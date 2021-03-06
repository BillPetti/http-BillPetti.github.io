---
layout: post
title: Using the Yelp API with R
tags: [R, httr, API, Yelp]
---

This is a guide to using the Yelp API with R. The approach borrows liberally from advice [published by Jenny Bryan](https://github.com/jennybc/yelpr).

First, load required packages:

```r
require(tidyverse)
require(httr)
```

Second, create a token for use with your API request. This requires that you have a `client_id` and a `client_secret`, both of which are provided when you [create an app through their developer area](https://www.yelp.com/developers/v3/manage_app):

```r
client_id <- "your client_id"
client_secret <- "your client_secret"

res <- POST("https://api.yelp.com/oauth2/token",
            body = list(grant_type = "client_credentials",
                        client_id = client_id,
                        client_secret = client_secret))

token <- content(res)$access_token
```

Next, you build the url for your query. In this example, we will query businesses with the term `sports` within 5 miles of Philadelphia:

```r
yelp <- "https://api.yelp.com"
term <- "sports"
location <- "Philadelphia, PA"
categories <- NULL
limit <- 50
radius <- 8000
url <- modify_url(yelp, path = c("v3", "businesses", "search"),
                  query = list(term = term, location = location, 
                               limit = limit,
                               radius = radius))
res <- GET(url, add_headers('Authorization' = paste("bearer", token)))

results <- content(res)
```

Now that we have the data we can create a function to parse and format the data:

```r
yelp_httr_parse <- function(x) {

  parse_list <- list(id = x$id, 
                     name = x$name, 
                     rating = x$rating, 
                     review_count = x$review_count, 
                     latitude = x$coordinates$latitude, 
                     longitude = x$coordinates$longitude, 
                     address1 = x$location$address1, 
                     city = x$location$city, 
                     state = x$location$state, 
                     distance = x$distance)
  
  parse_list <- lapply(parse_list, FUN = function(x) ifelse(is.null(x), "", x))
  
  df <- data_frame(id=parse_list$id,
                   name=parse_list$name, 
                   rating = parse_list$rating, 
                   review_count = parse_list$review_count, 
                   latitude=parse_list$latitude, 
                   longitude = parse_list$longitude, 
                   address1 = parse_list$address1, 
                   city = parse_list$city, 
                   state = parse_list$state, 
                   distance= parse_list$distance)
  df
}

results_list <- lapply(results$businesses, FUN = yelp_httr_parse)

payload <- do.call("rbind", results_list)
```

And here are our results:

![alt text](https://github.com/BillPetti/BillPetti.github.io/blob/master/_posts/yelp_api_1.png?raw=true "yelp api 1")

We can wrap the previous steps into a single function:

```r
yelp_business_search <- function(term = NULL, location = NULL, 
                                 categories = NULL, radius = NULL, 
                                 limit = 50, client_id = NULL, 
                                 client_secret = NULL) {
  
  yelp <- "https://api.yelp.com"
  url <- modify_url(yelp, path = c("v3", "businesses", "search"),
               query = list(term = term, location = location, limit = limit, 
                            radius = radius, categories = categories))
  res <- GET(url, add_headers('Authorization' = paste("bearer", token)))
  results <- content(res)
  
  yelp_httr_parse <- function(x) {
  
  parse_list <- list(id = x$id, 
                     name = x$name, 
                     rating = x$rating, 
                     review_count = x$review_count, 
                     latitude = x$coordinates$latitude, 
                     longitude = x$coordinates$longitude, 
                     address1 = x$location$address1, 
                     city = x$location$city, 
                     state = x$location$state, 
                     distance = x$distance)
  
  parse_list <- lapply(parse_list, FUN = function(x) ifelse(is.null(x), "", x))
  
  df <- data_frame(id=parse_list$id,
                   name=parse_list$name, 
                   rating = parse_list$rating, 
                   review_count = parse_list$review_count, 
                   latitude=parse_list$latitude, 
                   longitude = parse_list$longitude, 
                   address1 = parse_list$address1, 
                   city = parse_list$city, 
                   state = parse_list$state, 
                   distance= parse_list$distance)
  df
}
  results_list <- lapply(results$businesses, FUN = yelp_httr_parse)
  payload <- do.call("rbind", results_list)
  payload <- payload %>%
    filter(grepl(term, name))
  
  payload
}
```
Now, we can use that function to find all Dunkin Donuts locations within 10 miles of Philadelphia, PA:

```r
results <- yelp_business_search(term = "Dunkin' Donuts", 
                                location = "Philadelphia, PA",
                                radius = 16000, 
                                client_id = client_id, 
                                client_secret = client_secret)
```

And our results:

![alt text](https://github.com/BillPetti/BillPetti.github.io/blob/master/_posts/yelp_api_2.png?raw=true "yelp api 2")

