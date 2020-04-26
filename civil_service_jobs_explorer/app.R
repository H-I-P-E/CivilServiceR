library(shiny)
library(DT)
library(shinythemes)
library(plotly)

####Parameters####

approachs <- c("External")
min_area_sum = 9
HIPE_colour = "#73BFBD"
app_title = "HIPE job search"
external_only = F

####Data####

data <- readRDS(".//data//cleaned_data.rds")

if(external_only){
  data <- data %>%
    dplyr::filter(approach %in% approachs)
}

refs <- data$job_ref

departments <- unique(data$department) %>% sort()

acronyms <- readr::read_csv(".//www//dept_acronyms.csv")

grades_data <-  readRDS(".//data//grades_data.rds")%>%
  dplyr::filter(job_ref %in% refs)

grades <- unique(grades_data$label) %>% sort()

roles_data <-  readRDS(".//data//roles_data.rds")%>%
  dplyr::filter(job_ref %in% refs)

roles <- unique(roles_data$label)

key_words_context <- readRDS(".//data//key_words_context.rds")

key_words_data <- readRDS(".//data//key_words.rds") %>%
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
  titlePanel(title=div(img(src="hipe_logo.png",
                           style="width: 100px; float:right")
                       ,app_title),
             windowTitle = app_title),
  h3("Search for impactful jobs in the Civil Service", align = "left"),

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
        h3(textOutput("text_description")),
        plotlyOutput("dept_plot")
      ),
      mainPanel(
        if(!external_only){
          shiny::checkboxInput("include_internal", "Show internal jobs", value = FALSE)
        },
        shiny::checkboxInput("select_current", "Show only current jobs", value = FALSE),
        DT::dataTableOutput("mytable")
      )
    )
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
      dplyr::mutate(Title = paste0("<a href='", link,"' target='_blank'>", title ,"</a>")) %>%
      dplyr::transmute(
        Title = Title,
        Department = department,
        Grade = grade,
        Location = location,
        `Closing date` = closing_date
      )
  },options = list(pageLength = 20, autoWidth = TRUE),
  rownames= FALSE,
  escape = FALSE))

  output$text_description <- renderText ({


    jobs <- sum(filtered()$number_of_posts, na.rm= T)
    rate <- as.integer(jobs/months_in_data)

    paste0("In the past ", prettyNum(months_in_data,big.mark=",",scientific=FALSE), " months, there have been ",prettyNum(jobs,big.mark=",",scientific=FALSE), " posts matching your search criteria,
            this is a rate of ", prettyNum(rate,big.mark=",",scientific=FALSE), " posts per month")
  })

  output$dept_plot <- renderPlotly({
    my_data <- filtered()
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
      labs(title = "Top 10 departments for number of\nposts matching your selection")+
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
            plot.title = element_text(hjust = 0,
                                      margin=margin(0,0,30,0)),
            plot.margin=margin(c(30,0,0,0)))
    ggplotly(p, tooltip = c("number_of_posts","tooltip")) %>% config(displayModeBar = F)
  })
}

# Run the application
shinyApp(ui = ui, server = server)

