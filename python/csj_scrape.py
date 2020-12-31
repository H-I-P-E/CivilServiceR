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
import numpy as np

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

csj_username = ssm_client.get_parameter(
        Name='/CivilServiceJobsExplorer/Toby/csjemail', WithDecryption=True)
csj_password = ssm_client.get_parameter(
        Name='/CivilServiceJobsExplorer/Toby/csjpassword', WithDecryption=True)

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
html = req.read()


xpath = "//div//div//div//a"

tree = etree.HTML(html)

#A list of all the search pages
link_elements = tree.xpath(xpath)

link_urls = [link.get('href') for link in link_elements]
link_titles = [link.get('title') for link in link_elements]
links = tuple(zip(link_urls,link_titles))
links = [page for page in links if page[1] is not None]
#This line finds those links that are search pages and removes duplicates
search_links = list(dict.fromkeys([page[0] for page in links if 
                                   page[1].find("Go to search results") != -1])) + [req.geturl()]

search_links = search_links[0:2] # for testing

results = []

for (i, page) in zip([1,len(search_links)], search_links):
    #This loop goes to each page in the search links and converts 
    #the data there into a narrow dataframe of ref, variable,value
    
    print("Searching page " + str(i) + " of " + str(len(search_links)))
    
    open_page = br.open(page)
    
    html = open_page.read()
    tree = etree.HTML(html)
    xpath = "//ul//li//div | //ul//li//div//a"
    elements = tree.xpath(xpath)
    
    link = [link.get('href') for link in elements]
    node_class = [link.get('class') for link in elements]
    text = [link.text for link in elements]
    
    df = pd.DataFrame(data = list(zip(link, node_class, text)),
                           columns = ["link", "variable", "value"])
    
    df['job_ref'] = np.where(df['variable'] == "search-results-job-box-refcode", df['value'], None)
    df['job_ref'] =  df['job_ref'].bfill()
    df['job_ref'] =  df['job_ref'].str.replace('Reference: ' ,'')

    #links are treated seperately as they are part of the href under the job title element
    links = df[~df['link'].isnull()]
    links =  links[links['link'].str.contains("https://www.civilservicejobs.service.gov.uk/csr/index.cgi")]  
    links['variable'] = "link"
    links = links[["job_ref","variable","value"]]

    
    df['link'].fillna("", inplace = True) 
    df['variable'].fillna("title", inplace = True) 
    df = df[(df['variable'].str.contains("search-results-job-box-")) | (df['link'].str.contains("https://www.civilservicejobs.service.gov.uk/csr/index.cgi")) ]
    df = df[~df['value'].isnull()]
    df['variable'] =  df['variable'].str.replace('search-results-job-box-','')
    df['variable'] =  df['variable'].str.replace('stage','approach')

    df = df[["job_ref","variable","value"]]
    
    page_data = df.append(links)
    results.append(page_data)
    
    
#filter jobs to new jobs
    
#itterate over new links and  get full jobs

