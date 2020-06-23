# display a table of the data and download the underlying data

library(shiny)
library(DT)

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

  # Show a table of the data
  mainPanel(
    DTOutput("faithful_data"),
    downloadButton(outputId = "download_data", label = "Download")
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  output$faithful_data <- renderDT({
    DT::datatable(faithful)
  })

  output$download_data <- downloadHandler(

    filename = function() {
      paste("dataset", ".csv", sep = "")
    },
    content = function(file) {
      write.csv(faithful, file, row.names = FALSE)
    }


  )
}

# Run the application
shinyApp(ui = ui, server = server)
