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

bucket_name=$(aws ssm get-parameter --name '/CivilServiceJobsExplorer/BucketName' --output text --query Parameter.Value)
mkdir /srv/shiny-server/data
echo $bucket_name
aws s3 sync s3://${bucket_name}/data/ /srv/shiny-server/data/

env > /home/shiny/.Renviron
chown shiny.shiny /home/shiny/.Renviron

exec shiny-server 2>&1 &
exec xtail /var/log/shiny-server/
