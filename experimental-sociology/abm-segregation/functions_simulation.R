library(igraph)
library(tidyverse)

init_world <- function(model) {
  # For reproduceability we set a seed
  set.seed(model$seed)

  m <- model$world_size
  n <- m * m

  # 1) Generate the graph
  
  graph <- make_lattice(
    dimvector = c(m, m),
    nei        = 1
  )
  
  # Calc how many vertices will be populated by agents or stay empty
  pop_counts  <- round((1 - model$world_empty) * n * model$pop_shares)
  empty_count <- n - sum(pop_counts)
  
  # Build the vector of vertice‐types: 0 = empty, 1..k = group labels
  vertice_pool <- c(
    rep(0, empty_count),
    unlist(lapply(seq_along(pop_counts),
                  function(i) rep(i, pop_counts[i])))
  )

  # Randomly shuffle `vertice_pool` and add to graph as type
  V(graph)$type <- sample(vertice_pool, size = n)

  graph
}

get_unhappy_agents <- function(world, model) {
  # 1) Pull out the per-vertex types (0 = empty, 1..k = agent types)
  types <- V(world)$type

  # 2) Get the list of neighbors for each vertex
  nbr <- adjacent_vertices(world, V(world))

  # 3) Threshold
  h_t <- model$happiness_threshold

  # 4) For each agent, compute if unhappy
  is_unhappy <- vapply(
    seq_along(types),
    FUN = function(i) {
      t_i <- types[i]
      if (t_i == 0) return(FALSE)    # skip empty

      neigh_vs <- nbr[[i]]
      # get only occupied neighbors
      occ_neigh <- neigh_vs[types[neigh_vs] > 0]
      if (length(occ_neigh) == 0) return(FALSE)  # no neighbors → happy

      same_type <- sum(types[occ_neigh] == t_i)
      frac_same <- same_type / length(occ_neigh)
      frac_same < h_t
    },
    FALSE
  )

  # 5) return the indices of unhappy agents
  which(is_unhappy)
}

run_step <- function(world, model) {
  # pull out types & unhappy list
  types   <- V(world)$type
  unhappy <- get_unhappy_agents(world, model)
  
  # nothing to do?
  if (length(unhappy) == 0) {
    return(world)
  }
  
  # randomize move order
  unhappy <- sample(unhappy)
  
  # track current empty vertices
  empties <- which(types == 0)
  
  # choose for each agent a random location
  for (agent in unhappy) {
    # if no empties left, bail out
    if (length(empties) == 0) break
    
    # choose a random empty vertice
    target <- sample(empties, 1)
    
    # move the agent
    types[target] <- types[agent]
    types[agent]  <- 0L
    
    # update empties in‐place: replace the used slot with the old agent index
    idx <- match(target, empties)
    empties[idx] <- agent
  }
  
  # write back and return
  V(world)$type <- types
  
  world
}

get_data_segregation <- function(world) {
  types <- V(world)$type
  nbrs  <- adjacent_vertices(world, V(world))

  # for each occupied vertice, compute fraction of same‐type neighbors
  fracs <- vapply(seq_along(types), function(i) {
    t_i <- types[i]
    if (t_i == 0L) return(NA_real_)    # skip empties
    
    neigh <- nbrs[[i]]
    occ   <- neigh[types[neigh] > 0L]
    if (length(occ) == 0) return(1)    # isolated → perfect “self‐sorting”
    
    sum(types[occ] == t_i) / length(occ)
  }, numeric(1))
  
  mean(fracs, na.rm = TRUE)
}

run_sequence <- function(model,
                      verbose   = FALSE  # print progress?
                      ) {
  # 1) Initialization
  world <- init_world(model)
  unhappy_series   <- integer(0)
  segregation_series <- numeric(0)
  
  
  # 2) Iterate
  for (t in seq_len(model$max_t)) {
    unhappy <- get_unhappy_agents(world, model)
    unhappy_series[t] <- length(unhappy) / length(which(V(world)$type != 0))
    
    segregation_series[t] <- get_data_segregation(world)
    
    # print the results step by step if wanted
    if (verbose) {
      message(sprintf(
        "Step %3d: unhappiness = %3.0f, segregation = %.3f",  
        t, unhappy_series[t], segregation_series[t]
      ))
    }
    
    # stop if equilibrium reached
    if (unhappy_series[t] == 0) {
      if (verbose) message("All agents are happy. Stopping.")
      break
    }
    
    # otherwise perform one relocation step
    world <- run_step(world, model)
  }
  
  # 3) Return final state and summary
  list(
    final_world        = world,
    unhappy_series     = unhappy_series,
    segregation_series = segregation_series,
    steps_taken        = t,
    converged          = tail(unhappy_series,1) == 0
  )
}

run_replications <- function(model,
                             replications = 10,
                             master_seed  = 42,
                             verbose = FALSE) {
  
  # 1) prepare a `results` vector
  results <- vector("list", replications)
  
  # 2) run the replications
  for (r in seq_len(replications)) {
    if (verbose) cat(paste0("Replication: ", r))
    model$seed <- master_seed + r
    results[[r]] <- run_sequence(model)
  }
  
  # Extract series and align by length
  max_steps <- max(sapply(results, function(x) length(x$unhappy_series)))
  
  # Helper to fill with the last value if run ended early
  fill_with_last <- function(series, len) {
      c(series, rep(tail(series, 1), len - length(series)))
  }
  
  # Generate data matrices 
  unhappy_mat <- matrix(sapply(results, function(x) fill_with_last(x$unhappy_series, max_steps)), nrow = max_steps)
  segreg_mat <- matrix(sapply(results, function(x) fill_with_last(x$segregation_series, max_steps)), nrow = max_steps)

  # 3) calculate mean and sd at each time step
  df_sequence <- data.frame(
    step             = seq_len(max_steps),
    unhappy_mean     = apply(unhappy_mat, 1, mean, na.rm = TRUE),
    unhappy_sd       = apply(unhappy_mat, 1, sd  , na.rm = TRUE),
    segregation_mean = apply(segreg_mat , 1, mean, na.rm = TRUE),
    segregation_sd   = apply(segreg_mat , 1, sd  , na.rm = TRUE)
  )
  
  # 4) collect the final values for each replication
  converged         <- sapply(results, `[[`, "converged")
  steps_taken       <- sapply(results, `[[`, "steps_taken")
  final_segregation <- sapply(results, function(x) tail(x$segregation_series, 1))
  final_unhappy     <- sapply(results, function(x) tail(x$unhappy_series,     1))
  
  df_final <- data.frame(
    replication         = seq_len(replications),
    converged           = converged,
    steps_taken         = steps_taken,
    final_segregation   = final_segregation,
    final_unhappy       = final_unhappy
  )
  
  # 5) return results
  list(
    df_sequence = df_sequence,
    df_final    = df_final
  )
}

run_simulation <- function(simulation){
  # 1) load the baseline model
  model <- load_model(simulation$model)
  
  # 2) prepare a list to collect each model’s result
  results <- vector("list", length = nrow(simulation$tbl_parameter))
  
  # 3) run all replications for all models
  for (i in seq_len(nrow(simulation$tbl_parameter))) {
    # fetch the temporary parameters
    tmp_parameter <- simulation$tbl_parameter |> 
      slice(i) |>
      as.list()
    
    # replace the baseline model parameters with the temporary parameters
    tmp_model <- modifyList(model, tmp_parameter)
    
    # run the replications with this temorary model
    result <- run_replications(model        = tmp_model, 
                               replications = simulation$replications,
                               master_seed  = simulation$master_seed)
    
    # now we add the model name and the parameters that are changed
    # this function add it to df_process and df_final
    results[[i]] <- result %>%
      map(~ .x %>%
            mutate(
              model = tmp_model$name,
              !!!tmp_parameter
            )
      )
  }
  
  # 4) bind all df_process together, and all df_final together
  all_df_sequence <- map(results, "df_sequence") %>%
    bind_rows()
  
  all_df_final   <- map(results, "df_final") %>%
    bind_rows()
  
  # 5) return as a list of two data frames
  list(
    df_sequence = all_df_sequence,
    df_final   = all_df_final
  )
}