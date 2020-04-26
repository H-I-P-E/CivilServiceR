# CivilServiceR

Pulls data from the Civil Service Jobs website and presents this data as a Shiny app

### About the app

The app can be accessed [here](https://highimpact.shinyapps.io/civil_service_jobs_explorer)

The app was designed by the [HIPE](https://hipe.org.uk/) team to help civil servants and future civil servants plan an impactful career.

For more information, feedback or ideas about improvements, please contact [Toby](https://mailto:tobiasjolly@gmail.com?subject=HIPE jobs app)

### Technical stuff 


##### What is this

This GitHub repo is an R package containing code that scrapes data from [Civil Service Jobs](https://www.civilservicejobs.service.gov.uk), then cleans/reformats that data. Jobs are labelled as being in policy area based on the keywords in the [key words file](https://github.com/TWJolly/CivilServiceR/blob/master/meta_data/key_words.csv).


It also contains an RShiny application that present this data as a filterable table of jobs. 

##### To get this code to run...

You will need to create a file called "user_name_and_password.R" if the package directory
This file  will need to contain 2 lines:

username = ["your_cs_jobs_username"]

password = ["your_cs_jobs_password"]

Running CivilServiceR::update_database() will preform the webscrape

If you want to run your own Shiny app you will need to set this up at shinyapps.io

