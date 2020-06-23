# observe an event, then take action
# using action buttons

library(shiny)
library(tidyverse)

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Old Faithful Geyser Data"),

  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      sliderInput("bins",
                  "Number of bins:",
                  min = 1,
                  max = 50,
                  value = 30),
      actionButton("button", "Plot Data")
    ),

    # Show a plot of the generated distribution
    mainPanel(
      plotOutput("distPlot")
    )
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  bin_size <- eventReactive(input$button, {

    # generate bins based on input$bins from ui.R
    x    <- faithful[, 2]
    bins <- seq(min(x), max(x), length.out = input$bins + 1)
    return(bins)
  })

  output$distPlot <- renderPlot({
    # draw the histogram with the specified number of bins
    x <- faithful[, 2]
    hist(x, breaks = bin_size(), col = 'darkgray', border = 'white')
  })

}

# Run the application
shinyApp(ui = ui, server = server)
