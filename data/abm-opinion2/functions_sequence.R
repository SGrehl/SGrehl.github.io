##################################################################
#                                                                #
# Functions for ...                                              #
# Opinion Dynamics                                               #
#                                                                # 
# Version Opinion-2                                              #
#                                                                #
##################################################################

library(tidyverse)
library(igraph)
library(Matrix)

init_world <- function(model) {
  # For reproduceability we set a seed
  set.seed(model$seed)
  
  N <- model$N
  
  # 1) generate network 
  if (model$network == "karate") { # 
    library(igraphdata)
    data(karate)
    agents <- karate
  } else if (model$network == "growing")  { # Generate random growing graph
    agents <- sample_(growing(
                        n        = N,
                        m        = model$network_m %||% 1,
                        directed = FALSE,
                        citation = TRUE
                      ),
                      simplified()
                      )
  } else if (model$network == "grg")  { # Generate random geometric graph
    agents <- sample_(grg(
                        nodes        = N,
                        radius   = model$network_r %||% 1
                      ),
                      simplified()
                      )
  } else {
    if (model$network != "pa") warning("Unknown network type ", model$network, "; defaulting to `pa`")
    agents <- sample_(pa(
                        n = N,
                        m = model$network_m %||% 1,
                        directed = FALSE
                       ),
                       simplified()
                     )
  }
  
  # 2) set individual properties
  
  if (model$opinions_type == "category") {
    # sample each of the K opinions from the discrete set `vals`
    opinions_list <- replicate(
      N,
      sample(x    = model$opinions_min:model$opinions_max,
             size = model$opinions_num,
             replace = TRUE),
      simplify = FALSE
    )
  } else if (model$opinions_type == "interval") {
    opinions_list <- replicate(
      N,
      runif(n   = model$opinions_num,
            min = model$opinions_min,
            max = model$opinions_max),
      simplify = FALSE
    )
  } else {
    stop("opinions_type must be 'category' or 'interval'")
  }
  
  # Attach as a vertex attribute
  V(agents)$opinions <- opinions_list
  
  # Override opinions for the karate network 
  if (model$network == "karate") {
    V(agents)$opinions <- rep(list(0.5), 34)
    # Mr Hi
    V(agents)[[1]]$opinions <- 0 
    # John A
    V(agents)[[34]]$opinions <- 1
  }
  
  world <- list(
    agents = agents,
    nbrs   = adjacent_vertices(agents, V(agents))
  )
  
  return(world)
}

run_step <- function(world, model) {
  agents <- world$agents
  old_opinions <- V(agents)$opinions
  new_opinions <- vector("list", length = vcount(agents))
  
  for (i in seq_along(V(agents))) {
    i_neighbors <- world$nbrs[[i]]
    i_neighbors_num <- length(i_neighbors)
    
    # select next agent if the agent has no neighbors
    if (i_neighbors_num == 0) {
      new_opinions[[i]] <- old_opinions[[i]]
      next
    }
    
    # in the karate network, Mr. Hi and John A. do not change their opinion
    if (model$network == "karate") {
      if (i ==  1) { # Mr. Hi
        new_opinions[1] <- old_opinions[1]
        next 
      }
      if (i == 34) { # John A.
        new_opinions[34] <- old_opinions[34]
        next 
      }
    }
    
    # get i opions 
    i_opinions <- matrix(rep(old_opinions[[i]], i_neighbors_num),
                         nrow = length(i_neighbors),
                         byrow = TRUE
    )
    
    
    nbrs_opinions <- do.call(rbind, old_opinions[i_neighbors])
    
    # determine the opinion difference (0 = minimal, 1 = maximal)
    if (model$influence_metric == "dimension_wise") {
      diff <- abs(i_opinions - nbrs_opinions)
      # normalize between 0 (minimal) and 1 (maximal)
      diff <- diff / abs(model$opinions_min - model$opinions_max)
    } else if (model$influence_metric == "taxicab" || model$influence_metric == "manhattan") {
      diff <- rowSums(abs(i_opinions - nbrs_opinions))
      # normalize between 0 (minimal) and 1 (maximal)
      diff <- diff / sum(abs(rep(model$opinions_min - model$opinions_max, model$opinions_num)))
    } else { # "euclidean" 
      if (model$influence_metric != "euclidean") warning("Unknown influence metric: ", model$influence_metric, ". Used `euclidean` instead.")
      diff <- sqrt(rowSums((i_opinions - nbrs_opinions)^2))
      # normalize between 0 (minimal) and 1 (maximal)
      diff <- diff / sqrt(sum(rep(model$opinions_min - model$opinions_max, model$opinions_num)^2))
    }
    
    # determine the weight
    if (model$influence == "bounded_confidence") {
      weight <-  ifelse(diff <= model$influence_epsilon, model$influence_mu, 0)
    } else {
      if (model$influence != "linear_decline") warning("Unknown influence model: ", model$influence, ". Used `linear_decline` instead.")
      weight <- model$influence_mu * (1 - 2 * diff)
    }
    
    i_new_opinion <- old_opinions[[i]] + colSums(weight * (nbrs_opinions - i_opinions)) / i_neighbors_num
    
    # make sure they are in the valid interval
    i_new_opinion[model$opinions_min > i_new_opinion] = model$opinions_min
    i_new_opinion[model$opinions_max < i_new_opinion] = model$opinions_max
    
    new_opinions[[i]] <- i_new_opinion
  }
  
  # Set updated opinions back to graph
  V(agents)$opinions <- new_opinions
  
  # Return updated world
  world$agents <- agents
  return(world)
}

get_opinion_stats_names <- function(opinions_num) {
  mean_names <- paste0("mean_", seq_len(opinions_num))
  sd_names <- paste0("sd_", seq_len(opinions_num))
  
  cor_names <- c()
  for (i in 1:opinions_num) {
    if (i+1>opinions_num) break
    for (j in (i+1):opinions_num) cor_names <- c(cor_names, paste0("cor_",i, "_",j))
  }
  
  c(mean_names, sd_names, cor_names)
}

get_opinion_stats <- function(world, opinions_num) {
  # 1) Extract the N×K opinion matrix
  opinions_list <- V(world$agents)$opinions
  mat <- matrix(
    unlist(opinions_list),
    ncol = opinions_num,
    byrow = TRUE
  )
  
  # 2) Compute averages
  avg_vec <- colMeans(mat)
  sd_vec   <- apply(mat, 2, sd)

  # 3) Compute full correlation matrix
  R <- cor(mat)
  
  # 4) Extract unique, non-trivial correlations:
  #    i < j entries of the upper triangle
  idx <- which(upper.tri(R), arr.ind = TRUE)
  cor_vals <- R[idx]
  
  # 5) Concatenate
  c(avg_vec, sd_vec, cor_vals)
}


run_sequence <- function(model,
                         world = NULL
) {
  # 1) Initialization
  if (is.null(world)) world <- init_world(model)
  
  # 2) prepare data storage
  time_series <- matrix(NA_real_,
                        nrow = model$max_t, 
                        ncol = 2 * model$opinions_num + (model$opinions_num * (model$opinions_num-1)) %/% 2,
                        dimnames = list(NULL, get_opinion_stats_names(model$opinions_num)))
  
  # 3) iterate
  for (t in seq_len(model$max_t)) {
    # Store the data from world
    time_series[t,] <- get_opinion_stats(world, model$opinions_num)
    
    # Perform one step
    world <- run_step(world, model)
  }
  
  # prepare the final world data
  df_final_world <- igraph::as_data_frame(world$agents, what = "vertices") |> 
    mutate(id = row_number(),                                                 # add id
           opinions      = V(world$agents)$opinions,                          # add agents opinions
           neighbors     = adjacent_vertices(world$agents, V(world$agents)),  # add their neighbors
           step          = t                                                  # add how long it took to terminate
    )
  
  # prepare the time series data
  df_time_series <- time_series |>
    as.tibble() |>                     # turn from matrix into data frame
    mutate(step = row_number())        # add time
  
  # 3) Return final state and summary
  list(
    df_final_world  = df_final_world,
    df_time_series  = df_time_series
  )
}
