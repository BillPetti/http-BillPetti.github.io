# display a table of the data

library(shiny)
library(DT)

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

  # Show a table of the data
    mainPanel(
      DTOutput("faithful_data")
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  output$faithful_data <- renderDT({
    DT::datatable(faithful)
  })
}

# Run the application
shinyApp(ui = ui, server = server)
