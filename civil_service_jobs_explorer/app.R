#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(DT)

approachs <- c("External")

data <- readRDS(".//data//cleaned_data.rds") %>%
  dplyr::filter(stringr::str_trim(approach) %in% approachs)

refs <- data$job_ref

departments <- unique(data$department)

grades_data <-  readRDS(".//data//grades_data.rds")%>%
  dplyr::filter(job_ref %in% refs)

grades <- unique(grades_data$label)

roles_data <-  readRDS(".//data//roles_data.rds")%>%
  dplyr::filter(job_ref %in% refs)

roles <- unique(roles_data$label)

key_words_context <- readRDS(".//data//key_words_context.rds")

min_area_sum = 9

key_words_data <- readRDS(".//data//key_words.rds") %>%
  dplyr::filter(job_ref %in% refs) %>%
  dplyr::left_join(key_words_context, by = c("label" = "label")) %>%
  dplyr::group_by(job_ref, `Cause area`) %>%
  dplyr::summarise(area_sum = sum(`Strength of association 1-9 (currently subjective)`*count, na.rm = T)) %>%
  dplyr::filter(area_sum >= min_area_sum)

key_words <- unique(key_words_data$`Cause area`)

months_in_data <- as.integer((max(data$date_downloaded, na.rm = T) -
                       min(data$date_downloaded, na.rm = T))/30.44)
#policy area
#currently available

# Define UI for application that draws a histogram
ui <- fluidPage(

   # Application title
   titlePanel("HIPE job explorer"),

   # Sidebar with a slider input for number of bins
   sidebarLayout(
      sidebarPanel(
        selectInput("cause_area", "I care about", key_words, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("grade_select", "Grade", grades, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("role_select", "Role", sort(roles), selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("dept_select", "Department", departments, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        radioButtons("select_current", "Show only current jobs", c(""),  selected = character(0)),
        h3(textOutput("text_description"))
      ),

      # Show a plot of the generated distribution
      mainPanel(
        DT::dataTableOutput("mytable")
      )
   )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  filtered <- reactive({

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

    if(!is.null(input$select_current)){
      data <-  dplyr::filter(data, closing_date > lubridate::today())}

    data <- data %>%
      tidyr::replace_na(list(number_of_posts = 1))

  })

   output$mytable <- DT::renderDataTable({
     my_data <- filtered()
     my_data %>%
       dplyr::transmute(
         Title = title,
         Department = department,
         Grade = grade,
         `Closing date` = closing_date
       )
     })

   output$text_description <- renderText ({

     jobs <- sum(filtered()$number_of_posts, na.rm= T)
     rate <- as.integer(jobs/months_in_data)

     paste0("In the past ", prettyNum(months_in_data,big.mark=",",scientific=FALSE), " months, there have been ",prettyNum(jobs,big.mark=",",scientific=FALSE), " posts matching your search criteria,
            this is a rate of ", prettyNum(rate,big.mark=",",scientific=FALSE), " posts per month")
   })
}

# Run the application
shinyApp(ui = ui, server = server)

