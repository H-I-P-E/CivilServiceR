import boto3 as bt
import pandas as pd
from io import StringIO
import mechanize
from lxml import etree
import numpy as np
from datetime import date
import re


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

#User name and password is stored in parameter store and is used to log into Civil Service jobs
csj_username = ssm_client.get_parameter(
        Name='/CivilServiceJobsExplorer/Toby/csjemail', WithDecryption=True)
csj_password = ssm_client.get_parameter(
        Name='/CivilServiceJobsExplorer/Toby/csjpassword', WithDecryption=True)

#Log in at the log in page
br = mechanize.Browser()
br.open("https://www.civilservicejobs.service.gov.uk/csr/login.cgi")
br.select_form(nr=1)


br.form['username'] = csj_username['Parameter']['Value']
br.form['password_login_window'] = csj_password['Parameter']['Value']

req = br.submit()

search_url = "https://www.civilservicejobs.service.gov.uk/csr/index.cgi"

#Preform a search of jobs that covers all of the UK and overseas
br.open(search_url)
br.select_form(nr=1)
br.form['postcode'] = "Birmingham"
br.form['postcodedistance'] = ["600"]
br.form['postcodeinclusive'] = ["1"]

##Serach and extract html of search results
req = br.submit()
html = req.read()
tree = etree.HTML(html)

#Gets a list of all the search pages
link_elements = tree.xpath("//div//div//div//a")
link_urls = [link.get('href') for link in link_elements]
link_titles = [link.get('title') for link in link_elements]
links = tuple(zip(link_urls,link_titles))
links = [page for page in links if page[1] is not None]
#This line finds those links that are search pages and removes duplicates
search_links = list(dict.fromkeys([page[0] for page in links if
                                   page[1].find("Go to search results") != -1])) + [req.geturl()]
basic_advert_results = []

for (i, page) in zip(range(1,len(search_links)+1), search_links):
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
    df['job_ref'] =  df['job_ref'].bfill() #upfill references
    df['job_ref'] =  df['job_ref'].str.replace('Reference: ' ,'')

    #links are treated seperately as they are part of the href under the job title element
    links = df[~df['link'].isnull()]
    links =  links[links['link'].str.contains("https://www.civilservicejobs.service.gov.uk/csr/index.cgi")]
    links['variable'] = "link"
    links = links[["job_ref","variable","link"]]
    links = links.rename(columns = {"link":"value"})


    df['link'].fillna("", inplace = True)
    df['variable'].fillna("title", inplace = True)
    df = df[(df['variable'].str.contains("search-results-job-box-")) | (df['link'].str.contains("https://www.civilservicejobs.service.gov.uk/csr/index.cgi")) ]
    df = df[~df['value'].isnull()]
    df['variable'] =  df['variable'].str.replace('search-results-job-box-','')
    df['variable'] =  df['variable'].str.replace('stage','approach')

    df = df[["job_ref","variable","value"]]

    page_data = df.append(links, sort=False)
    basic_advert_results.append(page_data)

basic_data = pd.concat(basic_advert_results, sort=False)


#filter jobs to new jobs
basic_new_data = basic_data[~basic_data["job_ref"].isin(previous_ids_df['job_ref'])]

#92177

full_advert_results = []

new_links = basic_new_data[basic_new_data['variable'] == "link"]


for (i, page, job_ref) in zip(range(1,len(new_links)+1), new_links['value'], new_links['job_ref'] ):
    #itterate over new links and  get full jobs
    print("Scraping page " + str(i) + " of " + str(len(new_links)))
    open_page = br.open(page)
    html = open_page.read()
    tree = etree.HTML(html)
    elements = tree.cssselect('.vac_display_field_value , h3')
    node_tag = [e.tag for e in elements]
    node_text = [etree.tostring(e, encoding='unicode', method='text') for e in elements]
    node_html = [etree.tostring(e, encoding='unicode', method='html') for e in elements]

    df = pd.DataFrame(list(zip(node_tag, node_text, node_html)),
               columns =['tag', 'text','html'])
    #h3 elements are assumed to be teh variable headings and other elements (divs) and taken as the values
    #the values for a given heading are all the divs (that match the cssselect) below that heading, but
    #before another heading
    df['variable'] = np.where(df['tag'] == "h3", df['text'], None)
    df['variable'] =  df['variable'].ffill()
    df['text'] =  df['text'].str.strip().replace(r'\\n',' ')
    df['text'] =  df['text'].apply(lambda x: re.sub(r'\x95',"",x))
    df['text'] =  df['text'].apply(lambda x: re.sub(r'\t'," ",x))
    df['text'] =  df['text'].apply(lambda x: re.sub(r'\r'," ",x))

    #This html stuff is just here to handle roll types
    df['html'] = df['html'].apply(lambda x: re.sub("<div class=\"vac_display_field_value\">","",x))
    df['html'] = df['html'].apply(lambda x: re.sub("</div>","",x))
    df['html'] = df['html'].apply(lambda x: re.sub("<br>","!!!",x))
    df['text'] =  np.where(df['variable'] == "Type of role", df['html'], df['text'])

    df['variable'] =  df['variable'].str.strip()
    df = df[df['tag'] != "h3"]

    df['value'] = df.groupby(['variable'])['text'].transform(lambda x : "!!!".join(x))
    df = df[["variable","value"]]
    df = df.drop_duplicates()
    df['job_ref'] = job_ref

    df = df.append(
            {"variable": "date_downloaded", "value": str(date.today()) , "job_ref": job_ref},
            ignore_index=True )

    #need to check the time in here and if there is not enought time to save - is shoudl quite the looos
    #And then filter the basic data to the full data that it has managed to donwload before the concat

    full_advert_results.append(df)

#Join allnew full advert dataframes together
full_advert_data = pd.concat(full_advert_results, sort=False)

full_and_basic_data =  pd.concat([full_advert_data, basic_new_data], sort=False)

#carriage returns might not be working properly - will need to test in clean_data script

#New Ids are extracted and added to previous ones
new_ids = full_advert_data[["job_ref"]].drop_duplicates()
updated_ids = previous_ids_df.append(new_ids)


#New data file name is the current data and the min and max job ref
min_ref = str(min(new_ids["job_ref"].astype(int)))
max_ref = str(max(new_ids["job_ref"].astype(int)))
new_file_name = "_".join([str(date.today()), max_ref, min_ref, ".csv"])

#Add the new data and updated list of IDs to S3 as csvs
#Data
full_data_as_csv = full_and_basic_data.to_csv(index = False, encoding='unicode', sep = ",", line_terminator = "\n")
client.put_object(Body=full_data_as_csv, Bucket="civil-service-jobs", Key="raw_data/" + new_file_name)
#IDs (this just overwrites the old version)
updated_ids_as_csv = updated_ids.to_csv(index = False, encoding='unicode')
client.put_object(Body=updated_ids_as_csv, Bucket="civil-service-jobs", Key="existing_refs.csv")

