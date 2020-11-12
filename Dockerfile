from rocker/shiny:3.6.1

RUN apt-get -y install libssl-dev libgdal-dev libproj-dev libgeos-dev

RUN Rscript -e "install.packages(\
    c(\
        'shiny', \
        'DT', \
        'shinythemes', \
        'plotly', \
        'dplyr', \
        'readr', \
        'tidyr', \
        'ggplot2', \
        'rmarkdown'\
    ),\
    repos = c(CRAN = 'http://cran.rstudio.com')\
    )"

COPY ./civil_service_jobs_explorer /srv/shiny-server.sh/civil_service_jobs_explorer/

COPY shiny-server.sh /usr/bin/shiny-server.sh

RUN [ "chmod", "+x", "/usr/bin/shiny-server.sh"]

CMD ["/usr/bin/shiny-server.sh"]

RUN ls /var/log/shiny-server/