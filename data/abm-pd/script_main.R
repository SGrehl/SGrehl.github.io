rm(list = ls())

library(tidyverse)

source("functions_plot.R")
source("functions_simulation.R")
source("functions_models.R")

# ================= DEFINE SIMULATION ================= 

model <- list(
  # --- single game ---
  b = 3,                         # the benefit if the other cooperates
  c = 1,                         # the cost to cooperate
  # --- world generation ---
  n = 100,                       # number of agents 
  memory = 1,                    # how many rounds can actors remember? 
  expected_rounds = c(10, 20),   # an interval how many rounds of a games are to expect
  seed = 42,                     # our starting seed
  # --- step ---
  mu = 0.05,                     # 5 % of our agents mutate per time step (i.e. 5 agents)
  mu_rnd = 0.2,                  # 20% of the changers are purely random (i.e. 1 agent)
  w  = 5,                        # 
  max_t = 100                   # 1000
)

# ================= RUN SEQUENCE ================= 
source("functions_sequence.R")

results <- run_sequence(model)

# ================= GENERATE GRAPHS ================= 

df <- data.frame(
  t            = seq_along(results$avg_fitness_series),
  avg_fitness  = results$avg_fitness_series  
)

ggplot(df, aes(t, avg_fitness)) +
  geom_line() +
  labs(
    x = "Time step (t)",
    y = "Average fitness",
    title = "Average fitness over time"
  ) +
  theme_minimal()

summarise_strategies(results$final_world,10)

# ================= RUN SIMULATION ================= 

simulation  <- list(
  model = "baseline",
  replications = 50,
  tbl_parameter = expand.grid(
    mu = c(0.05, 0.1, 0.2)
  ),
  master_seed  = 42,
  max_cores    = 15
)

results <- run_simulation(simulation)

