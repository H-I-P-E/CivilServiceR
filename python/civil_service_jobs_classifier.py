# -*- coding: utf-8 -*-
"""
Created on Tue Jan 19 18:56:33 2021

@author: tobias.jolly
"""
import boto3 as bt


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
previous_ids = client.get_object(Bucket="civil-service-jobs", Key="existing_refs.csv")
body = previous_ids['Body']
csv_string = body.read().decode('utf-8')
previous_ids_df = pd.read_csv(StringIO(csv_string))


#read the keyword look up
#get the jobs that match this 
#Put them in airtable
#Check airtable for manually calssified jobs
#Save manually classified jobs into AWS
#Create a file that also adds to keywords lookup based ona model form the airtable  trainign set