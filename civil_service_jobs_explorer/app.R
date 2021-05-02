library(shiny)
library(DT)
library(shinythemes)
library(plotly)
library(readr)
library(botor)
####Parameters####

approachs <- c("External")
min_area_sum = 9
HIPE_colour = "#73BFBD"
app_title = "HIPE job search"
external_only = F
csv = T
DEBUG = F

####Data####

if(DEBUG){
  botor(aws_access_key_id, aws_secret_access_key, region_name = 'eu-west-2')
}

if(csv){
  data <- botor::s3_read("s3://civil-service-jobs/data/cleaned_data.csv", read_csv)
  grades_data <-  botor::s3_read("s3://civil-service-jobs/data/grades_data.csv", read_csv)
  key_words_data <- botor::s3_read("s3://civil-service-jobs/data/key_words_data.csv", read_csv)
  key_words_context <- botor::s3_read("s3://civil-service-jobs/data/key_words_context.csv", read_csv)
  roles_data <- botor::s3_read("s3://civil-service-jobs/data/roles_data.csv", read_csv)

  data <-data %>%
    dplyr::mutate(number_of_posts =`Number of posts`) %>%
    dplyr::mutate(closing_date =closingdate)}else{
  data <- readRDS(".//data//cleaned_data.rds")
  grades_data <-  readRDS(".//data//grades_data.rds")
  key_words_data <- readRDS(".//data//key_words.rds")
  key_words_context <- readRDS(".//data//key_words_context.rds")
  roles_data <- readRDS(".//data//roles_data.rds")
}
#//civil_service_jobs_explorer
if(external_only){
  data <- data %>%
    dplyr::filter(approach %in% approachs)
}

refs <- data$job_ref


departments <- unique(data$department) %>% sort()

acronyms <- readr::read_csv(".//www//dept_acronyms.csv")

grade_lookup <- readr::read_csv(".//www//grade_lookup.csv") %>%
  dplyr::select(label, order, name)

grades_data <-  grades_data %>%
  dplyr::filter(job_ref %in% refs) %>%
  dplyr::left_join(grade_lookup) %>%
  dplyr::mutate(label = name) %>%
  dplyr::select(-name, -order)

factor(grades_data$label, levels = grades_data$order)

grades <- unique(grade_lookup) %>% dplyr::arrange(desc(order)) %>%
  dplyr::pull(name)
#//civil_service_jobs_explorer
roles_data <-  roles_data%>%
  dplyr::filter(job_ref %in% refs)

roles <- unique(roles_data$label)

key_words_data <- key_words_data %>%
  dplyr::filter(job_ref %in% refs) %>%
  dplyr::left_join(key_words_context, by = c("label" = "label")) %>%
  dplyr::group_by(job_ref, `Cause area`) %>%
  dplyr::summarise(area_sum = sum(`Strength of association 1-9 (currently subjective)`*count, na.rm = T)) %>%
  dplyr::filter(area_sum >= min_area_sum)

key_words <- unique(key_words_data$`Cause area`) %>% sort()

months_in_data <- as.integer((max(data$date_downloaded, na.rm = T) -
                                min(data$date_downloaded, na.rm = T))/30.44)
####UI####

ui <- fluidPage(
  theme = "theme.css",
  titlePanel(title=div(a(href="https://hipe.org.uk/",
                         img(src="hipe_logo.png",
                           style="width: 100px; float:right"
                           ))
                       ,app_title),
             windowTitle = app_title),
  h3("Search Civil Service jobs by the type of social impact you could have", align = "left"),

  fluidRow(
    # Sidebar with a slider input for number of bins
    sidebarLayout(
      sidebarPanel(
        div(style = "font-size:20px;",
        selectInput("cause_area", "I care about:", key_words, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("grade_select", "Grade:", grades, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("role_select", "Role:", sort(roles), selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("dept_select", "Department:", departments, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL)),
        sliderInput("post_select", "Number of posts (within the advert):", 1, 100, value = c(1, 100)),
        h3(textOutput("text_description")),
        HTML("<p style=\"text-align:center;font-size:20px\">Top 10 departments for number of posts matching your selection in the last 12 months:"),
        plotlyOutput("dept_plot")
      ),
      mainPanel(
        if(!external_only){
          shiny::checkboxInput("include_internal", "Show internal jobs", value = FALSE)
        },
        shiny::checkboxInput("select_current", "Show only current jobs", value = TRUE),
        DT::dataTableOutput("mytable")
      )
      ),
    HTML(paste0("<p style=\"text-align:center;font-size:20px\"><br>This app is designed by the HIPE team to help civil servants and future civil servants plan an impactful career.
    <br>For more information about HIPE go <a href=\"https://hipe.org.uk\">here</a>.
    <br>For more information about this app go <a href=\"https://github.com/TWJolly/CivilServiceR/blob/master/README.md\">here </a>
    <br><br>Last updated: ", max(data$date_downloaded, na.rm = T) ,"</p>"))
  )
)

####Server####
server <- function(input, output) {

  output$HIPE_logo <- renderImage({
    list(src = './images/hipe_logo.png',
         width = 100,
         height = 100,
         alt = "HIPE logo")
  }, deleteFile = FALSE)

  filtered <- reactive({

    if(input$select_current){
      data <- data %>%
        dplyr::filter(closing_date > lubridate::today() & input$select_current)
    }
    if(!external_only){
      if(!input$include_internal){
        data <- data %>%
          dplyr::filter(approach %in% approachs)
      }
    }else{
      data <- data %>%
        dplyr::filter(approach %in% approachs)
    }

    if(!is.null(input$cause_area)){
      refs <- dplyr::filter(key_words_data, `Cause area` %in% input$cause_area) %>% dplyr::pull(job_ref)
      data <-  dplyr::filter(data, job_ref %in% refs)}

    if(!is.null(input$grade_select)){
      refs <- dplyr::filter(grades_data, label %in% input$grade_select) %>% dplyr::pull(job_ref)
      data <-  dplyr::filter(data, job_ref %in% refs)}

    if(!is.null(input$role_select)){
      refs <- dplyr::filter(roles_data, label %in% input$role_select) %>% dplyr::pull(job_ref)
      data <-  dplyr::filter(data, job_ref %in% refs)}

    if(!is.null( input$dept_select)){
      data <-  dplyr::filter(data, department %in% input$dept_select)}


    data <-  dplyr::filter(data, (number_of_posts >= input$post_select[[1]] & (number_of_posts <= input$post_select[[2]] | input$post_select[[2]]  == 100)) | is.na(number_of_posts))


    data <- data %>%
      tidyr::replace_na(list(number_of_posts = 1))

  })

  twelve_months_summary <- reactive({
    data <- data %>%
      dplyr::filter(closing_date >= lubridate::today() - lubridate::years(1))

    if(!external_only){
      if(!input$include_internal){
        data <- data %>%
          dplyr::filter(approach %in% approachs)
      }
    }else{
      data <- data %>%
        dplyr::filter(approach %in% approachs)
    }

    if(!is.null(input$cause_area)){
      refs <- dplyr::filter(key_words_data, `Cause area` %in% input$cause_area) %>% dplyr::pull(job_ref)
      data <-  dplyr::filter(data, job_ref %in% refs)}

    if(!is.null(input$grade_select)){
      refs <- dplyr::filter(grades_data, label %in% input$grade_select) %>% dplyr::pull(job_ref)
      data <-  dplyr::filter(data, job_ref %in% refs)}

    if(!is.null(input$role_select)){
      refs <- dplyr::filter(roles_data, label %in% input$role_select) %>% dplyr::pull(job_ref)
      data <-  dplyr::filter(data, job_ref %in% refs)}

    if(!is.null( input$dept_select)){
      data <-  dplyr::filter(data, department %in% input$dept_select)}


    data <-  dplyr::filter(data, (number_of_posts >= input$post_select[[1]] & (number_of_posts <= input$post_select[[2]] | input$post_select[[2]]  == 100)) | is.na(number_of_posts))


    data <- data %>%
      tidyr::replace_na(list(number_of_posts = 1))

  })

  date_filtered <- reactive({
    if(input$select_current){
      my_data <- filtered()
      data <-  dplyr::filter(my_data, closing_date > lubridate::today())}
    data
  })

  output$mytable <- DT::renderDataTable(
    DT::datatable({
    my_data <- filtered()



    my_data %>%
      dplyr::mutate(link_title = paste0("<a href='", link,"' target='_blank'>", title ,"</a>")) %>%
      dplyr::transmute(
        Title = ifelse(closing_date < lubridate::today(), title, link_title),
        Department = department,
        Grade = grade,
        Location = location,
        `Closing date` = closing_date
      )
  },options = list(pageLength = 20, autoWidth = TRUE),
  rownames= FALSE,
  escape = FALSE))

  output$text_description <- renderText ({

    jobs <- sum(twelve_months_summary()$number_of_posts, na.rm= T)
    adverts <- nrow(twelve_months_summary())
    rate <- as.integer(jobs/12)

    paste0("In the past 12 months, there have been ",prettyNum(jobs,big.mark=",",scientific=FALSE),
           " posts matching your search criteria, (across ",prettyNum(adverts,big.mark=",",scientific=FALSE) ,
           " adverts), this is a rate of ", prettyNum(rate,big.mark=",",scientific=FALSE),
           " posts per month")
  })

  output$dept_plot <- renderPlotly({
    my_data <- twelve_months_summary()
    grouped_data <- my_data %>%
      dplyr::group_by(department) %>%
      dplyr::summarise(number_of_posts = sum(number_of_posts, na.rm = T)) %>%
      dplyr::arrange(desc(number_of_posts)) %>%
      ungroup() %>%
      dplyr::left_join(acronyms, c("department" = "department")) %>%
      dplyr::mutate(acronym = ifelse(is.na(acronym), abbreviate(department, minlength = 2), acronym)) %>%
      head(10)

    p <- ggplot2::ggplot(grouped_data,
                        aes(x = reorder(acronym, number_of_posts) , y = number_of_posts, tooltip = department)) +
      ggplot2::geom_bar(stat = "identity", fill = HIPE_colour)  +
      coord_flip()+
      theme(text =element_text(family = "Helvetica",
                               colour = HIPE_colour,
                               size = 14),
            axis.title=element_blank(),
            axis.ticks=element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            panel.background = element_rect(fill = NA),
            axis.line = element_line(colour = "black"),
            axis.text = element_text(colour = HIPE_colour),
            plot.margin=margin(c(0,0,0,0)))
    ggplotly(p, tooltip = c("number_of_posts","tooltip")) %>% config(displayModeBar = F)
  })
}

# Run the application
shinyApp(ui = ui, server = server)

