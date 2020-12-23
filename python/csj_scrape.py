import boto3 as bt
import pandas as pd
import os
import requests
from io import StringIO 
from io import BytesIO  
import urllib.request as urllib2
from bs4 import BeautifulSoup

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

previous_ids = client.get_object(Bucket="civil-service-jobs", Key="existing_refs.csv")
body = previous_ids['Body']
csv_string = body.read().decode('utf-8')
df = pd.read_csv(StringIO(csv_string))

csj_username = ssm_client.get_parameter(Name='/CivilServiceJobsExplorer/Toby/csjemail', WithDecryption=True)
csj_password = ssm_client.get_parameter(Name='/CivilServiceJobsExplorer/Toby/csjpassword', WithDecryption=True)

login_url = "https://www.civilservicejobs.service.gov.uk/csr/login.cgi"
values = {'username': csj_username,
          'password_login_window': csj_password}

session = requests.post(login_url, data=values) 

#result = session_requests.get(login_url)
#FIX this log in and search


search_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi"
search_values = {"postcodedistance":"600", "postcode":"Birmingham",
                "postcodeinclusive":"1"}

response = requests.post(search_url, data=search_values) 

soup = BeautifulSoup(response.content)
