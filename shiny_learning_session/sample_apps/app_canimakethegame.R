library(shiny)
library(tidyverse)
library(tibble)
library(lubridate)
library(ggmap)
library(googleway)
library(gmapsdistance)
library(shinycssloaders)
library(DT)

format_address_google_api <- function(string) {
    
    new_string <- gsub(' ', '+', string)
    new_string <- gsub(',', '', new_string)
    
    new_string
}

create_final_table <- function(list_element, 
                               address_data, 
                               mapped_times) {
    
    final_table <- tibble(date = address_data[[list_element]]$date[1],
                          from = gsub("\\+", " ", 
                                      address_data[[list_element]]$address[1]),
                          game_end_time = address_data[[list_element]]$end_time[1], 
                          to = gsub("\\+", " ", 
                                    address_data[[list_element]]$address[2]),
                          game_start_time = address_data[[list_element]]$start_time[2],
                          drive_time = mapped_times$drive_time[list_element], 
                          time_between_games = as.numeric(address_data[[list_element]]$start_time[2] - address_data[[list_element]]$end_time[1])/60, 
                          time_difference = time_between_games - drive_time,
                          message = ifelse(drive_time > time_between_games, paste0("Looks like you'll be late. You should arrive about ", abs(time_difference), " minutes late for the second game"), 
                                           ifelse(drive_time == time_between_games, "You can make it! Looks like you should arrive right at the start of the second game", 
                                                  paste0("You can make it! You should arrive about ", abs(time_difference), " minutes early for the second game")))
    )
    
    final_table <- final_table %>%
        select(date, from, game_end_time, to, game_start_time, drive_time, message)
    
    final_table
}

mapped_table_function <- function(input_table) {
    
    table <- input_table %>%
        mutate(address = format_address_google_api(address)) %>%
        rownames_to_column()
    
    combinations <- combn(table$rowname, 2, simplify = F)
    
    
    address_combinations <- map(.x = seq(1, length(combinations),1),
                                ~{table %>%
                                        filter(
                                            rowname %in%
                                                combinations[[.x]])})
    
    mapped_times <- map(.x = address_combinations,
                        ~gmapsdistance::gmapsdistance(
                            origin = .x$address[1],
                            destination = .x$address[2],
                            mode = "driving",
                            key = "AIzaSyAqysDyMM_zX-gLHIXGudGQiD2WPVso4eI"))
    
    mapped_times_minutes <- mapped_times %>%
        map(.x = .,
            ~{round(.x$Time/60,1)}) %>%
        bind_cols(.) %>%
        t() %>%
        tibble(drive_time = .)
    
    final_table_messages <- map_df(.x = seq(1,length(address_combinations),1),
                                   ~create_final_table(list_element = .x, 
                                                       address_combinations, 
                                                       mapped_times_minutes))
    
    return(final_table_messages)
}

# Define UI for application that draws a histogram
ui <- fluidPage(
    
    # Application title
    titlePanel("Can I Make the Game?"),
    
    tags$style(type="text/css",
               ".shiny-output-error { visibility: hidden; }",
               ".shiny-output-error:before { visibility: hidden; }"
    ),
        tabsetPanel(
            tabPanel("Main",
                     br(), 
                     fileInput(inputId = "file_csv",
                               "Upload properly formatted csv file. Please remove any dates for which only 1 game appears, otherwise the app will not work.",
                               multiple = FALSE,
                               accept = c(
                                   "text/csv",
                                   "text/comma-separated-values,text/plain",
                                   ".csv"),
                               width = '300px'),
                     div(p(
                         HTML(
                             paste0('For a sample, formatted csv file ', 
                                    a(href = 'https://drive.google.com/file/d/1iKijg9IjfzEB6jxxv3nO8VRrkFPfYj7J/view?usp=sharing', target="_blank", 'click here'))))),
                     withSpinner(dataTableOutput('message_table')), 
                     downloadButton("downloadData", "Download Table")), 
            tabPanel("About", 
                     br(), 
                     p("This tool allows users to estimate whether they can make it to two locations depending on where they leave from and when. Users can upload multiple locations and days so it’s easier to see where they might run into scheduling issues in a given day (which is our life now, hence the tool). Obviously, users can throw anything in--parties, business meetings, etc., the tool was just built with games in mind."), 
                     p("Users have to upload a file with all the data in the right format--and it needs to be saved as a csv (comma separated values) file, rather than as an Excel sheet (which you can do in any spreadsheet program). There is a link to a sample file users can refer to. Additionally, the output can be downloaded as a csv file."), 
                     p("The tool takes each date, generates all possible combinations between items, and then generates estimated drive times using the Google Maps API based on the most efficient route. No guarantee it won't be buggy, so please double check individual drive times manually."),
                     div(p(
                         HTML(
                             paste0('Built and maintained by ', 
                                    a(href = 'https://billpetti.github.io', target="_blank", 'Bill Petti')))))
                     
        )
    )    
)

# Define server logic required to draw a histogram
server <- function(input, output) {
    
    input_data <- reactive({
        
        inFile <- input$file_csv
        
        if (is.null(inFile)) {
            return(NULL)
        }
        
        df <- read_csv(inFile$datapath)
        
        df <- df %>%
            arrange(date, start_time)
        
        return(df)
    })
    
    mapped_table <- reactive({
        
        if(!is.null(input_data())) {
            
            df <- input_data() %>%
                split(.$date) %>%
                map_df(~mapped_table_function(.x))
            
            df <- df %>%
                arrange(desc(date), game_end_time) %>%
                mutate(game_end_time = sub("^0", "", format(strptime(
                    game_end_time, format='%H:%M:%S'), '%r')), 
                    game_end_time = gsub(":00 ", " ", game_end_time),
                    game_start_time = sub("^0", "", format(strptime(
                        game_start_time, format='%H:%M:%S'), '%r')), 
                    game_start_time = gsub(":00 ", " ", game_start_time))
            
            names(df) <- c("Date", "From", "Game End Time",
                           "To", "Next Game Start Time",
                           "Estimated Drive Time (minutes)","Message")
            
            return(df)}
    })
    
    output$message_table <- DT::renderDataTable({
        DT::datatable(mapped_table(), 
                      filter = 'top',
                      options = list(lengthChange = FALSE,
                                     pageLength = 100,
                                     lengthMenu = seq(50,1000,50)))
    })

    output$downloadData <- downloadHandler(
        filename = function() {
            paste(input$dataset, ".csv", sep = "")
        },
        content = function(file) {
            write.csv(mapped_table(), file, row.names = FALSE)
        }
    )
    
}

# Run the application 
shinyApp(ui = ui, server = server)
