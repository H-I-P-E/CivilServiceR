from rocker/shiny:3.6.1
RUN apt-get update
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

COPY ./civil_service_jobs_explorer /srv/shiny-server/

COPY shiny-server.sh /usr/bin/shiny-server.sh

RUN [ "chmod", "+x", "/usr/bin/shiny-server.sh"]
RUN echo "preserve_logs true;" >> /etc/shiny-server/shiny-server.conf

CMD ["/usr/bin/shiny-server.sh"]

