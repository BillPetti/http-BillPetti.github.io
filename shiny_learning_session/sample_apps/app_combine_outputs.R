# combine outputs in the same panel

library(shiny)
library(ggplot2)
library(DT)

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

    # vertical

    # plotOutput("faithful_plot"),
    # br(),
    # DTOutput('faithful_data')

    # horizontal
    column(6, plotOutput("faithful_plot")),
    column(6, DTOutput('faithful_data'))

)

# Define server logic required to draw a histogram
server <- function(input, output) {


  output$faithful_plot <- renderPlot({
    ggplot(data = faithful,
           aes(x = waiting)) +
      geom_histogram()
  })

  output$faithful_data <- renderDT({
    DT::datatable(faithful)
  })
}

# Run the application
shinyApp(ui = ui, server = server)
