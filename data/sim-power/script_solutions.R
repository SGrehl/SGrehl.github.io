model <- list(
  # design
  schools = 1,
  classes = 1,
  n_per_class = 129,
  prob = 0.35,
  randomization = "complete",
  # Y 
  mean = 50,
  sd = 10,
  effect_treatment = 5.5
) 

model$n_per_class * 10 + model$n_per_class * 60 * model$prob

get_power(model, test = 1, replications = 1000)


model <- list(
  # design
  schools = 1,
  classes = 1,
  n_per_class = 6,
  prob = 0.5,
  randomization = "complete",
  # Y 
  mean = 50,
  sd = 10,
  effect_treatment = 5.5
) 

model$n_per_class * 10 + model$n_per_class * 60 * model$prob

get_power(model, test = 2, replications = 1000)

model <- list(
  # design
  schools = 4,
  classes = 4,
  n_per_class = 4,
  prob = 0.5,
  randomization = "complete",
  # Y 
  mean = 50,
  sd = 10,
  effect_treatment = 5.5
) 
