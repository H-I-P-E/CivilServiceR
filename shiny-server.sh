#!/bin/sh

#remove toy examples from shiny server
# Make sure the dir for individual app logs exists
# sudo mkdir -p /var/log/shiny-server
# chown shiny.shiny /var/log/shiny-server
# if ["$APPLICATION_LOGS_TO_STDOUT" != "false"];
#     then
# exec xtail /var/log/shiny-server/
# fi
aws configure set default.region eu-west-2
# export AWS_ACCESS_KEY_ID=xxxx #DO NOT DO THIS IN PRODUCTION, SET VIA ROLE ATTACHED TO PROD MACHINE
# export AWS_SECRET_ACCESS_KEY=xxxxx

# Next para is all for getting data into the bucket which we'll do somewhere else
# username=$(aws ssm get-parameter --name '/CivilServiceJobsExplorer/Toby/csjemail' --output text --query Parameter.Value)
# password=$(aws ssm get-parameter --name '/CivilServiceJobsExplorer/Toby/csjpassword' --output text --query Parameter.Value)
# rm /srv/shiny-server/CivilServiceR/user_name_and_password.R
# touch /srv/shiny-server/CivilServiceR/user_name_and_password.R
# echo "username = '$username'" >> /user_name_and_password.R
# echo "password = '$password'" >> /user_name_and_password.R
# cat /srv/shiny-server/CivilServiceR/user_name_and_password.R #can remove this
# sudo Rscript -e "CivilServiceR::update_database()"

bucket_name=$(aws ssm get-parameter --name '/CivilServiceJobsExplorer/BucketName' --output text --query Parameter.Value)
mkdir /srv/shiny-server/data/
aws s3 cp s3://${bucket_name}/data/ /srv/shiny-server/data/ --recursive
ls /srv/shiny-server/data/ #can remove this 

env > /home/shiny/.Renviron
chown shiny.shiny /home/shiny/.Renviron

exec shiny-server 2>&1 &
exec xtail /var/log/shiny-server/
