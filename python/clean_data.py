# import csv

from boto3 import client
from datetime import datetime
from dotenv import load_dotenv
from io import StringIO
from os import getenv
from pandas import concat, DataFrame, read_csv, set_option

load_dotenv()

def convert_to_datetime(value):
  # format: 'Closes : 05:00 pm on Wednesday 2nd December 2020'
  date_elements = value.split()[-3:]
  time_elements = value.split()[-7:-5]

  # '2nd' => '02'
  day_of_month = date_elements[0]
  day_of_month = ''.join(filter(str.isdigit, day_of_month))
  if len(day_of_month) == 1:
    date_elements[0] = f'0{day_of_month}'
  else:
    date_elements[0] = day_of_month

  # Account for 'midday' edgecase ('Closes : Midday on Monday 4th January 2021')
  # Convert 12:00 => 11:59 to sidestep am/pm ambiguity without requiring logic in web app
  if time_elements[-1] != "pm" and time_elements[-1] != "am":
    if time_elements[-1].lower() == 'midday':
      time_elements = ["11:59", "am"]
    elif time_elements[-1].lower() == 'midnight':
      time_elements = ["11:59", "pm"]

  datetime_elements = date_elements + time_elements

  # '02 December 2020 05:00 pm' => date object
  return datetime.strptime((' ').join(datetime_elements), '%d %B %Y %I:%M %p')

s3_client = client(
  's3',
  aws_access_key_id = getenv("AWS_ACCESS_KEY"),
  aws_secret_access_key = getenv("AWS_SECRET_KEY")
  )

# Get list of files that have already been cleaned
original_cleaned_files = s3_client.get_object(Bucket="civil-service-jobs", Key="cleaned_files.csv")
original_cleaned_data_filenames = original_cleaned_files['Body'].read().decode('utf-8').split()
column_heading = 'csv'
if column_heading in original_cleaned_data_filenames:
  original_cleaned_data_filenames.remove(column_heading)

# Remove a recent cleaned_data_filename so that there appears to be an uncleaned
# file for us to work on.
# We have to iterate with 'while' because it may have been cleaned multiple times.
old_style_file = '2020-12-22_91257_72083_.csv'
new_style_file = '2021-01-23_95715_80682_.csv'
for removed_cleaned_data_filename in [old_style_file, new_style_file]:
  while removed_cleaned_data_filename in original_cleaned_data_filenames:
    original_cleaned_data_filenames.remove(removed_cleaned_data_filename)

removed_cleaned_data_filename = old_style_file
while removed_cleaned_data_filename in original_cleaned_data_filenames:
  original_cleaned_data_filenames.remove(removed_cleaned_data_filename)

# Don't truncate the precious data
set_option('display.max_colwidth', None)

# Get raw data files to work on
# All files in raw_data/ which end csv and haven't already been cleaned
raw_data_directory_name = "raw_data/"
raw_data_filenames = set()
for object in s3_client.list_objects(Bucket="civil-service-jobs", Prefix=raw_data_directory_name)['Contents']:
  filename = object['Key'][len(raw_data_directory_name):]
  if (filename == raw_data_directory_name) or (filename[-4:] != ".csv"):
    continue
  raw_data_filenames.add(filename)

filenames_to_clean = set(original_cleaned_data_filenames).symmetric_difference(raw_data_filenames)

# Clean data
# ==========

# Reformat some columns, convert to wide data structure (i.e. variables as individual columns instead of
# variable-value pairs), and filter to required columns.
wide_cleaned_dataframes_dictionary = {}
descriptions_and_summaries = []
for filename in filenames_to_clean:
  jobs = []

  raw_data = s3_client.get_object(Bucket="civil-service-jobs", Key=f'{raw_data_directory_name}{filename}')
  body = raw_data['Body']
  csv_string = body.read().decode('utf-8')
  # Read job_ref as string to try and avoid getting NaNs for non-number job ref numbers.
  dataframe = read_csv(StringIO(csv_string), dtype={'job_ref': str})

  # Reformat some columns
  for index in dataframe.index:
    # Rename any columns called 'stage'. We are moving to a consistent schema across
    # all parts of the HIPE app, such that the column is always called 'approach'. But
    # old raw data will still have the old column name.
    if dataframe.loc[index, "variable"] == "stage":
      dataframe.loc[index, "variable"] = "approach"

    variable = dataframe.loc[index, "variable"]
    value = dataframe.loc[index, "value"]

    if variable == "closingdate":
      dataframe.loc[index, "value"] = convert_to_datetime(value)
    elif variable == "grade":
      dataframe.loc[index, "value"] = value.replace("Grade : ", "")
    elif variable == "approach":
      dataframe.loc[index, "value"] = value.replace("Approach : ", "")

  required_columns = {
    "approach", # formatted as "Approach : [internal/external]".
    "closingdate", # formatted as "Closes : 11:55 pm on Sunday 17th January 2021"
    "date_downloaded",
    "department",
    "grade", # formatted as "Grade : [grade]"
    "link",
    # We cannot tell if location contains >1 location ("East Midlands, Eastern, London"), or a single location ("Piccadilly, Manchester")
    "location",
    "Number of posts",
    "title",
    "Type of role"
  }

  description_and_summary_columns = { "Job description", "Summary" } # Used later to count keywords: not saved in a file.

  # Convert to wide data structure (i.e. variables as individual columns instead of variable-value pairs) while
  # filtering to required columns.

  for job_reference_number in dataframe.job_ref.unique():
    job_data = dataframe[dataframe.job_ref == job_reference_number]

    job_dictionary = { 'job_ref': int(job_reference_number) }
    for column in required_columns:
      row = job_data[job_data.variable == column]
      job_dictionary[column] = row.value.to_string(index=False)
    jobs.append(job_dictionary)

    description_and_summary_dictionary = { 'job_ref': int(job_reference_number) }
    for column in description_and_summary_columns:
      row = job_data[job_data.variable == column]
      description_and_summary_dictionary[column] = row.value.to_string(index=False).lower()
    descriptions_and_summaries.append(description_and_summary_dictionary)

    wide_cleaned_dataframes_dictionary[filename] = DataFrame(jobs)

all_cleaned_data_dataframe = concat(wide_cleaned_dataframes_dictionary.values()).drop_duplicates().reset_index(drop=True)

descriptions_and_summaries_dataframe = DataFrame(descriptions_and_summaries)

# Update tables which count the number of instances of tokens. For grades, roles, and keywords.
# =============================================================================================

# Grades: Download files and reorder contents where necessary for avoiding false positives

grades_lookup = s3_client.get_object(Bucket="civil-service-jobs", Key="grade_lookup.csv")
grades_lookup_dataframe = read_csv(StringIO(grades_lookup['Body'].read().decode('windows-1252')))
old_grades_count_data = s3_client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/grades_data.csv")
# Read job_ref as str - otherwise we get mixed types in the column (int and str) because of the two formats: '11111' and 'old_22222'
old_grades_count_dataframe = read_csv(StringIO(old_grades_count_data['Body'].read().decode('utf-8')), dtype={'job_ref': str})

# Move 'Executive Officer' to the end to be searched for last, so that we aren't getting false positives by counting
# 'Higher Executive Officer' and 'Senior Executive Officer' jobs as EO.
# This does not fix backwards: the previous issue of counting HEO jobs as EO has not been fixed for past data.

grade_labels = list(grades_lookup_dataframe.label.unique())
grade_names = list(grades_lookup_dataframe.name.unique())
eo_label = 'Executive Officer'
eo_index = grade_labels.index(eo_label)
eo_name = grade_names[eo_index]
grade_labels.remove(eo_label)
grade_labels.append(eo_label)
grade_names.remove(eo_name)
grade_names.append(eo_name)

# Roles: Download files and reorder contents where necessary for avoiding false positives

roles_lookup = s3_client.get_object(Bucket="civil-service-jobs", Key="role_lookup.csv")
roles_lookup_dataframe = read_csv(StringIO(roles_lookup['Body'].read().decode('windows-1252')))
role_type_groups = list(roles_lookup_dataframe.role_type_group.unique())
old_roles_count_data = s3_client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/roles_data.csv")
# Read job_ref as str - otherwise we get mixed types in the column (int and str) because of the two formats: '11111' and 'old_22222'
old_roles_count_dataframe = read_csv(StringIO(old_roles_count_data['Body'].read().decode('utf-8')), dtype={'job_ref': str})

# There are some role-types whose names are a subset of another role-type (e.g. below), which means that searching for
# the presence of the shorter role-type will produce false positives unless we both search for the longer role-type
# and remove it from the string afterwards. We could rely on the delimiter '!!!' if this cleaning task did not need
# to be backwards-compatible with data scraped before the introduction of the delimiter; in the future we might be
# able to move to that preferable delimiter-based way of doing things, if we decide that we don't need this task to
# be compatible with pre-2021 data.

# Trade < International Trade
# Finance < Corporate Finance
# Audit < Internal Audit
# Social Research < Social Research / Market Research
# Market Research < Social Research / Market Research

role_labels = list(roles_lookup_dataframe.label.unique())
for role_type in ['Trade', 'Finance', 'Audit', 'Social Research', 'Market Research']:
  role_labels.remove(role_type)
  role_labels.append(role_type)

# Keywords: Download files and reorder contents where necessary for avoiding false positives

keywords = s3_client.get_object(Bucket="civil-service-jobs", Key="key_words.csv")
keywords_dataframe = read_csv(StringIO(keywords['Body'].read().decode('windows-1252')))
old_keywords_count_data = s3_client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/key_words_data.csv")
# Read job_ref as str - otherwise we get mixed types in the column (int and str) because of the two formats: '11111' and 'old_22222'
old_keywords_count_dataframe = read_csv(StringIO(old_keywords_count_data['Body'].read().decode('utf-8')), dtype={'job_ref': str})

# Reordering for similar reasons as for role_labels and grade_labels/grade_names: avoid false positives.
keyword_labels = list(keywords_dataframe.label.unique())
for keyword_label in ['global', 'mental health', 'international']:
  keyword_labels.remove(keyword_label)
  keyword_labels.append(keyword_label)

# Grades and roles: Count the instances of each in cleaned data

new_grade_counts = []
new_role_counts = []
for job_reference_number in all_cleaned_data_dataframe.job_ref.unique():
  job_data = all_cleaned_data_dataframe[all_cleaned_data_dataframe.job_ref == job_reference_number]

  # Grades: Search for labels or, failing that, names, in the cleaned grade

  job_grade = job_data.grade.to_string(index=False)

  grade_token = None
  for label in grade_labels:
    if label in job_grade:
      grade_token = label
      break
  if grade_token == None:
    for index, name in enumerate(grade_names):
      if name in job_grade:
        grade_token = grade_labels[index]
        break
  if grade_token != None:
    new_grade_counts.append({
      'job_ref': int(job_reference_number),
      'label': grade_token,
      'count': 1 })

  # Roles: Search for roles in the Type of role column (which can contain multiple roles)

  # NB: For old-format raw data files (before the scrape task began to delimit roles by looking for a <br> tag in the
  # HTML and inserting '!!!'), when there are multiple roles they come back concatenated together, like:
  # Administration / Corporate SupportHuman ResourcesOperational Delivery. Regexing for CamelCase does not solve this
  # in all cases because Civil Service Jobs is inconsistent about whether it inserts a space after each role.

  roles = job_data['Type of role'].to_string(index=False)

  for label in role_labels:
    if label in roles:
      role_type_group = roles_lookup_dataframe[roles_lookup_dataframe.label == label]["role_type_group"].to_string(index=False)
      new_role_counts.append({
            'job_ref': int(job_reference_number),
            'label': role_type_group,
            'count': 1 })
      # Remove the label from the roles to prevent false positives (see earlier comment).
      roles = roles.replace(label, '(replaced)')

# Keywords: Search for keywords in the job descriptions and summaries.

new_keyword_counts = []
for job_reference_number in descriptions_and_summaries_dataframe.job_ref.unique():
  job_data = descriptions_and_summaries_dataframe[descriptions_and_summaries_dataframe.job_ref == job_reference_number]
  job_text = ''
  for column in description_and_summary_columns:
    job_text += job_data[column].to_string(index=False).lower()

  for word in keyword_labels:
    word_count = job_text.count(word)
    if word_count > 0:
      cause_area_label = keywords_dataframe[keywords_dataframe.label == word]["label"].to_string(index=False)
      new_keyword_counts.append({
            'job_ref': int(job_reference_number),
            'label': cause_area_label,
            'count': word_count })
      # Remove the word from the text to prevent false positives (see earlier comment).
      job_text = job_text.replace(word, '(replaced)')

# Combine old and new data without duplicating rows (incorrect data resulting from previous bugs is NOT overwritten.)
grades_dataframe = concat([old_grades_count_dataframe, DataFrame(new_grade_counts)]).drop_duplicates().reset_index(drop=True)
roles_dataframe = concat([old_roles_count_dataframe, DataFrame(new_role_counts)]).drop_duplicates().reset_index(drop=True)
keywords_dataframe = concat([old_keywords_count_dataframe, DataFrame(new_keyword_counts)]).drop_duplicates().reset_index(drop=True)

# Upload
# ======

# Cleaned data

for original_filename, dataframe in wide_cleaned_dataframes_dictionary.items():
  dataframe_as_csv = keywords_dataframe.to_csv(index=False, encoding='unicode')
  s3_client.put_object(Body=dataframe_as_csv, Bucket="civil-service-jobs", Key=f'test_folder/cleaned_data/cleaned_' + original_filename)

# List of cleaned files (cleaned_files.csv)

todays_cleaned_data_filenames = list(wide_cleaned_dataframes_dictionary.keys())
# Use set to remove duplicates
cleaned_files = list(set(todays_cleaned_data_filenames + original_cleaned_data_filenames))
cleaned_files.sort()
cleaned_files_dataframe = DataFrame(cleaned_files, columns=['csv'])
dataframe_as_csv = cleaned_files_dataframe.to_csv(index=False, encoding='unicode')
s3_client.put_object(Body=dataframe_as_csv, Bucket="civil-service-jobs", Key="test_folder/cleaned_files.csv")

# Grades, roles, keyword count tables

token_count_tables = {
  'grades_data.csv': grades_dataframe,
  'key_words_data.csv': keywords_dataframe,
  'roles_data.csv': roles_dataframe
}
for filename, dataframe in token_count_tables.items():
  dataframe_as_csv = dataframe.to_csv(index=False, encoding='unicode')
  s3_client.put_object(Body=dataframe_as_csv, Bucket="civil-service-jobs", Key=f'test_folder/token_count_tables/' + filename)

