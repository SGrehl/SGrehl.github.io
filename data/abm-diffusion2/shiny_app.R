# app.R
library(shiny)
library(igraph)

# 1) Source your existing functions
source("functions_sequence.R")        

# 2) UI
ui <- fluidPage(
  titlePanel("Diffusion ABM Simulation V1.2"),
  sidebarLayout(
    sidebarPanel(
      sliderInput(
        "world_size", "World size:",
        min = 11, max = 51, value = 31, step = 2
      ),
      sliderInput(
        "transmit_prob", "Transmission probability:",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      sliderInput(
        "I_R_prob", "Getting immunity (🔴 I → R 🔵):",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      sliderInput(
        "I_S_prob", "Getting healty (🔴 I → S 🟢):",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      sliderInput(
        "R_S_prob", "Waning immunity (🔵 R → S 🟢):",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      sliderInput(
        "S_I_prob", "Spontaneous  infection (🟢 S → I 🔴):",
        min = 0, max = 0.05, value = 0, step = 0.0005
      ),
      sliderInput(
        "init_I", "Initial Infected 🔴:",
        min = 0, max = 13, value = 1, step = 1
      ),
      sliderInput(
        "init_R", "Initial share of Removed 🔵:",
        min = 0, max = 1, value = 0, step = 0.01
      ),
      actionButton("reset", "Reset"),
      actionButton("step",  "Step"),
      actionButton("run",   "Run"),
      checkboxInput("fixed_seed", "Fixed seed", value = TRUE),
      width = 3
    ),
    mainPanel(
      textOutput("status"),
      plotOutput("gridPlot", height = "800px"),
      tableOutput("sharesTable"),
      width = 9
    )
  )
)

# 3) Server
server <- function(input, output, session) {
  source("functions_sequence.R")
  source("functions_plot.R")
  
  seedVal <- reactiveVal(123)
  
  # Reactive model parameters
  model <- reactive({
    list(
      world_size    = input$world_size,
      transmit_prob = input$transmit_prob,
      I_R_prob      = input$I_R_prob,
      I_S_prob      = input$I_S_prob,
      R_S_prob      = input$R_S_prob,
      S_I_prob      = input$S_I_prob,
      init_I        = input$init_I,
      init_R        = input$init_R,
      seed          = seedVal()
    )
  })
  
  # Reactive values
  vals <- reactiveValues(
    world   = NULL,
    running = FALSE,
    step    = 1,
    run     = 0,
    label   = "Start"
  )
  
  # Helper to flip button label
  toggleLabel <- function() {
    if (vals$label %in% c("Start", "Resume")) vals$label <- "Stop"
    else vals$label <- "Resume"
    vals$label
  }
  
  # Reset button
  observeEvent(input$reset, {
    seedVal(if (input$fixed_seed) 123 else sample.int(.Machine$integer.max, 1))
    
    vals$world   <- init_world(model())
    vals$running <- FALSE
    vals$step    <- 1
    vals$label   <- "Start"
    updateActionButton(session, "run", label = "Start")
  }, ignoreNULL = FALSE)
  
  # Single‐step button
  observeEvent(input$step, {
    req(vals$world)
    vals$world <- run_step(vals$world, model())
    vals$step  <- vals$step + 1
  })
  
  # Main observer: toggles, steps and re-schedules itself
  observe({
    req(input$run)
    
    isolate({
      # 1) On each button click, detect via counter and toggle
      if (input$run != vals$run) {
        updateActionButton(session, "run", label = toggleLabel())
        vals$run <- input$run
        vals$running <- !vals$running
      }
      
      # update label and vals$running the first time around only
      if (vals$label == "Start") {
        updateActionButton(session, "run", label = toggleLabel())
        vals$running <- TRUE
      }
    })
    
    # 3) If running, do one step and schedule the next
    if (isolate(vals$running)) {
      Sys.sleep(0)                                                 
      isolate({
        vals$world <- run_step(vals$world, model())             
        vals$step  <- vals$step + 1
      })
      invalidateLater(200, session)                               
    }
  })
  
  # Plot layout computed once
  plot_layout <- reactive({
    req(vals$world)
    layout_on_grid(vals$world$agents)
  })
  
  # Render the graph at each shiny redraw
  output$gridPlot <- renderPlot({
    req(vals$world)
    plot_world_shiny(vals$world, plot_layout)
  }, res = 96)                                                  
  
  # Status text
  output$status <- renderText({
    paste("You're on iteration number:", vals$step)
  })
}


# 4) Run the app
shinyApp(ui, server)
