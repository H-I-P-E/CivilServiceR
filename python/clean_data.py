import boto3
import os
import pandas

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
cleaned_data_filenames = cleaned_data['Body'].read().decode('utf-8').split()
cleaned_data_filenames.remove('csv') # Don't know why 'csv' appears as a file name

# Remove the last cleaned_data_filename so that there appears to be an uncleaned
# file for us to work on.
# We have to iterate because it may have been cleaned multiple times.
removed_cleaned_data_filename = cleaned_data_filenames[0]
while removed_cleaned_data_filename in cleaned_data_filenames:
  cleaned_data_filenames.remove(removed_cleaned_data_filename)

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

for filename in filenames_to_clean:
  raw_data = s3_client.get_object(Bucket="civil-service-jobs", Key=f'{raw_data_directory_name}{filename}')
  body = raw_data['Body']
  csv_string = body.read().decode('utf-8')
  dataframe = pandas.read_csv(StringIO(csv_string))

  # Filter NA values from raw data (optional)

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
    "stage", # Old name for 'approach' column, renamed by scrape data. Kept for now as I am working with old data.
    "title",
    "Type of role"
  }

  dataframe = dataframe[dataframe.variable.isin(required_columns)]

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
  # Regexing for CamelCase does not solve this because CSJ is inconistent about whether it inserts a space after each role

  # Convert to wide data structure (i.e. variables as individual columns instead of variable-value pairs)

  for job_reference_number in dataframe.job_ref.unique():
    job_data = dataframe[dataframe.job_ref == job_reference_number]
    job_dictionary = { 'job_ref': job_reference_number }
    for column in required_columns:
      row = job_data[job_data.variable == column]
      job_dictionary[column] = row.value.to_string(index=False)
    jobs.append(job_dictionary)

wide_dataframe = pandas.DataFrame(jobs)
  
breakpoint()

print(csv_string)
print(filenames_to_clean)

  # The below is from the colab. Last line may be a decent way to read the csv. Or use python inbuilt csv module.

  # cleaned_data = s3_client.get_object(Bucket="civil-service-jobs", Key="cleaned_files.csv")
  # body = cleaned_data['Body']
  # csv_string = body.read().decode('utf-8')
  # df = pd.read_csv(StringIO(csv_string))

