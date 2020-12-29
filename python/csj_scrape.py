import boto3 as bt
import pandas as pd
import os
import requests
from io import StringIO 
from io import BytesIO  
import urllib.request as urllib2
from urllib import request, parse
from bs4 import BeautifulSoup
import re
import mechanize
from lxml import etree

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

br = mechanize.Browser()
br.open("https://www.civilservicejobs.service.gov.uk/csr/login.cgi")
br.select_form(nr=0)


br.form['username'] = csj_username['Parameter']['Value']
br.form['password_login_window'] = csj_password['Parameter']['Value']

req = br.submit()
req.read()

search_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi"


br.open("https://www.civilservicejobs.service.gov.uk/csr/index.cgi")
br.select_form(nr=0)


br.form['postcode'] = "Birmingham"
br.form['postcodedistance'] = ["600"]
br.form['postcodeinclusive'] = ["1"]

req = br.submit()
html =req.read()


xpath = "//div//div//div//a/@href"

tree = etree.HTML(html)

#A list of all the search pages
search_pages = tree.xpath(xpath)

#get the correct search pages (this is not selective enough)
search_pages = [page for page in search_pages if page.find(search_url) != -1]




