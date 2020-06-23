# make available values for one input dependend
# on selections from another

library(shiny)
library(tidyverse)


get_game_pks_mlb <- function (date,
                              level_ids = c(1)) {
  api_call <- paste0("http://statsapi.mlb.com/api/v1/schedule?sportId=",
                     paste(level_ids, collapse = ","), "&date=", date)
  payload <- jsonlite::fromJSON(api_call, flatten = TRUE)
  payload <- payload$dates$games %>% as.data.frame() %>% rename(game_pk = gamePk)
  return(payload)
}


# Define UI for application that draws a histogram
ui <- fluidPage(

  # Application title
  titlePanel("Conditional Filters"),

  dateInput("date",
            "Choose or enter a date (YYYY-MM-DD)",
            value = '2019-04-01'),
  uiOutput('matchups')

)

# Define server logic required to draw a histogram
server <- function(input, output) {

  output$matchups <- renderUI({

    games <- get_game_pks_mlb(input$date) %>%
      mutate(matchup =
               paste0(teams.away.team.name, " at ",
                      teams.home.team.name))

    matchups <- games %>%
      pull(matchup)

    selectizeInput("matchups_for_date",
                   "Select a game",
                   matchups,
                   width = 350)
  })
}

# Run the application
shinyApp(ui = ui, server = server)
