#' Statistical Display Functions
#'
#' @description Functions to render statistical data visualizations (boxplots, line plots, summaries)
#' for concept details. Used by both mod_concept_mapping and mod_dictionary_explorer.

# COLORS ====

#' Get standard colors for statistics display
#' @noRd
get_stats_colors <- function() {
  list(
    source = "#0f60af",
    target = "#fd7e14"
  )
}


# BOXPLOT RENDERING ====

#' Create a boxplot from numeric data
#'
#' @param numeric_data List with min, max, mean, median, sd, p5, p25, p75, p95
#' @param color Fill color for the boxplot (default: source blue)
#' @return ggplot object
#' @noRd
create_boxplot <- function(numeric_data, color = "#0f60af") {
  nd <- numeric_data
  if (is.null(nd$p25) || is.na(nd$p25) || is.null(nd$p75) || is.na(nd$p75)) {
    return(NULL)
  }

  min_val <- if (!is.null(nd$min) && !is.na(nd$min)) nd$min else nd$p5
  max_val <- if (!is.null(nd$max) && !is.na(nd$max)) nd$max else nd$p95
  median_val <- if (!is.null(nd$median) && !is.na(nd$median)) nd$median else (nd$p25 + nd$p75) / 2
  lower_val <- if (!is.null(nd$p5) && !is.na(nd$p5)) nd$p5 else min_val
  upper_val <- if (!is.null(nd$p95) && !is.na(nd$p95)) nd$p95 else max_val

  p <- ggplot2::ggplot() +
    ggplot2::geom_boxplot(
      ggplot2::aes(x = "", ymin = lower_val, lower = nd$p25, middle = median_val,
                   upper = nd$p75, ymax = upper_val),
      stat = "identity",
      fill = color,
      color = "#333",
      width = 0.5,
      fatten = 0
    ) +
    ggplot2::geom_segment(
      ggplot2::aes(x = 0.75, xend = 1.25, y = median_val, yend = median_val),
      color = "white",
      linewidth = 1
    ) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(size = 9),
      plot.margin = ggplot2::margin(5, 10, 5, 10)
    )

  p
}


#' Create a dual boxplot comparing source and target distributions
#'
#' @param source_data List with numeric_data for source
#' @param target_data List with numeric_data for target
#' @return ggplot object
#' @noRd
create_dual_boxplot <- function(source_data, target_data) {
  colors <- get_stats_colors()
  snd <- source_data
  tnd <- target_data

  # Validate data
  if (is.null(snd$p25) || is.na(snd$p25) || is.null(snd$p75) || is.na(snd$p75)) return(NULL)
  if (is.null(tnd$p25) || is.na(tnd$p25) || is.null(tnd$p75) || is.na(tnd$p75)) return(NULL)

  # Source values
  s_min_val <- if (!is.null(snd$min) && !is.na(snd$min)) snd$min else if (!is.null(snd$p5) && !is.na(snd$p5)) snd$p5 else snd$p25
  s_max_val <- if (!is.null(snd$max) && !is.na(snd$max)) snd$max else if (!is.null(snd$p95) && !is.na(snd$p95)) snd$p95 else snd$p75
  s_median_val <- if (!is.null(snd$median) && !is.na(snd$median)) snd$median else (snd$p25 + snd$p75) / 2
  s_lower_val <- if (!is.null(snd$p5) && !is.na(snd$p5)) snd$p5 else s_min_val
  s_upper_val <- if (!is.null(snd$p95) && !is.na(snd$p95)) snd$p95 else s_max_val

  # Target values
  t_min_val <- if (!is.null(tnd$min) && !is.na(tnd$min)) tnd$min else tnd$p5
  t_max_val <- if (!is.null(tnd$max) && !is.na(tnd$max)) tnd$max else tnd$p95
  t_median_val <- if (!is.null(tnd$median) && !is.na(tnd$median)) tnd$median else (tnd$p25 + tnd$p75) / 2
  t_lower_val <- if (!is.null(tnd$p5) && !is.na(tnd$p5)) tnd$p5 else t_min_val
  t_upper_val <- if (!is.null(tnd$p95) && !is.na(tnd$p95)) tnd$p95 else t_max_val

  box_data <- data.frame(
    group = factor(c("Source", "Target"), levels = c("Source", "Target")),
    ymin = c(s_lower_val, t_lower_val),
    lower = c(snd$p25, tnd$p25),
    middle = c(s_median_val, t_median_val),
    upper = c(snd$p75, tnd$p75),
    ymax = c(s_upper_val, t_upper_val)
  )

  p <- ggplot2::ggplot(box_data, ggplot2::aes(x = group, ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax, fill = group)) +
    ggplot2::geom_boxplot(stat = "identity", color = "#333", width = 0.6, fatten = 0) +
    ggplot2::geom_segment(ggplot2::aes(x = as.numeric(group) - 0.3, xend = as.numeric(group) + 0.3, y = middle, yend = middle), color = "white", linewidth = 1) +
    ggplot2::scale_fill_manual(values = c("Source" = colors$source, "Target" = colors$target)) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 9),
      axis.text.x = ggplot2::element_text(size = 9),
      plot.margin = ggplot2::margin(5, 10, 5, 10),
      legend.position = "none"
    )

  p
}


# LINE PLOT / HISTOGRAM RENDERING ====

#' Create a line plot from histogram data
#'
#' @param histogram_data Data frame or list with bin_start, bin_end, count
#' @param color Line/fill color (default: source blue)
#' @return ggplot object
#' @noRd
create_line_plot <- function(histogram_data, color = "#0f60af") {
  if (is.null(histogram_data) || length(histogram_data) == 0) return(NULL)

  hist_df <- as.data.frame(histogram_data)
  if (nrow(hist_df) == 0 || !"bin_start" %in% colnames(hist_df) || !"count" %in% colnames(hist_df)) {
    return(NULL)
  }

  hist_df$bin_mid <- (hist_df$bin_start + hist_df$bin_end) / 2
  total_count <- sum(hist_df$count, na.rm = TRUE)
  hist_df$percentage <- if (total_count > 0) hist_df$count / total_count * 100 else 0

  p <- ggplot2::ggplot(hist_df, ggplot2::aes(x = bin_mid, y = percentage)) +
    ggplot2::geom_area(fill = color, alpha = 0.3) +
    ggplot2::geom_line(color = color, linewidth = 1.2) +
    ggplot2::geom_point(color = color, size = 2) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.05)), labels = function(x) paste0(x, "%")) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(5, 10, 5, 10)
    )

  p
}


#' Create a dual line plot comparing source and target distributions
#'
#' @param source_histogram Source histogram data
#' @param target_histogram Target histogram data
#' @return ggplot object
#' @noRd
create_dual_line_plot <- function(source_histogram, target_histogram) {
  colors <- get_stats_colors()

  # Process target histogram
  if (is.null(target_histogram) || length(target_histogram) == 0) return(NULL)
  target_df <- as.data.frame(target_histogram)
  if (nrow(target_df) == 0 || !"bin_start" %in% colnames(target_df)) return(NULL)

  target_df$bin_mid <- (target_df$bin_start + target_df$bin_end) / 2
  target_total <- sum(target_df$count, na.rm = TRUE)
  target_df$percentage <- if (target_total > 0) target_df$count / target_total * 100 else 0
  target_df$source <- "Target"

  # Process source histogram
  if (is.null(source_histogram) || length(source_histogram) == 0) {
    return(create_line_plot(target_histogram, colors$target))
  }
  source_df <- as.data.frame(source_histogram)
  if (nrow(source_df) == 0 || !"bin_start" %in% colnames(source_df)) {
    return(create_line_plot(target_histogram, colors$target))
  }

  source_df$bin_mid <- (source_df$bin_start + source_df$bin_end) / 2
  source_total <- sum(source_df$count, na.rm = TRUE)
  source_df$percentage <- if (source_total > 0) source_df$count / source_total * 100 else 0
  source_df$source <- "Source"

  # Combine both
  combined_df <- rbind(target_df, source_df)

  p <- ggplot2::ggplot(combined_df, ggplot2::aes(x = bin_mid, y = percentage, color = source, fill = source)) +
    ggplot2::geom_area(alpha = 0.25, position = "identity") +
    ggplot2::geom_line(linewidth = 1.2) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(values = c("Source" = colors$source, "Target" = colors$target)) +
    ggplot2::scale_fill_manual(values = c("Source" = colors$source, "Target" = colors$target)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.02))) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.05)), labels = function(x) paste0(x, "%")) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(5, 10, 5, 10),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank()
    )

  p
}


# CATEGORICAL DISTRIBUTION RENDERING ====

#' Create categorical bar chart
#'
#' @param categorical_data List or data frame with value, percentage columns
#' @param color Bar color (default: source blue)
#' @return ggplot object
#' @noRd
create_categorical_chart <- function(categorical_data, color = "#0f60af") {
  if (is.null(categorical_data) || length(categorical_data) == 0) return(NULL)

  cat_df <- as.data.frame(categorical_data)
  if (nrow(cat_df) == 0 || !"value" %in% colnames(cat_df) || !"percentage" %in% colnames(cat_df)) {
    return(NULL)
  }

  cat_df <- cat_df[order(-cat_df$percentage), ]
  cat_df$value_label <- ifelse(nchar(as.character(cat_df$value)) > 20,
                                paste0(substr(as.character(cat_df$value), 1, 18), "..."),
                                as.character(cat_df$value))
  cat_df$value_label <- factor(cat_df$value_label, levels = rev(cat_df$value_label))

  plot_height <- max(100, min(250, nrow(cat_df) * 25))

  p <- ggplot2::ggplot(cat_df, ggplot2::aes(x = value_label, y = percentage)) +
    ggplot2::geom_col(fill = color, width = 0.7) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "%") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(size = 9),
      axis.text.y = ggplot2::element_text(size = 9),
      axis.title.x = ggplot2::element_text(size = 10),
      plot.margin = ggplot2::margin(5, 10, 5, 5)
    )

  p
}


# TEMPORAL DISTRIBUTION RENDERING ====

#' Create temporal distribution chart (by year)
#'
#' @param year_data Data frame or list with year, percentage columns
#' @param color Bar color (default: source blue)
#' @return ggplot object
#' @noRd
create_temporal_chart <- function(year_data, color = "#0f60af") {
  if (is.null(year_data) || length(year_data) == 0) return(NULL)

  year_df <- as.data.frame(year_data)
  if (nrow(year_df) == 0 || !"year" %in% colnames(year_df) || !"percentage" %in% colnames(year_df)) {
    return(NULL)
  }

  year_df$year <- as.factor(year_df$year)

  p <- ggplot2::ggplot(year_df, ggplot2::aes(x = year, y = percentage)) +
    ggplot2::geom_col(fill = color, width = 0.6) +
    ggplot2::labs(x = NULL, y = "%") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 10),
      axis.title.y = ggplot2::element_text(size = 10),
      plot.margin = ggplot2::margin(5, 10, 5, 10)
    )

  p
}


# UNIT DISTRIBUTION RENDERING ====

#' Create unit distribution chart
#'
#' @param unit_data Data frame or list with unit_name, percentage columns
#' @param color Bar color (default: source blue)
#' @return ggplot object
#' @noRd
create_unit_chart <- function(unit_data, color = "#0f60af") {
  if (is.null(unit_data) || length(unit_data) == 0) return(NULL)

  unit_df <- as.data.frame(unit_data)
  if (nrow(unit_df) == 0 || !"unit_name" %in% colnames(unit_df) || !"percentage" %in% colnames(unit_df)) {
    return(NULL)
  }

  unit_df <- unit_df[order(-unit_df$percentage), ]
  unit_df$unit_label <- ifelse(nchar(unit_df$unit_name) > 20,
                                paste0(substr(unit_df$unit_name, 1, 18), "..."),
                                unit_df$unit_name)
  unit_df$unit_label <- factor(unit_df$unit_label, levels = rev(unit_df$unit_label))

  p <- ggplot2::ggplot(unit_df, ggplot2::aes(x = unit_label, y = percentage)) +
    ggplot2::geom_col(fill = color, width = 0.7) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "%") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(size = 9),
      axis.text.y = ggplot2::element_text(size = 9),
      axis.title.x = ggplot2::element_text(size = 10),
      plot.margin = ggplot2::margin(5, 10, 5, 5)
    )

  p
}


# UI HELPER FUNCTIONS ====

#' Format a numeric value with optional comparison value
#'
#' @param target_val Target value (displayed in orange if comparison mode)
#' @param source_val Source value for comparison (optional, displayed in blue in parentheses)
#' @param color_target Color for target value (default: orange)
#' @param color_source Color for source value (default: blue)
#' @param digits Number of decimal places (default: 2)
#' @return shiny tagList
#' @noRd
format_stat_value <- function(target_val, source_val = NULL, color_target = "#fd7e14", color_source = "#0f60af", digits = 2) {
  if (is.null(target_val) || (is.logical(target_val) && !target_val) || is.na(target_val)) {
    return(shiny::tags$span("-"))
  }

  target_text <- shiny::tags$span(style = paste0("color: ", color_target, "; font-weight: 600;"), round(target_val, digits))

  if (!is.null(source_val) && !is.na(source_val)) {
    shiny::tags$span(
      target_text,
      shiny::tags$span(style = paste0("color: ", color_source, "; margin-left: 5px;"), paste0("(", round(source_val, digits), ")"))
    )
  } else {
    target_text
  }
}


#' Create a stat row with label and formatted value(s)
#'
#' @param label Label text
#' @param target_val Target value
#' @param source_val Source value for comparison (optional)
#' @param color_target Color for target value
#' @param color_source Color for source value
#' @return shiny tags$div
#' @noRd
create_stat_row <- function(label, target_val, source_val = NULL, color_target = "#fd7e14", color_source = "#0f60af") {
  val_content <- format_stat_value(target_val, source_val, color_target, color_source)

  shiny::tags$div(
    style = "display: flex; gap: 5px; margin-bottom: 2px;",
    shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", paste0(label, ":")),
    val_content
  )
}
