import boto3 as bt
import pandas as pd
import paramiko
import os
import pyreadr
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

session_requests = requests.session()

#result = session_requests.get(login_url)

session = session_requests.post(login_url, data=values) 


search_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi"

session = rvest::jump_to(session, search_url)
  form = rvest::html_form(xml2::read_html(search_url))[[1]]
  filled_form = rvest::set_values(form,
                                   postcodedistance = "600",
                                   postcode = "Birmingham",
                                   postcodeinclusive = "1")
  session = rvest::submit_form(session, filled_form)