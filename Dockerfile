from rocker/shiny:3.6.1

RUN apt-get update

RUN apt-get install -y libssl-dev libpython3-dev python3-pip
RUN pip3 install boto3 awscli

RUN Rscript -e "install.packages(\
    c(\
        'shiny', \
        'httr', \
        'DT', \
        'shinythemes', \
        'plotly', \
        'dplyr', \
        'readr', \
        'tidyr', \
        'ggplot2', \
        'magrittr',\
        'lubridate'\
        'botor'\
    ),\
    repos = c(CRAN = 'http://cran.rstudio.com')\
    )"

RUN rm -r /srv/shiny-server/*
COPY ./civil_service_jobs_explorer/ /srv/shiny-server/

RUN echo "preserve_logs true;" >> /etc/shiny-server/shiny-server.conf

COPY shiny-server.sh /usr/bin/shiny-server.sh
RUN [ "chmod", "+x", "/usr/bin/shiny-server.sh"]
CMD ["/usr/bin/shiny-server.sh"]