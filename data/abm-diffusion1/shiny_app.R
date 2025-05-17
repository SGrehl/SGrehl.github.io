# app.R
library(shiny)
library(igraph)

# 1) Source your existing functions
source("functions_sequence.R")        

# 2) UI
ui <- fluidPage(
  titlePanel("Diffusion ABM Simulation V1.1"),
  sidebarLayout(
    sidebarPanel(
      sliderInput(
        "transmit_prob", "Transmission probability (S → I):",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      sliderInput(
        "I_R_prob", "Getting immunity (I → R):",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      sliderInput(
        "R_S_prob", "Waning immunity (R → S):",
        min = 0, max = 1, value = 0.5, step = 0.01
      ),
      actionButton("reset", "Reset"),
      actionButton("step",  "Step"),
      actionButton("run",   "Run"),
      width = 3
    ),
    mainPanel(
      textOutput("status"),
      plotOutput("gridPlot", height = "600px"),
      tableOutput("sharesTable"),
      width = 9
    )
  )
)

# 3) Server
server <- function(input, output, session) {
  source("functions_sequence.R")
  
  # Reactive model parameters
  model <- reactive({
    list(
      world_size    = 31,
      transmit_prob = input$transmit_prob,
      I_R_prob      = input$I_R_prob,
      R_S_prob      = input$R_S_prob,
      seed          = 123
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
      Sys.sleep(0)                                                 # yield control :contentReference[oaicite:11]{index=11}
      isolate({
        vals$world <- run_step(vals$world, model())               # step model
        vals$step  <- vals$step + 1
      })
      invalidateLater(200, session)                               # reschedule :contentReference[oaicite:12]{index=12}
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
    g    <- vals$world$agents
    cols <- c("#a5d875","#eb6a6a","#73bcde")
    plot(g,
         vertex.color = cols[V(g)$type],
         vertex.size  = 6,
         vertex.label = NA,
         edge.color   = "grey80",
         layout       = plot_layout())
  }, res = 96)                                                   # :contentReference[oaicite:8]{index=8}
  
  # Status text
  output$status <- renderText({
    paste("You're on iteration number:", vals$step)
  })
}


# 4) Run the app
shinyApp(ui, server)
