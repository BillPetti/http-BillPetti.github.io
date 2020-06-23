library(shiny)
library(tidyverse)
library(palmerpenguins)
library(DT)

penguins <- penguins

custom_theme <- function(base_size = 12, base_family = "Helvetica") {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      axis.text = element_text(face = "bold", size = rel(.9)),
      axis.text.x = element_text(
        margin = margin(t = 0.1, r = 0, b = .35, l = 0, unit = "cm")),
      axis.text.y = element_text(
        margin = margin(t = 0, r = .1, b = 0, l = .35, unit = "cm")),
      axis.title = element_text(face = "bold", size = rel(1.1)),
      strip.text.x = element_text(face = "bold", size = rel(1.05),
                                  margin =
                                    margin(t = .15, r = 0, b = .25, l = 0, unit = "cm")),
      legend.title = element_text(face = "bold"),
      legend.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold",
                                hjust = 0,
                                size = rel(1.45),
                                margin = margin(t = 0.2,
                                                b = 0.13,
                                                unit = "cm")),
      plot.subtitle = element_text(hjust = 0,
                                   margin = margin(t = 0.1,
                                                   b = 0.35,
                                                   unit = "cm")),
      plot.background = element_rect(fill="#F0F0F0", color=NA),
      panel.background = element_rect(fill="#F0F0F0", color=NA),
      panel.grid.major = element_line(colour="#FFFFFF",size=.75)
    )
}


ui <- fluidPage(

  # Application title
  titlePanel("Clustering Penguins"),

  sidebarLayout(
    sidebarPanel(numericInput('centers',
                              label = "Choose Number of Centers",
                              value = 3,
                              min = 2,
                              max = 10),
                 selectInput('x',
                             label = 'Choose X Axis',
                             selected = "bill_length_mm",
                             choices = c("species", "bill_length_mm", "bill_depth_mm",
                                         "flipper_length_mm", "body_mass_g", "sex")),
                 selectInput('y',
                             label = 'Choose Y Axis',
                             selected = "bill_depth_mm",
                             choices = c("species", "bill_length_mm", "bill_depth_mm",
                                         "flipper_length_mm", "body_mass_g", "sex")),
                 width = 2),

    mainPanel(plotOutput('clusterPlot',
                         brush = brushOpts(id = 'clusterPlotbrush')),
              br(),
              br(),
              DTOutput('cluster_table')))

)

server <- function(input, output) {

  clusters <- reactive({

    set.seed(42)

    df <- penguins %>%
      mutate(sex = ifelse(sex == 'male', 1, 0),
             sex = as.numeric(sex)) %>%
      filter(complete.cases(.))

    df_normalized <- df %>%
      select_if(is.numeric) %>%
      mutate_all(scale)

    payload <- kmeans(df_normalized, centers = input$centers, iter.max = 400)

    return(payload)
  })

  output$clusters <- renderText({

    clusters()$centers

  })

  joined_data <- reactive({

    clusters_vector <- clusters()$cluster

    df_clusters <- penguins %>%
      filter(complete.cases(.)) %>%
      mutate(cluster = as.factor(clusters_vector))

    return(df_clusters)
  })

  output$clusterPlot <- renderPlot({

    plot <- joined_data() %>%
      ggplot(aes_string(input$x, input$y)) +
      geom_point(aes(color = cluster), size = 2, alpha = .75) +
      custom_theme()

    return(plot)
  }, height = 400, width = 1000)

  output$brush_info <- renderPrint({
    brushedPoints(joined_data(), input$clusterPlotbrush)
  })

  brushed_points <- reactive({

    brushedPoints(joined_data(), input$clusterPlotbrush)

  })

  summarized <- reactive({

    numeric_cols <- joined_data() %>%
      select_if(is.numeric) %>%
      names()

    brushedPoints(joined_data(), input$clusterPlotbrush) %>%
      select(cluster, one_of(numeric_cols)) %>%
      group_by(cluster) %>%
      mutate(count = n()) %>%
      group_by(cluster, count) %>%
      summarise_all(mean) %>%
      ungroup() %>%
      mutate_if(is.numeric, round, 1)

  })
  output$cluster_table <- renderDT({

    DT::datatable(summarized())
  })
}

# Run the application
shinyApp(ui = ui, server = server)

