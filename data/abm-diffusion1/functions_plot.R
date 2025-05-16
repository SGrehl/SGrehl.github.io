##################################################################
#                                                                #
# Functions for ...                                              #
# Diffusion                                                      #
#                                                                # 
# Version Diffusion-2                                            #
#                                                                #
##################################################################

plot_avg_type <- function(df,
                         show       = "all",    # "all" or a character vector of series, e.g. c("S","I")
                         group_var  = NULL,     # unquoted name to facet by
                         replications = NULL    # if NULL, tries to read df$replications
) {
  # capture the grouping variable
  group_q <- enquo(group_var)
  
  # find or check replications
  if (is.null(replications) && "replications" %in% names(df)) {
    replications <- max(df$replications, na.rm = TRUE)
  }
  if (is.null(replications) || replications <= 0) {
    stop("Please supply a positive `replications` or have a column `replications` in df.")
  }
  
  # 1) gather all cols ending in _mean/_sd
  series_cols <- grep("_(mean|sd)$", names(df), value = TRUE)
  df_long <- df %>%
    pivot_longer(
      cols = all_of(series_cols),
      names_to   = c("series", "stat"),
      names_pattern = "(.+)_([^_]+)$",
      values_to  = "value"
    ) %>%
    pivot_wider(names_from = stat, values_from = value) %>%
    # extract the short series name (prefix up to first underscore)
    mutate(
      series_short = sub("_.*", "", series),
      ci_lower = mean - 1.96 * (sd / sqrt(replications)),
      ci_upper = mean + 1.96 * (sd / sqrt(replications))
    )
  
  # 2) filter which series to show
  if (!identical(show, "all")) {
    df_long <- df_long %>%
      filter(series_short %in% show)
  }
  
  # 3) build the ggplot
  p <- ggplot(df_long, aes(
    x = step,
    y = mean,
    color = series_short,
    fill  = series_short,
    group = series_short
  )) +
    geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper),
                alpha = 0.2, color = NA) +
    geom_line()
  
  # 4) facet if requested
  if (!quo_is_null(group_q)) {
    p <- p + facet_wrap(vars(!!group_q))
  }
  
  # 5) labels
  p + labs(
    x     = "Step",
    y     = "Proportion",
    color = NULL,
    fill  = NULL
  ) +
    theme_minimal()
}