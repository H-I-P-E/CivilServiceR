# -*- coding: utf-8 -*-
"""
Created on Sat Jan 23 13:09:08 2021

@author: tobias.jolly
"""

import boto3 as bt
import pandas as pd
from io import StringIO 
from airtable import Airtable

#Need to get secret key somewhere else (currently just paste into the console - where?)

client = bt.client(
    's3',
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY
    )

ssm_client = bt.client('ssm',
    region_name="eu-west-2",
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY
    )


key_words_count_data = client.get_object(Bucket="civil-service-jobs", Key="token_count_tables/key_words_data.csv")
key_words_count_df = pd.read_csv(StringIO(key_words_count_data['Body'].read().decode('utf-8')))

key_words_list = client.get_object(Bucket="civil-service-jobs", Key="key_words.csv")
key_words_list_df = pd.read_csv(StringIO(key_words_list['Body'].read().decode('utf-8')))


key_word_scores = pd.merge(key_words_count_df, key_words_list_df, left_on = "label", right_on = "label")
key_word_scores['total_score'] = key_word_scores["count"] * key_word_scores['Strength of association 1-9 (currently subjective)']

job_cause_scores = key_word_scores.groupby(by = ['job_ref', "Cause area"], axis=0, as_index = False).sum()
job_cause_scores = job_cause_scores[['job_ref', "Cause area", "total_score"]]
#Get this groupby to work

clean_folder= "test_folder/cleaned_data/"

clean_data_files = client.list_objects_v2(Bucket="civil-service-jobs", Prefix=clean_folder)['Contents']
#Use dates to optimise this stuff
clean_data = []

for file in clean_data_files:
    file_obj = client.get_object(Bucket="civil-service-jobs", Key=  file['Key'])
    df = pd.read_csv(StringIO(file_obj['Body'].read().decode('utf-8')))
    clean_data.append(df)

clean_dataframe = pd.concat(clean_data)

labelled_clean_data = pd.merge(clean_dataframe, job_cause_scores, left_on = "job_ref", right_on = "job_ref")
labelled_clean_data = labelled_clean_data.rename(columns={"link": "Link", "title": "Job title"})
data_to_add = labelled_clean_data[["Job title", "Link"]].to_dict('records')

base_key = "appq9JOFCQtPaSxSC"    
airtable = Airtable(base_key, 'jobs', api_key = airtable_api_key)


for job in data_to_add:
    airtable.insert(job)
    

#filter values and add the rest of teh field




