# tabset panel example

library(shiny)
library(DT)

ui <- fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

  tabsetPanel(
    tabPanel('plot',
        plotOutput("faithful_plot")),
    tabPanel('table',
        DTOutput('faithful_data'))

  )
)



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
