# CivilServiceR

Pulls data from the Civil Service Jobs website and presents this data as a Shiny app

### About the app

The app can be accessed [here](http://hipe.amid.fish)

The app was designed by the [HIPE](https://hipe.org.uk/) team to help civil servants and future civil servants plan an impactful career.

For more information, feedback or ideas about improvements, please contact [Toby](https://mailto:tobiasjolly@gmail.com)

### Technical stuff

##### Run the app locally

You can run this app yourself if you have Docker installed.

Clone this repository and run this command from the directory with the Dockerfile:

`docker build -t [IMAGENAME] .`

You can check the image built with `docker images`.

Once the image has built, you should be able to run it like so:

`docker run -p 80:3838 [IMAGENAME]`

There are some AWS dependencies, so you may need to have IAM credentials set up.

##### Architecture

The web app is running on Shiny server in a Docker container that runs on EC2 instance. It depends on the civil service jobs data that live in an S3 bucket, which is regularly updated by a Lambda on a CRON job.

![arch](https://user-images.githubusercontent.com/13587601/116826391-a3b0aa00-ab8b-11eb-8850-2cd1e192a8c5.png)

The Cloudformation template builds the infrastructure for the front-end.

##### Data source and categorisation

The data come from [Civil Service Jobs](https://www.civilservicejobs.service.gov.uk). Jobs are labelled as being in a policy/cause area based on the keywords in the [key words file](https://github.com/TWJolly/CivilServiceR/blob/master/meta_data/key_words.csv).
