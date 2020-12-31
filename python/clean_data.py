import boto3
import os
import pandas
import re

from datetime import datetime
from dotenv import load_dotenv
from io import StringIO 

load_dotenv()

s3_client = boto3.client(
  's3',
  aws_access_key_id = os.getenv("AWS_ACCESS_KEY"),
  aws_secret_access_key = os.getenv("AWS_SECRET_KEY")
  )

# Get list of files that have already been cleaned
cleaned_data = s3_client.get_object(Bucket="civil-service-jobs", Key="cleaned_files.csv")
original_cleaned_data_filenames = cleaned_data['Body'].read().decode('utf-8').split()
original_cleaned_data_filenames.remove('csv') # Don't know why 'csv' appears as a file name
cleaned_data_filenames = original_cleaned_data_filenames

# Remove a recent cleaned_data_filename so that there appears to be an uncleaned
# file for us to work on.
# We have to iterate because it may have been cleaned multiple times.
removed_cleaned_data_filename = '2020-12-22_91257_72083_.csv'
while removed_cleaned_data_filename in cleaned_data_filenames:
  cleaned_data_filenames.remove(removed_cleaned_data_filename)

# Don't truncate the precious data
pandas.set_option('display.max_colwidth', None)

# Get raw data files to work on
# All files in raw_data/ which end csv and haven't already been cleaned
raw_data_directory_name = "raw_data/"
raw_data_filenames = set()
for object in s3_client.list_objects(Bucket="civil-service-jobs", Prefix=raw_data_directory_name)['Contents']:
  filename = object['Key'][len(raw_data_directory_name):]
  if (filename == raw_data_directory_name) or (filename[-4:] != ".csv"):
    continue
  raw_data_filenames.add(filename)

filenames_to_clean = set(cleaned_data_filenames).symmetric_difference(raw_data_filenames)

def convert_to_datetime(value):
  # 'Closes : 05:00 pm on Wednesday 2nd December 2020'
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

jobs = []
descriptions_and_summaries = []
for filename in filenames_to_clean:
  raw_data = s3_client.get_object(Bucket="civil-service-jobs", Key=f'{raw_data_directory_name}{filename}')
  body = raw_data['Body']
  csv_string = body.read().decode('utf-8')
  # Reading job_ref as string to try and avoid getting NaNs
  dataframe = pandas.read_csv(StringIO(csv_string), dtype={'job_ref': str})

  # Filter NA values from raw data (optional - not done)

  # Filter to required columns

  required_columns = {
    "approach", # formatted as "Approach : [stage]". New name for 'stage' column, not yet present at time of writing.
    "closingdate", # formatted as "Closes : 11:55 pm on Sunday 17th January 2021"
    "date_downloaded",
    "department",
    "grade", # formatted as "Grade : [grade]"
    "link",
    # We cannot tell if location contains >1 location ("East Midlands, Eastern, London"), or a single location ("Piccadilly, Manchester")
    "location",
    "Number of posts",
    "stage", # Old name for 'approach' column, renamed by scrape data. Kept for backwards compatibility.
    "title",
    "Type of role"
  }

  description_and_summary_columns = { "Job description", "Summary" } # Used later to count keywords: not saved in a file.

  # Reformat some columns
  for index in dataframe.index:
    variable = dataframe.loc[index, "variable"]
    value = dataframe.loc[index, "value"]
    # Convert to python datetime object
    
    if variable == "closingdate":
      dataframe.loc[index, "value"] = convert_to_datetime(value)
    elif variable == "grade":
      dataframe.loc[index, "value"] = value.replace("Grade : ", "")
    elif variable == "stage" or variable == "approach":
      dataframe.loc[index, "value"] = value.replace("Approach : ", "")

  # 'Type of role' column comes back concatenated when there are multiple roles. Break these apart.
  # Regexing for CamelCase does not solve this because CSJ is inconsistent about whether it inserts a space after each role

  # Convert to wide data structure (i.e. variables as individual columns instead of variable-value pairs)

  for job_reference_number in dataframe.job_ref.unique():
    job_data = dataframe[dataframe.job_ref == job_reference_number]

    job_dictionary = { 'job_ref': int(job_reference_number) }
    description_and_summary_dictionary = { 'job_ref': int(job_reference_number) }

    for column in required_columns:
      # Rename any columns called 'stage'. We are moving to a consistent schema across
      # all parts of the HIPE app, such that the column is always called 'approach'. But
      # old data will still have the old column name.
      if column == 'stage':
        continue
      if column == 'approach':
        row = job_data[job_data.variable == 'stage']
      else:
        row = job_data[job_data.variable == column]
      job_dictionary[column] = row.value.to_string(index=False)
    jobs.append(job_dictionary)

    for column in description_and_summary_columns:
      row = job_data[job_data.variable == column]
      description_and_summary_dictionary[column] = row.value.to_string(index=False)
    descriptions_and_summaries.append(description_and_summary_dictionary)

wide_jobs_dataframe = pandas.DataFrame(jobs)
descriptions_and_summaries_dataframe = pandas.DataFrame(descriptions_and_summaries)

# Update tables which count the number of instances of tokens

# Grades

grades_lookup = s3_client.get_object(Bucket="civil-service-jobs", Key="grade_lookup.csv")
grades_lookup_dataframe = pandas.read_csv(StringIO(grades_lookup['Body'].read().decode('windows-1252')))
grade_labels = list(grades_lookup_dataframe.label.unique())
grade_names = list(grades_lookup_dataframe.name.unique())
# Search for 'Executive Officer' last, so that we aren't counting 'Higher Executive Officer' jobs as EO.
# This does not fix backwards: the previous issue of counting HEO jobs as EO has not been fixed for past data.
eo_label = 'Executive Officer'
eo_index = grade_labels.index(eo_label)
eo_name = grade_names[eo_index]
grade_labels.remove(eo_label)
grade_labels.append(eo_label)
grade_names.remove(eo_name)
grade_names.append(eo_name)

old_grades_count_data = s3_client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/grades_data.csv")
# Read job_ref as str - otherwise we get mixed types in the column (int and str) because of the two formats: '11111' and 'old_22222'
old_grades_count_dataframe = pandas.read_csv(StringIO(old_grades_count_data['Body'].read().decode('utf-8')), dtype={'job_ref': str})

new_grade_counts = []
for job_reference_number in wide_jobs_dataframe.job_ref.unique():
  job_data = wide_jobs_dataframe[wide_jobs_dataframe.job_ref == job_reference_number]
  job_grade = job_data.grade.to_string(index=False)
  
  # Search for labels or, failing that, names, in the cleaned grade
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

# Combine old and new grades data without duplicating rows
grades_dataframe = pandas.concat([old_grades_count_dataframe, pandas.DataFrame(new_grade_counts)]).drop_duplicates().reset_index(drop=True)

# Roles

roles_lookup = s3_client.get_object(Bucket="civil-service-jobs", Key="role_lookup.csv")
roles_lookup_dataframe = pandas.read_csv(StringIO(roles_lookup['Body'].read().decode('windows-1252')))
role_labels = list(roles_lookup_dataframe.label.unique())
role_type_groups = list(roles_lookup_dataframe.role_type_group.unique())
old_roles_count_data = s3_client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/roles_data.csv")
old_roles_count_dataframe = pandas.read_csv(StringIO(old_roles_count_data['Body'].read().decode('utf-8')))

role = job_data['Type of role'].to_string(index=False)

# The rest of the roles part of the code is dependent on (awaiting) the new roles data schema from the new scrape task.
# (i.e. adding a delimiter to the 'Types of role' column in raw data, to enable cleaning)

# Keywords

keywords = s3_client.get_object(Bucket="civil-service-jobs", Key="key_words.csv")
keywords_dataframe = pandas.read_csv(StringIO(keywords['Body'].read().decode('windows-1252')))

# keywords_dataframe.tail
#                        Cause area                                              label  Strength of association 1-9 (currently subjective)     type  score_cutoff
# 34                 Climate change                                     greenhouse gas                                                  4   keyword             9
# 35                 Climate change                        committee on climate change                                                  9      team             9
# 36                 Climate change                         international climate fund                                                  9   project             9
# 37                 Climate change                 climate and environment department                                                  9      team             9
# 38                 Climate change                                     carbon capture                                                  4   keyword             9
# 39                 Climate change                                    decarbonisation                                                  4   keyword             9
# 40                   China policy                                              china                                                  8   keyword             9
# 41                   China policy                                            chinese                                                  8   keyword             9
# 42                   China policy                                            beijing                                                  6   keyword             9
# 43                   China policy                                          hong kong                                                  6   keyword             9

old_keywords_count_data = s3_client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/key_words_data.csv")
old_keywords_count_dataframe = pandas.read_csv(StringIO(old_keywords_count_data['Body'].read().decode('utf-8')))

new_keyword_counts = []

for job_reference_number in descriptions_and_summaries_dataframe.job_ref.unique():
  job_dictionary = { 'job_ref': int(job_reference_number) }
  job_data = descriptions_and_summaries_dataframe[descriptions_and_summaries_dataframe.job_ref == job_reference_number]

  job_text = ''
  for column in description_and_summary_columns:
    job_text += job_data[column].to_string(index=False).lower()

  for word in keywords_dataframe.label.unique():
    word_count = job_text.count(word)
    if word_count > 0:
      job_dictionary['count'] = word_count
      word_row = keywords_dataframe[keywords_dataframe.label == word]
      cause_area_label = word_row["label"].to_string(index=False)
      job_dictionary['label'] = cause_area_label
      new_keyword_counts.append(job_dictionary)

# Combine old and new keywords data without duplicating rows
keywords_dataframe = pandas.concat([old_keywords_count_dataframe, pandas.DataFrame(new_keyword_counts)]).drop_duplicates().reset_index(drop=True)






# Uploading:
# 1. Cleaned data
# 2. List of cleaned files
# 3,4,5. Grades, roles, keywords
dataframe_as_csv = keywords_dataframe.to_csv(index=False, encoding='unicode')
s3_client.put_object(Body=dataframe_as_csv, Bucket="civil-service-jobs", Key='test_folder/' + 'test1')
