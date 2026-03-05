# -----------------------------------------------------------------------
# Question 3: Interactive R Shiny Dashboard
# -----------------------------------------------------------------------
# This takes the bar chart from Question 2 and wraps it in a Shiny app
# so users can interact with it — specifically, they can filter the chart
# by Treatment Arm using checkboxes on the left side.
#
# The chart updates automatically whenever the selection changes.
# If no arm is selected, a friendly warning appears instead of a
# broken/empty plot.
#
# How to run this app:
#   shiny::runApp("question_3/question_3.R")
#
# Structure of this file:
#   1. Data prep (runs once when the app starts)
#   2. A reusable plot-building function
#   3. UI (what the user sees)
#   4. Server (the logic behind the scenes)
#   5. shinyApp() call to launch everything
# -----------------------------------------------------------------------

library(pharmaverseadam)   # data
library(tidyverse)         # wrangling
library(ggplot2)           # charts
library(shiny)             # the app framework


# -----------------------------------------------------------------------
# Part 1: Data Preparation
#
# We do this OUTSIDE the server function so it only runs once when the
# app launches, not every time a user changes a filter. Much faster!
# -----------------------------------------------------------------------

adae <- pharmaverseadam::adae

# Clean and deduplicate — same logic as Question 2, just also keeping
# ACTARM so we can filter by treatment arm later
ae_clean <- adae %>%
  filter(!is.na(AESEV), !is.na(AESOC), !is.na(ACTARM)) %>%
  select(USUBJID, ACTARM, AESOC, AESEV) %>%
  distinct()

# Get the list of all unique treatment arms for the checkbox filter
all_arms <- sort(unique(ae_clean$ACTARM))

# Severity color palette — consistent with Question 2
severity_colors <- c(
  "MILD"     = "#FDDBC7",
  "MODERATE" = "#D6604D",
  "SEVERE"   = "#A50026"
)


# -----------------------------------------------------------------------
# Part 2: Plot-Building Function
#
# This is a standalone function that takes a (possibly filtered) dataset
# and returns a ggplot object. Keeping it separate makes the server code
# much cleaner and easier to read.
# -----------------------------------------------------------------------

build_ae_plot <- function(data) {

  # Count unique subjects per SOC and severity for the given data slice
  ae_counts <- data %>%
    select(USUBJID, AESOC, AESEV) %>%
    distinct() %>%
    count(AESOC, AESEV, name = "n_subjects")

  # If there's nothing to plot, return NULL early (server handles this gracefully)
  if (nrow(ae_counts) == 0) return(NULL)

  # Re-calculate SOC ordering based on the FILTERED data — this is important!
  # If a user selects only one arm, the frequencies will be different than
  # when all arms are shown, so we need to re-sort every time.
  soc_order <- ae_counts %>%
    group_by(AESOC) %>%
    summarise(total = sum(n_subjects), .groups = "drop") %>%
    arrange(total) %>%
    pull(AESOC)

  ae_counts <- ae_counts %>%
    mutate(
      AESOC = factor(AESOC, levels = soc_order),
      AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE"))
    )

  # Build and return the plot
  ggplot(ae_counts, aes(x = n_subjects, y = AESOC, fill = AESEV)) +
    geom_col(position = "stack", width = 0.7, colour = "white", linewidth = 0.2) +
    scale_fill_manual(values = severity_colors, name = "Severity") +
    scale_x_continuous(
      expand = expansion(mult = c(0, 0.04)),
      breaks = scales::pretty_breaks(n = 6)
    ) +
    labs(
      title = "Unique Subjects per SOC and Severity Level",
      x     = "Number of Unique Subjects",
      y     = "System Organ Class"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title         = element_text(face = "bold", size = 14, hjust = 0.5,
                                        margin = margin(b = 10)),
      axis.title.x       = element_text(face = "bold", size = 11, margin = margin(t = 8)),
      axis.title.y       = element_text(face = "bold", size = 11, margin = margin(r = 8)),
      axis.text.y        = element_text(size = 9),
      axis.text.x        = element_text(size = 10),
      legend.position    = "right",
      legend.title       = element_text(face = "bold", size = 10),
      legend.text        = element_text(size = 10),
      panel.grid.major.y = element_blank(),
      panel.grid.major.x = element_line(colour = "grey85", linewidth = 0.4),
      panel.grid.minor   = element_blank(),
      plot.margin        = margin(10, 15, 10, 10)
    )
}


# -----------------------------------------------------------------------
# Part 3: UI — What the User Sees
#
# Layout: a sidebar on the left for filters, the chart on the right.
# The custom CSS just makes it look a bit more polished than the default.
# -----------------------------------------------------------------------

ui <- fluidPage(

  # Some light custom styling to make the app look clean and professional
  tags$head(
    tags$style(HTML("
      body {
        font-family: 'Segoe UI', Arial, sans-serif;
        background-color: #f4f6f9;
      }
      .sidebar-box {
        background-color: #ffffff;
        border-radius: 8px;
        padding: 20px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.08);
      }
      .main-box {
        background-color: #ffffff;
        border-radius: 8px;
        padding: 16px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.08);
      }
      .app-title {
        color: #1a3a5c;
        font-weight: 700;
        margin-bottom: 2px;
      }
      .app-subtitle {
        color: #6c757d;
        font-size: 13px;
        margin-bottom: 18px;
      }
    "))
  ),

  # App title area at the top
  div(
    style = "padding: 18px 20px 10px 20px;",
    h2("AE Summary Interactive Dashboard", class = "app-title"),
    p("Adverse event distribution by System Organ Class and Severity — filter by Treatment Arm",
      class = "app-subtitle")
  ),

  # Main layout: sidebar (filters) + main panel (plot)
  sidebarLayout(

    # Left sidebar: the treatment arm filter
    sidebarPanel(
      width = 3,
      div(class = "sidebar-box",

        tags$b("Select Treatment Arm(s):"),
        tags$br(), tags$br(),

        # Convenience buttons to quickly select or clear all arms
        fluidRow(
          column(6,
            actionButton("btn_select_all", "Select All",
                         class = "btn btn-sm btn-primary",
                         style = "width:100%;")
          ),
          column(6,
            actionButton("btn_clear_all", "Clear All",
                         class = "btn btn-sm btn-outline-secondary",
                         style = "width:100%;")
          )
        ),

        tags$br(),

        # The actual checkbox filter — starts with all arms selected
        checkboxGroupInput(
          inputId  = "selected_arms",
          label    = NULL,
          choices  = all_arms,
          selected = all_arms   # all selected by default
        ),

        tags$hr(),

        # Small note about the methodology at the bottom of the sidebar
        tags$small(
          style = "color: #888; line-height: 1.5;",
          "Each subject is counted once per severity level per SOC.",
          tags$br(), tags$br(),
          "Source: pharmaverseadam::adae"
        )
      )
    ),

    # Right panel: the bar chart lives here
    mainPanel(
      width = 9,
      div(class = "main-box",
        plotOutput("ae_severity_plot", height = "600px"),
        # This UI output renders a warning if no arm is selected
        uiOutput("empty_state_message")
      )
    )
  )
)


# -----------------------------------------------------------------------
# Part 4: Server — The Logic Behind the App
# -----------------------------------------------------------------------

server <- function(input, output, session) {

  # --- Button: Select All ---
  # When clicked, set all checkboxes to checked
  observeEvent(input$btn_select_all, {
    updateCheckboxGroupInput(session, "selected_arms", selected = all_arms)
  })

  # --- Button: Clear All ---
  # When clicked, uncheck everything
  observeEvent(input$btn_clear_all, {
    updateCheckboxGroupInput(session, "selected_arms", selected = character(0))
  })

  # --- Reactive filtered dataset ---
  # This re-runs automatically whenever the checkbox selection changes.
  # req() stops execution gracefully if nothing is selected yet.
  filtered_data <- reactive({
    req(input$selected_arms)
    ae_clean %>% filter(ACTARM %in% input$selected_arms)
  })

  # --- Render the plot ---
  output$ae_severity_plot <- renderPlot({
    data <- filtered_data()
    if (nrow(data) == 0) return(NULL)   # don't try to plot empty data
    build_ae_plot(data)
  }, res = 110)   # res = 110 gives crisp rendering in the browser

  # --- Empty state message ---
  # If the user unchecks all arms, show a helpful message instead of
  # a blank/broken plot area
  output$empty_state_message <- renderUI({
    if (length(input$selected_arms) == 0) {
      div(
        style = "text-align: center; padding: 60px 20px; color: #c0392b; font-size: 15px;",
        icon("triangle-exclamation"),
        " Please select at least one Treatment Arm to display the chart."
      )
    }
  })
}


# -----------------------------------------------------------------------
# Part 5: Launch the App
# -----------------------------------------------------------------------

shinyApp(ui = ui, server = server)
