# display a plot of the data

library(shiny)
library(ggplot2)

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

  # Show a table of the data
  mainPanel(
    plotOutput("faithful_plot"),
    downloadButton(outputId = "download_plot", label = "Download")
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  plot <- reactive({

    ggplot(data = faithful,
           aes(x = waiting)) +
      geom_histogram()

  })

  output$faithful_plot <- renderPlot(expr = plot())

  output$download_plot <- downloadHandler(
    filename = function(){
      paste('test', '.png', sep = '')
    },
    content = function(file){
      ggsave(file,
             plot=plot())
    }
  )
}

# Run the application
shinyApp(ui = ui, server = server)
