# app.R
library(shiny)
library(igraph)

# 1) Source your existing functions
source("functions_sequence.R")        

# 2) UI
ui <- fluidPage(
  titlePanel("Diffusion ABM Simulation V1"),
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
      plotOutput("gridPlot", height = "600px"),
      tableOutput("sharesTable"),
      width = 9
    )
  )
)

# 3) Server
server <- function(input, output, session) {
  source("functions_models.R")
  source("functions_sequence.R")
  
  model <- reactive({
    list(
      world_size    = 31,
      transmit_prob = input$transmit_prob,
      I_R_prob      = input$I_R_prob,
      R_S_prob      = input$R_S_prob,
      max_t         = 200,
      seed          = 123
    )
  })
  
  rv <- reactiveValues(world = NULL, running = FALSE)
  
  # Precompute layout once
  plot_layout <- reactive({
    req(rv$world)
    layout_on_grid(rv$world$agents)
  })
  
  # Reset button
  observeEvent(input$reset, {
    rv$world   <- init_world(model())
    rv$running <- FALSE
    updateActionButton(session, "run", label = "Run")
  }, ignoreNULL = FALSE)
  
  # Single‐step button
  observeEvent(input$step, {
    req(rv$world)
    rv$world <- run_step(rv$world, model())
  })
  
  # Reactive timer that fires every 200ms
  timer <- reactiveTimer(200, session)
  
  # Use the timer to step when running
  observe({
    timer()
    if (isTRUE(rv$running) && !is.null(rv$world)) {
      rv$world <- run_step(rv$world, model())
    }
  })
  
  # Run / Pause button
  observeEvent(input$run, {
    # initialize if needed
    if (is.null(rv$world)) {
      rv$world <- init_world(model())
    }
    # toggle state
    rv$running <- !isTRUE(rv$running)
    # update button label
    updateActionButton(
      session, "run",
      label = if (rv$running) "Pause" else "Run"
    )
  })
  
  # Plot output (draw only)
  output$gridPlot <- renderPlot({
    req(rv$world)
    g    <- rv$world$agents
    cols <- c("#a5d875","#eb6a6a","#73bcde")
    plot(
      g,
      vertex.color = cols[V(g)$type],
      vertex.size  = 6,
      vertex.label = NA,
      edge.color   = "grey80",
      layout       = plot_layout()
    )
  }, res = 96)
  
  # Shares table
  output$sharesTable <- renderTable({
    req(rv$world)
    types <- V(rv$world$agents)$type
    df <- data.frame(
      State = c("S","I","R"),
      Count = as.integer(table(factor(types, levels=1:3))),
      Share = as.numeric(table(factor(types, levels=1:3))) / length(types)
    )
    df
  }, digits = c(0,0,3))
}



# 4) Run the app
shinyApp(ui, server)
