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

stages <- c("External")

data <- readRDS("data\\cleaned_data.rds") %>%
  dplyr::filter(stage %in% stages)

grades <- unique(data$grade)
departments <- unique(data$department)

months_in_data <- as.integer((max(data$date_downloaded, na.rm = T) -
                       min(data$date_downloaded, na.rm = T))/30.44)
#role_type
#policy area
#currently available

# Define UI for application that draws a histogram
ui <- fluidPage(

   # Application title
   titlePanel("HIPE job explorer"),

   # Sidebar with a slider input for number of bins
   sidebarLayout(
      sidebarPanel(
        selectInput("grade_select", "Grade", grades, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        selectInput("dept_select", "Department", departments, selected = NULL, multiple = TRUE,
                    selectize = TRUE, width = NULL, size = NULL),
        textOutput("text_description")
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

    if(!is.null(input$grade_select)){
      data <-  dplyr::filter(data, grade %in% input$grade_select)}

    if(!is.null( input$dept_select)){
      data <-  dplyr::filter(data, department %in% input$dept_select)}

    data <- data %>%
      tidyr::replace_na(list(number_of_posts = 1))

  })

   output$mytable <- DT::renderDataTable({filtered()})

   output$text_description <- renderText({

     jobs <- sum(filtered()$number_of_posts, na.rm= T)
     rate <- as.integer(jobs/months_in_data)

     paste0("In the past ", months_in_data, " months, there have been ",jobs, " posts matching your search criteria,
            this is a rate of ", rate, " posts per month")
   })
}

# Run the application
shinyApp(ui = ui, server = server)

