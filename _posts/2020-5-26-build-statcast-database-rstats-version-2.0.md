---
layout: post
title: How to Build a Statcast Database from BaseballSavant, v2.0
tags: [R, statacast, baseballr]
---

Two years ago I [wrote a post about](https://t.co/gwjUkXzmX7?amp=1) how to create a database of Statcast data using the [`baseballr` package for R](http://billpetti.github.io/baseballr/). I, and others, have made improvements to the `scrape_statcast_savant` function to make is easier to automate the build.

As before, the trick is to go year by year and, at most, week by week. [BaseballSavant](https://baseballsavant.mlb.com) limits the size of any query to about 40,000 rows, or one week of games.

I place all my data in a PostgreSQL database, so the code below assumes you are dumping your data in a similar set up. Of course, you can use whatever database type you choose.

First, load the following packages:

```r
library(baseballr)
library(tidyverse)
library(DBI)
library(RPostgreSQL)
library(myDBconnections)
```
***Note: `myDBconnections` is a personal package that makes it simpler for me to connecting to my existing databases, local and remoate***

Second, we load some helper functions. The first is the main function for creating the week breaks and dates for scraping game data:

```r

annual_statcast_query <- function(season) {
  
  dates <- seq.Date(as.Date(paste0(season, '-03-01')),
                    as.Date(paste0(season, '-12-01')), by = 'week')
  
  date_grid <- tibble(start_date = dates, 
                      end_date = dates + 6)
  
  safe_savant <- safely(scrape_statcast_savant)
  
  payload <- map(.x = seq_along(date_grid$start_date), 
                 ~{message(paste0('\nScraping week of ', date_grid$start_date[.x], '...\n'))
                   
                   payload <- safe_savant(start_date = date_grid$start_date[.x], 
                                          end_date = date_grid$end_date[.x], type = 'pitcher')
                   
                   return(payload)
                 })
  
  payload_df <- map(payload, 'result')
  
  number_rows <- map_df(.x = seq_along(payload_df), 
                        ~{number_rows <- tibble(week = .x, 
                                                number_rows = length(payload_df[[.x]]$game_date))}) %>%
    filter(number_rows > 0) %>%
    pull(week)
  
  payload_df_reduced <- payload_df[number_rows]
  
  combined <- payload_df_reduced %>%
    bind_rows()
  
  return(combined)
  
}
```

Let's step through this. The first action takes the season of interest and creates weeks of dates starting in March and through the end of November. This means you will pick uop some Spring Training games and all Postseason games. Next, it creates a grid of the weeks with start and ending dates--end dates simply being 6 days after the start date. Then we need to create a 'safe' version of the `scrape_statcast_savant` function so that if a week doesn't process we can capture that side effect without stopping the entire loop.

The big action comes with the `map` function. Here, we are looping over each row of the `date_grid`, using each date as the start and end dates. For each row, the function will print a message letting you know which week is being acquired. After the function runs, it collects each weeek into a dataframe within a larger list by isolating all `result` objects (as opposed to errors) and then eliminating any `result` that contains an empty dataframe. This makes binding less problematic.

I have an additional function that I run over each season's worth of data to add variables and ensure that all columns are consistent in class for appending to the database.

```r
format_append_statcast <- function(df) {
  
  # function for appending new variables to the data set
  
  additional_info <- function(df) {
    
    # apply additional coding for custom variables
    
    df$hit_type <- with(df, ifelse(type == "X" & events == "single", 1,
                                   ifelse(type == "X" & events == "double", 2,
                                          ifelse(type == "X" & events == "triple", 3, 
                                                 ifelse(type == "X" & events == "home_run", 4, NA)))))
    
    df$hit <- with(df, ifelse(type == "X" & events == "single", 1,
                              ifelse(type == "X" & events == "double", 1,
                                     ifelse(type == "X" & events == "triple", 1, 
                                            ifelse(type == "X" & events == "home_run", 1, NA)))))
    
    df$fielding_team <- with(df, ifelse(inning_topbot == "Bot", away_team, home_team))
    
    df$batting_team <- with(df, ifelse(inning_topbot == "Bot", home_team, away_team))
    
    df <- df %>%
      mutate(barrel = ifelse(launch_angle <= 50 & launch_speed >= 98 & launch_speed * 1.5 - launch_angle >= 117 & launch_speed + launch_angle >= 124, 1, 0))
    
    df <- df %>%
      mutate(spray_angle = round(
        (atan(
          (hc_x-125.42)/(198.27-hc_y)
        )*180/pi*.75)
        ,1)
      )
    
    df <- df %>%
      filter(!is.na(game_year))
    
    return(df)
  }
  
  df <- df %>%
    additional_info()
  
  df$game_date <- as.character(df$game_date)
  
  df <- df %>%
    arrange(game_date)
  
  df <- df %>%
    filter(!is.na(game_date))
  
  df <- df %>%
    ungroup()
  
  df <- df %>%
    select(setdiff(names(.), c("error")))
  
  cols_to_transform <- c("fielder_2", "pitcher_1", "fielder_2_1", "fielder_3",
                         "fielder_4", "fielder_5", "fielder_6", "fielder_7",
                         "fielder_8", "fielder_9")
  
  df <- df %>%
    mutate_at(.vars = cols_to_transform, as.numeric) %>%
    mutate_at(.vars = cols_to_transform, function(x) {
      ifelse(is.na(x), 999999999, x)
    })
  
  data_base_column_types <- read_csv("https://app.box.com/shared/static/q326nuker938n2nduy81au67s2pf9a3j.csv")
  
  character_columns <- data_base_column_types %>%
    filter(class == "character") %>%
    pull(variable)
  
  numeric_columns <- data_base_column_types %>%
    filter(class == "numeric") %>%
    pull(variable)
  
  integer_columns <- data_base_column_types %>%
    filter(class == "integer") %>%
    pull(variable)
  
  df <- df %>%
    mutate_if(names(df) %in% character_columns, as.character) %>%
    mutate_if(names(df) %in% numeric_columns, as.numeric) %>%
    mutate_if(names(df) %in% integer_columns, as.integer)
   
  return(df)
}
```

Finally, this function will automate uploading to your database: 

```r
delete_and_upload <- function(df, 
                              year, 
                              db_driver = "PostgreSQL", 
                              dbname, 
                              user, 
                              password, 
                              host = 'local_host', 
                              port = 5432) {
  
  pg <- dbDriver(db_driver)
  
  statcast_db <- dbConnect(pg, 
                           dbname = dbname, 
                           user = user, 
                           password = password,
                           host = host, 
                           port = posrt)
  
  query <- paste0('DELETE from statcast where game_year = ', year)
  
  dbGetQuery(statcast_db, query)
  
  dbWriteTable(statcast_db, "statcast", df, append = TRUE)
  
  dbDisconnect(statcast_db)
  rm(statcast_db)
}

``` 

This function established a connection to your database, removes any existing data with the same `game_year` as your fresh upload, then appends the new data to the table. I do this to ensure no duplicates and a clean data set as BaseballSavant will often times update data from previous seasons.

Now that we have our functions we are ready to roll.

If you don't have an existing database set up, I typically run the first year alone and then use the map function to handle the rest:

```r
# create table and upload first year
 
payload_statcast <- annual_statcast_query(2008)
 
df <- format_append_statcast(df = payload_statcast)
 
# connect to your database
# here I am using my personal package that has a wrapper function for this

statcast_db <- myDBconnections::connect_Statcast_postgreSQL()

dbWriteTable(statcast_db, "statcast", df, overwrite = TRUE)

# disconnect from database

myDBconnections::disconnect_Statcast_postgreSQL(statcast_db)
 
rm(df)
gc()
``` 
 
We can check to make sure the datbase exists and houses the data:

```r
statcast_db <- myDBconnections::connect_Statcast_postgreSQL()

tbl(statcast_db, 'statcast') %>%
  filter(game_year == 2008) %>%
  count()
  
#       n
#   <dbl>
#1 722525
  
```

Now we are ready to roll. We can map over the remaining years, 2009 through 2019, using the following code:


```r
map(.x = seq(2009, 2019, 1), 
    ~{payload_statcast <- annual_statcast_query(season = .x)
    
    message(paste0('Formatting payload for ', .x, '...'))
    
    df <- format_append_statcast(df = payload_statcast)
    
    message(paste0('Deleting and uploading ', .x, ' data to database...'))
    
    delete_and_upload(df, 
                      year = .x, 
                      db_driver = 'PostgreSQL', 
                      dbname = 'your_db_name', 
                      user = 'your_user_name', 
                      password = 'your_password', 
                      host = 'local_host', 
                      port = 5432)
    
    statcast_db <- myDBconnections::connect_Statcast_postgreSQL()
    
    dbGetQuery(statcast_db, 'select game_year, count(game_year) from statcast group by game_year')
    
    myDBconnections::disconnect_Statcast_postgreSQL(statcast_db)
    
    message('Sleeping and collecting garbage...')
    
    Sys.sleep(5*60)
    
    gc()
    
    })
```

You can see I included some additional messages to keep you sane during the process, as well as 5 minutes of sleep inbetween each season.

The entire process can take anywhere between 70-120 minutes.

When you are done, your data should look something like this:

```r 
tbl(statcast_db, 'statcast') %>%
  group_by(game_year) %>%
  count() %>%
  collect()
  
# game_year n
# 2008 722525
# 2009 726125
# 2010 719561
# 2011 718963
# 2012 716238
# 2013 720702
# 2014 714305
# 2015 712840
# 2016 726023
# 2017 732476
# 2018 731207
# 2019 743572

```

I also highly recommend indexing the database to make your queries run faster where possible. Here are the standard one's I create whenever the database gets updated:

```r

dbGetQuery(statcast_db, "drop index statcast_index")

dbGetQuery(statcast_db, "create index statcast_index on statcast (game_date)")

dbGetQuery(statcast_db, "drop index statcast_game_year")

dbGetQuery(statcast_db, "create index statcast_game_year on statcast (game_year)")

dbGetQuery(statcast_db, "drop index statcast_type")

dbGetQuery(statcast_db, "create index statcast_type on statcast (type)")

dbGetQuery(statcast_db, "drop index statcast_pitcher_index")

dbGetQuery(statcast_db, "create index statcast_pitcher_index on statcast (pitcher)")

dbGetQuery(statcast_db, "drop index statcast_batter_index")

dbGetQuery(statcast_db, "create index statcast_batter_index on statcast (batter)")

```

Hopefully this helps and if you have any questions, feel free to reach out.
