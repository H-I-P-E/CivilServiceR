# -*- coding: utf-8 -*-
"""
Created on Sat Jan 23 13:09:08 2021

@author: tobias.jolly
"""

import boto3 as bt
import pandas as pd

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

key_word_scores= key_word_scores.groupby(by = ['job_ref', "Cause area"]).sum()
#Get this groupby to work


clean_data = client.get_object(Bucket="civil-service-jobs", Key="data/clean_data.csv")
clean_dataframe = pd.read_csv(StringIO(clean_data['Body'].read().decode('utf-8'))) 