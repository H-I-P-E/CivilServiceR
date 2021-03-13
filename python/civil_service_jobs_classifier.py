# -*- coding: utf-8 -*-
"""
Created on Tue Jan 19 18:56:33 2021

@author: tobias.jolly
"""
import boto3 as bt
import pandas as pd
from io import StringIO 


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

#Get a table of the IDs of previously downloaded jobs (these are not downloaded again - and this 
#file is updated at the end of this code)
#
#key_word_look_up = client.get_object(Bucket="civil-service-jobs", Key="key_words.csv")
#body = key_word_look_up['Body']
#csv_string = body.read().decode('utf-8')
#key_word_look_up_df = pd.read_csv(StringIO(csv_string))
#
#previous_ids = client.get_object(Bucket="civil-service-jobs", Key="test_folder/token_count_tables/key_words_data.csv")
#body = previous_ids['Body']
#csv_string = body.read().decode('utf-8')
#previous_ids_df = pd.read_csv(StringIO(csv_string))
#
#key_word_merged = previous_ids_df.merge(key_word_look_up_df, how = "left", on = "label")
#
#key_word_totals = key_word_merged.groupby(['job_ref','Cause area'], as_index=False).agg({'Strength of association 1-9 (currently subjective)':sum})
#
#
#

key_word_results  = pd.read_csv(..)

#read the keyword look up (create this duirng the clean and combine stage )
#get the jobs that match this 
#Put them in airtable
#Check airtable for manually classified jobs
#Save manually classified jobs into AWS
#Create a file that also adds to keywords lookup based ona model form the airtable  trainign set