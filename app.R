# Interactive companion to the reproducible INEGI analysis.
# Run from the repository root: shiny::runApp(".")
# Data source: already-validated CSV outputs in data/processed/.

library(shiny)
library(plotly)

states_path <- file.path("data", "processed", "healthcare_states_with_counts.csv")
national_path <- file.path("data", "processed", "healthcare_national.csv")
if (!file.exists(states_path) || !file.exists(national_path)) {
  stop("Missing processed CSV files. See README.md for analysis instructions.")
}

states_data <- read.csv(states_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                        check.names = FALSE)
national_data <- read.csv(national_path, stringsAsFactors = FALSE, check.names = FALSE)
required_states <- c("state", "year", "healthcare_deprivation_pct", "people_millions")
required_national <- c("year", "national_deprivation_pct", "national_people_millions")
if (!all(required_states %in% names(states_data)) ||
    !all(required_national %in% names(national_data))) {
  stop("The processed data schema does not match the required fields.")
}
if (anyNA(states_data[, required_states]) || anyNA(national_data[, required_national])) {
  stop("Processed data contain missing values in required fields.")
}
if (anyDuplicated(states_data[, c("state", "year")]) ||
    anyDuplicated(national_data["year"])) {
  stop("Unexpected duplicate state-year or national-year records.")
}
years <- sort(unique(states_data$year))
available_states <- sort(unique(states_data$state))
if (length(available_states) != 32 || length(years) != 5) {
  warning("The current dataset differs from the documented 32-state, five-year coverage.")
}
fmt <- function(x, digits = 2) formatC(x, format = "f", digits = digits, big.mark = ",")

ui <- fluidPage(
  tags$head(tags$style(HTML("
    body {background: #f5f7fb; color: #172b4d; font-family: system-ui, Arial, sans-serif;}
    .container-fluid {max-width: 1450px; padding: 20px 26px;}
    .hero {background: linear-gradient(110deg,#122541,#174d70);
           color: white; border-radius: 18px; padding: 25px 30px; margin-bottom: 18px;}
    .hero h2 {font-size: 31px; font-weight: 750; margin: 3px 0;}
    .hero p {color: #d4e5f4; margin: 5px 0 0;}
    .panel-card, .well {background: white; border: 1px solid #e1e8f2;
           border-radius: 14px; box-shadow: 0 3px 12px rgba(20,38,60,.035); padding: 17px;}
    .stat-value {font-size: 28px; font-weight: 760; color: #183657;}
    .stat-label {font-size: 13px; color: #63748a; font-weight: 600;}
    .note {font-size: 12px; color: #5d6b82;}
    .section-title {font-weight: 750; margin-top: 16px; margin-bottom: 12px;}
    .control-label {font-weight: 600;}
    .shiny-output-error-validation {color: #8a4b18;}
  "))),
  div(class = "hero",
      tags$small("R SHINY · PUBLIC DATA EXPLORER"),
      h2("Healthcare Access in Mexico"),
      p("Explore estimated healthcare-access deprivation across Mexico's 32 states (2016–2024).")
  ),
  sidebarLayout(
    sidebarPanel(width = 3,
      h4("Explore the data"),
      selectInput("year", "Reference year", choices = years, selected = max(years)),
      selectInput("measure", "Comparison metric",
                  choices = c("Deprivation rate (%)" = "healthcare_deprivation_pct",
                              "People affected (millions)" = "people_millions")),
      selectizeInput("states", "States for trend comparison",
                     choices = available_states,
                     selected = c("Nuevo León", "Chiapas", "Estado de México"),
                     multiple = TRUE,
                     options = list(placeholder = "Choose one or more states")),
      checkboxInput("compare_national", "Show official national benchmark", TRUE),
      downloadButton("download_filtered", "Download selected year's data"),
      tags$hr(),
      tags$p(class = "note", "Source: INEGI, Multidimensional Poverty 2024. ",
             "Data are point estimates, not clinical service or care-quality measures."),
      tags$p(class = "note", "Five reference years only: 2016, 2018, 2020, 2022 and 2024. ",
             "Connecting these points does not imply annual observations.")
    ),
    mainPanel(width = 9,
      fluidRow(
        column(4, div(class = "panel-card", div(class = "stat-label", "National deprivation rate"),
                      div(class = "stat-value", textOutput("national_pct", inline = TRUE)),
                      div(class = "note", "Official national estimate"))),
        column(4, div(class = "panel-card", div(class = "stat-label", "People affected nationwide"),
                      div(class = "stat-value", textOutput("national_people", inline = TRUE)),
                      div(class = "note", "Millions of people"))),
        column(4, div(class = "panel-card", div(class = "stat-label", "State with highest rate"),
                      div(class = "stat-value", textOutput("highest_state", inline = TRUE)),
                      div(class = "note", textOutput("highest_rate", inline = TRUE))))
      ),
      h3(class = "section-title", "Compare states"),
      div(class = "panel-card", plotlyOutput("ranked_plot", height = "470px")),
      fluidRow(
        column(6, h3(class = "section-title", "Selected state trends"),
               div(class = "panel-card", plotlyOutput("trend_plot", height = "350px"))),
        column(6, h3(class = "section-title", "Rates and affected population"),
               div(class = "panel-card", plotlyOutput("scatter_plot", height = "350px")))
      ),
      h3(class = "section-title", "Data table"),
      div(class = "panel-card", tableOutput("data_table")),
      tags$p(class = "note", style = "margin: 16px 0;",
             "Interpretation: percentage rates and population counts answer different questions. ",
             "Cross-state comparisons are descriptive; no confidence intervals, causal ",
             "effects or statistical significance claims are provided.")
    )
  )
)

server <- function(input, output, session) {
  year_data <- reactive({
    d <- states_data[states_data$year == as.integer(input$year), , drop = FALSE]
    d[order(-d[[input$measure]]), , drop = FALSE]
  })
  national_row <- reactive({
    d <- national_data[national_data$year == as.integer(input$year), , drop = FALSE]
    validate(need(nrow(d) == 1, "No official national estimate is available for that year."))
    d
  })

  output$national_pct <- renderText(paste0(fmt(national_row()$national_deprivation_pct), "%"))
  output$national_people <- renderText(fmt(national_row()$national_people_millions))
  output$highest_state <- renderText({
    s <- year_data()
    s$state[which.max(s$healthcare_deprivation_pct)]
  })
  output$highest_rate <- renderText({
    s <- year_data()
    paste0(fmt(max(s$healthcare_deprivation_pct)), "% of state population")
  })

  output$ranked_plot <- renderPlotly({
    d <- year_data()
    metric <- input$measure
    label <- if (metric == "healthcare_deprivation_pct") "Deprivation rate (%)" else "People affected (millions)"
    p <- plot_ly(d, x = factor(d$state, levels = d$state), y = d[[metric]],
                 type = "bar", marker = list(color = "#247d9a"),
                 text = paste0(d$state, "<br>Rate: ", fmt(d$healthcare_deprivation_pct),
                               "%<br>Affected: ", fmt(d$people_millions), " million"),
                 hoverinfo = "text") %>%
      layout(xaxis = list(title = "", tickangle = -55, categoryorder = "array",
                         categoryarray = d$state),
             yaxis = list(title = label, rangemode = "tozero"),
             margin = list(b = 155, t = 15, l = 60, r = 20),
             showlegend = FALSE)
    if (isTRUE(input$compare_national)) {
      benchmark <- if (metric == "healthcare_deprivation_pct") national_row()$national_deprivation_pct else NA_real_
      if (is.finite(benchmark)) {
        p <- p %>% layout(shapes = list(list(type = "line", x0 = -0.5,
                       x1 = length(d$state) - 0.5, y0 = benchmark, y1 = benchmark,
                       line = list(color = "#ce6b43", dash = "dash", width = 2))))
      }
    }
    p
  })

  output$trend_plot <- renderPlotly({
    chosen <- input$states
    validate(need(length(chosen) > 0, "Choose at least one state."))
    d <- states_data[states_data$state %in% chosen, , drop = FALSE]
    p <- plot_ly()
    for (state_name in chosen) {
      s <- d[d$state == state_name, , drop = FALSE]
      s <- s[order(s$year), , drop = FALSE]
      p <- p %>% add_trace(x = s$year, y = s$healthcare_deprivation_pct,
                           name = state_name, type = "scatter", mode = "lines+markers",
                           hovertemplate = paste0(state_name, "<br>%{x}: %{y:.2f}%<extra></extra>"))
    }
    if (isTRUE(input$compare_national)) {
      p <- p %>% add_trace(x = national_data$year,
              y = national_data$national_deprivation_pct,
              name = "National (official)", type = "scatter", mode = "lines+markers",
              line = list(color = "#3c4355", dash = "dash"),
              hovertemplate = "National %{x}: %{y:.2f}%<extra></extra>")
    }
    p %>% layout(xaxis = list(title = "Reference year", tickmode = "array", tickvals = years),
                 yaxis = list(title = "Deprivation rate (%)", rangemode = "tozero"),
                 margin = list(t = 15, b = 50))
  })

  output$scatter_plot <- renderPlotly({
    d <- year_data()
    plot_ly(d, x = ~healthcare_deprivation_pct, y = ~people_millions,
            type = "scatter", mode = "markers",
            marker = list(size = 11, color = "#218a82", opacity = 0.8),
            text = paste0(d$state, "<br>Rate: ", fmt(d$healthcare_deprivation_pct),
                          "%<br>People: ", fmt(d$people_millions), " million"),
            hoverinfo = "text") %>%
      layout(xaxis = list(title = "Deprivation rate (%)", rangemode = "tozero"),
             yaxis = list(title = "People affected (millions)", rangemode = "tozero"),
             margin = list(t = 15, b = 50))
  })

  output$data_table <- renderTable({
    d <- year_data()
    data.frame(State = d$state,
               "Deprivation rate (%)" = round(d$healthcare_deprivation_pct, 2),
               "People affected (millions)" = round(d$people_millions, 3),
               check.names = FALSE)
  }, striped = TRUE, hover = TRUE, spacing = "xs", width = "100%")

  output$download_filtered <- downloadHandler(
    filename = function() paste0("mexico_healthcare_access_", input$year, ".csv"),
    content = function(file) write.csv(year_data(), file, row.names = FALSE,
                                      fileEncoding = "UTF-8")
  )
}

shinyApp(ui, server)
