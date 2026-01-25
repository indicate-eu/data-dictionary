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

  # Debug: print raw data structure
  cat("\n=== DEBUG create_line_plot ===\n")
  cat("Class of histogram_data:", class(histogram_data), "\n")
  cat("Length:", length(histogram_data), "\n")
  if (is.list(histogram_data) && length(histogram_data) > 0) {
    cat("First element structure:\n")
    print(str(histogram_data[[1]]))
  }

  hist_df <- as.data.frame(histogram_data)
  cat("Converted to data.frame:\n")
  print(head(hist_df))
  cat("Columns:", paste(colnames(hist_df), collapse = ", "), "\n")

  if (nrow(hist_df) == 0 || !"count" %in% colnames(hist_df)) {
    cat("ERROR: No data or no count column\n")
    return(NULL)
  }

  # Support new format with x coordinate
  if ("x" %in% colnames(hist_df)) {
    hist_df$bin_mid <- hist_df$x
    cat("Using 'x' column for bin_mid\n")
  } else if ("bin_start" %in% colnames(hist_df) && "bin_end" %in% colnames(hist_df)) {
    # Support legacy format with bin_start/bin_end
    hist_df$bin_mid <- (hist_df$bin_start + hist_df$bin_end) / 2
    cat("Using bin_start/bin_end for bin_mid\n")
  } else {
    cat("ERROR: No x or bin_start/bin_end columns\n")
    return(NULL)
  }

  total_count <- sum(hist_df$count, na.rm = TRUE)
  hist_df$percentage <- if (total_count > 0) hist_df$count / total_count * 100 else 0

  cat("Final data for plotting:\n")
  print(hist_df[, c("bin_mid", "count", "percentage")])
  cat("=== END DEBUG ===\n\n")

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
#' @param categorical_data List or data frame with value/category, percentage columns
#' @param color Bar color (default: source blue)
#' @return ggplot object
#' @noRd
create_categorical_chart <- function(categorical_data, color = "#0f60af") {
  if (is.null(categorical_data) || length(categorical_data) == 0) return(NULL)

  cat_df <- as.data.frame(categorical_data)

  # Support both "value" and "category" column names
  value_col <- if ("value" %in% colnames(cat_df)) "value" else if ("category" %in% colnames(cat_df)) "category" else NULL

  if (nrow(cat_df) == 0 || is.null(value_col) || !"percentage" %in% colnames(cat_df)) {
    return(NULL)
  }

  cat_df <- cat_df[order(-cat_df$percentage), ]
  # Clean up carriage returns and newlines, then truncate
  cat_df$value_label <- sapply(cat_df[[value_col]], function(v) {
    v <- gsub("\r\n|\r|\n", " ", as.character(v))
    if (nchar(v) > 20) paste0(substr(v, 1, 18), "...") else v
  })
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


# HISTOGRAM DATA PARSING ====

#' Parse histogram data supporting both x and bin_start/bin_end formats
#'
#' @param histogram_list List or data.frame with histogram data
#' @return Data frame with x, count columns or NULL
#' @noRd
parse_histogram_data <- function(histogram_list) {
  if (is.null(histogram_list) || length(histogram_list) == 0) return(NULL)

  # If it's a list of lists, convert properly using do.call(rbind, ...)
  if (is.list(histogram_list) && !is.data.frame(histogram_list)) {
    # Check if first element is a list with x/count or bin_start/bin_end
    first_elem <- histogram_list[[1]]
    if (is.list(first_elem)) {
      # Convert list of lists to data frame properly (each list element becomes a row)
      hist_df <- do.call(rbind.data.frame, histogram_list)
    } else {
      hist_df <- as.data.frame(histogram_list)
    }
  } else {
    hist_df <- as.data.frame(histogram_list)
  }

  if (nrow(hist_df) == 0) return(NULL)

  # Support new format with x coordinate
  if ("x" %in% colnames(hist_df) && "count" %in% colnames(hist_df)) {
    return(hist_df[, c("x", "count")])
  }

  # Support legacy format with bin_start/bin_end
  if ("bin_start" %in% colnames(hist_df) && "bin_end" %in% colnames(hist_df) && "count" %in% colnames(hist_df)) {
    hist_df$x <- (hist_df$bin_start + hist_df$bin_end) / 2
    return(hist_df[, c("x", "count")])
  }

  NULL
}


# SHARED PANEL RENDERERS ====

#' Check if numeric_data has actual values
#' @noRd
has_numeric_values <- function(nd) {
  if (is.null(nd)) return(FALSE)
  (!is.null(nd$min) && !is.na(nd$min)) ||
  (!is.null(nd$max) && !is.na(nd$max)) ||
  (!is.null(nd$mean) && !is.na(nd$mean)) ||
  (!is.null(nd$median) && !is.na(nd$median)) ||
  (!is.null(nd$p25) && !is.na(nd$p25)) ||
  (!is.null(nd$p75) && !is.na(nd$p75))
}


#' Render Summary Panel
#'
#' @description Renders a summary panel with statistics. Can show target data alone
#' (orange) or with source data for comparison (blue in parentheses).
#'
#' @param profile_data Profile data containing numeric_data, missing_rate, measurement_frequency
#' @param source_data Optional source data for comparison (from source concept JSON)
#' @param row_data Optional row data containing rows_count, patients_count
#' @param target_unit_name Optional unit name for the target concept
#' @param source_unit_name Optional source unit name for comparison
#' @param show_source_specific_stats Logical: show missing_rate and measurement_frequency
#'   (these are source-specific and should not be shown for Target Concept Details)
#' @return shiny tagList
#' @noRd
render_stats_summary_panel <- function(profile_data, source_data = NULL, row_data = NULL, target_unit_name = NULL, source_unit_name = NULL, show_source_specific_stats = TRUE) {
  items <- list()

  colors <- get_stats_colors()
  has_source <- !is.null(source_data)

  # Summary shows metadata only (numeric stats are in Distribution tab)

  # Rows count
  if (!is.null(row_data) && !is.null(row_data$rows_count) && !is.na(row_data$rows_count)) {
    items <- c(items, list(
      shiny::tags$div(
        class = "detail-item", style = "margin-bottom: 6px;",
        shiny::tags$span(style = "font-weight: 600; color: #666;", "Rows:"),
        shiny::tags$span(class = "detail-value", format(row_data$rows_count, big.mark = ","))
      )
    ))
  }

  # Patients count
  if (!is.null(row_data) && !is.null(row_data$patients_count) && !is.na(row_data$patients_count)) {
    items <- c(items, list(
      shiny::tags$div(
        class = "detail-item", style = "margin-bottom: 6px;",
        shiny::tags$span(style = "font-weight: 600; color: #666;", "Patients:"),
        shiny::tags$span(class = "detail-value", format(row_data$patients_count, big.mark = ","))
      )
    ))
  }

  # Unit (with optional source comparison)
  if (!is.null(target_unit_name) && nchar(target_unit_name) > 0) {
    items <- c(items, list(
      shiny::tags$div(
        class = "detail-item", style = "margin-bottom: 6px;",
        shiny::tags$span(style = "font-weight: 600; color: #666;", "Unit:"),
        if (!is.null(source_unit_name) && nchar(source_unit_name) > 0) {
          shiny::tags$span(
            shiny::tags$span(style = paste0("color: ", colors$target, "; font-weight: 600;"), target_unit_name),
            shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_unit_name, ")"))
          )
        } else {
          shiny::tags$span(class = "detail-value", target_unit_name)
        }
      )
    ))
  }

  # Missing rate (source-specific, only show when show_source_specific_stats is TRUE)
  if (show_source_specific_stats && !is.null(profile_data$missing_rate) && !is.na(profile_data$missing_rate)) {
    source_missing <- if (has_source && !is.null(source_data$missing_rate)) source_data$missing_rate else NULL
    items <- c(items, list(
      shiny::tags$div(
        class = "detail-item", style = "margin-bottom: 6px;",
        shiny::tags$span(style = "font-weight: 600; color: #666;", "Missing:"),
        if (has_source && !is.null(source_missing)) {
          shiny::tags$span(
            shiny::tags$span(style = paste0("color: ", colors$target, "; font-weight: 600;"), paste0(profile_data$missing_rate, "%")),
            shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_missing, "%)"))
          )
        } else {
          shiny::tags$span(class = "detail-value", paste0(profile_data$missing_rate, "%"))
        }
      )
    ))
  }

  # Measurement frequency (source-specific, only show when show_source_specific_stats is TRUE)
  if (show_source_specific_stats && !is.null(profile_data$measurement_frequency) && !is.null(profile_data$measurement_frequency$typical_interval)) {
    items <- c(items, list(
      shiny::tags$div(
        class = "detail-item", style = "margin-bottom: 6px;",
        shiny::tags$span(style = "font-weight: 600; color: #666;", "Interval:"),
        shiny::tags$span(class = "detail-value", gsub("_", " ", profile_data$measurement_frequency$typical_interval))
      )
    ))
  }

  if (length(items) == 0) {
    return(shiny::tags$div(style = "color: #999; font-style: italic;", "No summary data available."))
  }

  # Single column layout (all items on left)
  shiny::tags$div(
    style = "padding: 15px;",
    items
  )
}


#' Render Distribution Panel
#'
#' @description Renders a distribution panel with boxplot and/or histogram.
#' Shows target data with optional source comparison.
#'
#' @param profile_data Profile data containing numeric_data, histogram, categorical_data
#' @param source_data Optional source data for comparison overlay
#' @param primary_color Color for primary data (default: blue for standalone, orange for comparison mode)
#' @return shiny tagList
#' @noRd
render_stats_distribution_panel <- function(profile_data, source_data = NULL, primary_color = NULL) {
  colors <- get_stats_colors()
  has_source <- !is.null(source_data) &&
                !is.null(source_data$numeric_data) &&
                !is.null(source_data$numeric_data$p25) &&
                !is.na(source_data$numeric_data$p25)

  # Use blue for standalone mode, orange for comparison mode
  main_color <- if (!is.null(primary_color)) primary_color else if (has_source) colors$target else colors$source

  nd <- profile_data$numeric_data
  snd <- if (has_source) source_data$numeric_data else NULL

  # Numeric distribution (boxplot + histogram)
  if (!is.null(nd) && has_numeric_values(nd) && !is.null(nd$p25) && !is.na(nd$p25) && !is.null(nd$p75) && !is.na(nd$p75)) {

    # Create stats display next to boxplot
    stats_items <- list()

    # Mean
    if (!is.null(nd$mean) && !is.na(nd$mean)) {
      source_mean <- if (!is.null(snd) && !is.null(snd$mean)) snd$mean else NULL
      stats_items <- c(stats_items, list(create_stat_row("Mean", nd$mean, source_mean, main_color, colors$source)))
    }

    # Median
    if (!is.null(nd$median) && !is.na(nd$median)) {
      source_median <- if (!is.null(snd) && !is.null(snd$median)) snd$median else NULL
      stats_items <- c(stats_items, list(create_stat_row("Median", nd$median, source_median, main_color, colors$source)))
    }

    # SD
    if (!is.null(nd$sd) && !is.na(nd$sd)) {
      source_sd <- if (!is.null(snd) && !is.null(snd$sd)) snd$sd else NULL
      stats_items <- c(stats_items, list(create_stat_row("SD", nd$sd, source_sd, main_color, colors$source)))
    }

    # Range (min - max)
    if (!is.null(nd$min) && !is.na(nd$min) && !is.null(nd$max) && !is.na(nd$max)) {
      range_text <- paste(round(nd$min, 2), "-", round(nd$max, 2))
      source_range <- NULL
      if (!is.null(snd) && !is.null(snd$min) && !is.null(snd$max)) {
        source_range <- paste(round(snd$min, 2), "-", round(snd$max, 2))
      }
      stats_items <- c(stats_items, list(
        shiny::tags$div(
          style = "display: flex; gap: 5px; margin-bottom: 2px;",
          shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", "Range:"),
          if (!is.null(source_range)) {
            shiny::tags$span(
              shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), range_text),
              shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_range, ")"))
            )
          } else {
            shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), range_text)
          }
        )
      ))
    }

    # IQR (p25 - p75)
    if (!is.null(nd$p25) && !is.na(nd$p25) && !is.null(nd$p75) && !is.na(nd$p75)) {
      iqr_text <- paste(round(nd$p25, 2), "-", round(nd$p75, 2))
      source_iqr <- NULL
      if (!is.null(snd) && !is.null(snd$p25) && !is.na(snd$p25) && !is.null(snd$p75) && !is.na(snd$p75)) {
        source_iqr <- paste(round(snd$p25, 2), "-", round(snd$p75, 2))
      }
      stats_items <- c(stats_items, list(
        shiny::tags$div(
          style = "display: flex; gap: 5px; margin-bottom: 2px;",
          shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", "IQR:"),
          if (!is.null(source_iqr)) {
            shiny::tags$span(
              shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), iqr_text),
              shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_iqr, ")"))
            )
          } else {
            shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), iqr_text)
          }
        )
      ))
    }

    # P5 - P95 range
    if (!is.null(nd$p5) && !is.na(nd$p5) && !is.null(nd$p95) && !is.na(nd$p95)) {
      p5_p95_text <- paste(round(nd$p5, 2), "-", round(nd$p95, 2))
      source_p5_p95 <- NULL
      if (!is.null(snd) && !is.null(snd$p5) && !is.na(snd$p5) && !is.null(snd$p95) && !is.na(snd$p95)) {
        source_p5_p95 <- paste(round(snd$p5, 2), "-", round(snd$p95, 2))
      }
      stats_items <- c(stats_items, list(
        shiny::tags$div(
          style = "display: flex; gap: 5px; margin-bottom: 2px;",
          shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", "P5-P95:"),
          if (!is.null(source_p5_p95)) {
            shiny::tags$span(
              shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), p5_p95_text),
              shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_p5_p95, ")"))
            )
          } else {
            shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), p5_p95_text)
          }
        )
      ))
    }

    # Create boxplot
    if (has_source) {
      boxplot <- create_dual_boxplot(snd, nd)
    } else {
      boxplot <- create_boxplot(nd, main_color)
    }

    # Parse histogram data
    target_hist <- parse_histogram_data(profile_data$histogram)
    source_hist <- if (has_source) parse_histogram_data(source_data$histogram) else NULL

    # Create histogram plot
    hist_plot <- NULL
    if (!is.null(target_hist)) {
      # Calculate percentages
      target_hist$percentage <- target_hist$count / sum(target_hist$count, na.rm = TRUE) * 100

      if (!is.null(source_hist)) {
        source_hist$percentage <- source_hist$count / sum(source_hist$count, na.rm = TRUE) * 100

        # Combine for dual plot
        target_hist$source <- "Target"
        source_hist$source <- "Source"
        combined_df <- rbind(target_hist, source_hist)

        hist_plot <- ggplot2::ggplot(combined_df, ggplot2::aes(x = x, y = percentage, color = source, fill = source)) +
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
      } else {
        hist_plot <- ggplot2::ggplot(target_hist, ggplot2::aes(x = x, y = percentage)) +
          ggplot2::geom_area(fill = main_color, alpha = 0.3) +
          ggplot2::geom_line(color = main_color, linewidth = 1.2) +
          ggplot2::geom_point(color = main_color, size = 2) +
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
      }
    }

    return(shiny::tags$div(
      style = "display: flex; flex-direction: column; gap: 10px; height: 100%;",

      # Top: Boxplot section with stats
      shiny::tags$div(
        style = "flex: 0 0 auto; padding: 15px; background: #f8f9fa; border-radius: 6px;",
        shiny::tags$div(
          style = "display: flex; align-items: center; gap: 15px;",
          # Stats column
          shiny::tags$div(
            style = "min-width: 150px; font-size: 12px;",
            stats_items
          ),
          # Boxplot column
          shiny::tags$div(
            style = "flex: 1;",
            if (!is.null(boxplot)) {
              shiny::renderPlot({ boxplot }, height = if (has_source) 80 else 50, width = "auto")
            }
          )
        )
      ),

      # Bottom: Histogram section
      if (!is.null(hist_plot)) {
        shiny::tags$div(
          style = "flex: 1; min-height: 0; padding: 15px; background: #f8f9fa; border-radius: 6px;",
          shiny::tags$div(
            style = "height: 100%;",
            shiny::renderPlot({ hist_plot }, height = "100%", width = "auto")
          )
        )
      }
    ))
  }

  # Categorical distribution (bar chart)
  if (!is.null(profile_data$categorical_data) && length(profile_data$categorical_data) > 0) {
    cat_df <- as.data.frame(profile_data$categorical_data)

    # Support both "value" and "category" column names
    value_col <- if ("value" %in% colnames(cat_df)) "value" else if ("category" %in% colnames(cat_df)) "category" else NULL

    if (nrow(cat_df) > 0 && !is.null(value_col) && "percentage" %in% colnames(cat_df)) {
      # Truncate long category names for display
      cat_df$display_value <- sapply(cat_df[[value_col]], function(v) {
        v <- gsub("\r\n|\r|\n", " ", as.character(v))
        if (nchar(v) > 50) paste0(substr(v, 1, 47), "...") else v
      })

      rows <- lapply(seq_len(nrow(cat_df)), function(i) {
        shiny::tags$div(
          style = "display: flex; align-items: center; margin-bottom: 5px;",
          shiny::tags$span(
            style = "width: 200px; font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;",
            title = gsub("\r\n|\r|\n", " ", as.character(cat_df[[value_col]][i])),
            cat_df$display_value[i]
          ),
          shiny::tags$div(
            style = "flex: 1; margin: 0 8px;",
            shiny::tags$div(style = sprintf("width: %s%%; background: %s; height: 18px; border-radius: 3px;", cat_df$percentage[i], main_color))
          ),
          shiny::tags$span(style = "font-size: 12px; color: #666; min-width: 45px; text-align: right;", paste0(cat_df$percentage[i], "%"))
        )
      })
      return(do.call(shiny::tagList, rows))
    }
  }

  shiny::tags$div(style = "color: #999; font-style: italic;", "No distribution data available.")
}


#' Render Comments Panel
#'
#' @description Renders the comments panel with markdown content
#'
#' @param comments_text Comments text (markdown format)
#' @return shiny tagList
#' @noRd
render_stats_comments_panel <- function(comments_text) {
  if (is.null(comments_text) || is.na(comments_text) || nchar(trimws(comments_text)) == 0) {
    return(shiny::tags$div(
      style = "color: #999; font-style: italic;",
      "No comments available for this concept."
    ))
  }

  shiny::tags$div(
    class = "comments-section",
    style = "background: #ffffff; padding: 10px; border-radius: 6px; height: 100%; overflow-y: auto;",
    shiny::tags$div(
      class = "markdown-content",
      shiny::HTML(markdown::markdownToHTML(
        text = comments_text,
        fragment.only = TRUE,
        options = c("fragment_only", "base64_images", "smartypants")
      ))
    )
  )
}


#' Render Boxplot Section Only
#'
#' @description Renders only the boxplot with statistics (no histogram)
#'
#' @param profile_data Profile data containing numeric_data
#' @param source_data Optional source data for comparison overlay
#' @param primary_color Color for primary data
#' @return shiny tags
#' @noRd
render_stats_boxplot_section <- function(profile_data, source_data = NULL, primary_color = NULL) {
  colors <- get_stats_colors()
  has_source <- !is.null(source_data) &&
                !is.null(source_data$numeric_data) &&
                !is.null(source_data$numeric_data$p25) &&
                !is.na(source_data$numeric_data$p25)

  main_color <- if (!is.null(primary_color)) primary_color else if (has_source) colors$target else colors$source

  nd <- profile_data$numeric_data
  snd <- if (has_source) source_data$numeric_data else NULL

  if (!is.null(nd) && has_numeric_values(nd) && !is.null(nd$p25) && !is.na(nd$p25) && !is.null(nd$p75) && !is.na(nd$p75)) {
    # Create stats display
    stats_items <- list()

    # Mean
    if (!is.null(nd$mean) && !is.na(nd$mean)) {
      source_mean <- if (!is.null(snd) && !is.null(snd$mean)) snd$mean else NULL
      stats_items <- c(stats_items, list(create_stat_row("Mean", nd$mean, source_mean, main_color, colors$source)))
    }

    # Median
    if (!is.null(nd$median) && !is.na(nd$median)) {
      source_median <- if (!is.null(snd) && !is.null(snd$median)) snd$median else NULL
      stats_items <- c(stats_items, list(create_stat_row("Median", nd$median, source_median, main_color, colors$source)))
    }

    # SD
    if (!is.null(nd$sd) && !is.na(nd$sd)) {
      source_sd <- if (!is.null(snd) && !is.null(snd$sd)) snd$sd else NULL
      stats_items <- c(stats_items, list(create_stat_row("SD", nd$sd, source_sd, main_color, colors$source)))
    }

    # Range (min - max)
    if (!is.null(nd$min) && !is.na(nd$min) && !is.null(nd$max) && !is.na(nd$max)) {
      range_text <- paste(round(nd$min, 2), "-", round(nd$max, 2))
      source_range <- NULL
      if (!is.null(snd) && !is.null(snd$min) && !is.null(snd$max)) {
        source_range <- paste(round(snd$min, 2), "-", round(snd$max, 2))
      }
      stats_items <- c(stats_items, list(
        shiny::tags$div(
          style = "display: flex; gap: 5px; margin-bottom: 2px;",
          shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", "Range:"),
          if (!is.null(source_range)) {
            shiny::tags$span(
              shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), range_text),
              shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_range, ")"))
            )
          } else {
            shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), range_text)
          }
        )
      ))
    }

    # IQR (p25 - p75)
    if (!is.null(nd$p25) && !is.na(nd$p25) && !is.null(nd$p75) && !is.na(nd$p75)) {
      iqr_text <- paste(round(nd$p25, 2), "-", round(nd$p75, 2))
      source_iqr <- NULL
      if (!is.null(snd) && !is.null(snd$p25) && !is.na(snd$p25) && !is.null(snd$p75) && !is.na(snd$p75)) {
        source_iqr <- paste(round(snd$p25, 2), "-", round(snd$p75, 2))
      }
      stats_items <- c(stats_items, list(
        shiny::tags$div(
          style = "display: flex; gap: 5px; margin-bottom: 2px;",
          shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", "IQR:"),
          if (!is.null(source_iqr)) {
            shiny::tags$span(
              shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), iqr_text),
              shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_iqr, ")"))
            )
          } else {
            shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), iqr_text)
          }
        )
      ))
    }

    # P5 - P95 range
    if (!is.null(nd$p5) && !is.na(nd$p5) && !is.null(nd$p95) && !is.na(nd$p95)) {
      p5_p95_text <- paste(round(nd$p5, 2), "-", round(nd$p95, 2))
      source_p5_p95 <- NULL
      if (!is.null(snd) && !is.null(snd$p5) && !is.na(snd$p5) && !is.null(snd$p95) && !is.na(snd$p95)) {
        source_p5_p95 <- paste(round(snd$p5, 2), "-", round(snd$p95, 2))
      }
      stats_items <- c(stats_items, list(
        shiny::tags$div(
          style = "display: flex; gap: 5px; margin-bottom: 2px;",
          shiny::tags$span(style = "font-weight: 600; color: #666; min-width: 55px;", "P5-P95:"),
          if (!is.null(source_p5_p95)) {
            shiny::tags$span(
              shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), p5_p95_text),
              shiny::tags$span(style = paste0("color: ", colors$source, "; margin-left: 5px;"), paste0("(", source_p5_p95, ")"))
            )
          } else {
            shiny::tags$span(style = paste0("color: ", main_color, "; font-weight: 600;"), p5_p95_text)
          }
        )
      ))
    }

    # Create boxplot
    if (has_source) {
      boxplot <- create_dual_boxplot(snd, nd)
    } else {
      boxplot <- create_boxplot(nd, main_color)
    }

    return(shiny::tags$div(
      style = "height: 100%; display: flex; flex-direction: column; padding: 15px; gap: 10px;",
      # Stats section on top
      shiny::tags$div(
        style = "font-size: 12px;",
        stats_items
      ),
      # Boxplot section below
      shiny::tags$div(
        style = "flex: 1; min-height: 0;",
        if (!is.null(boxplot)) {
          shiny::renderPlot({ boxplot }, height = if (has_source) 80 else 50)
        }
      )
    ))
  }

  return(shiny::tags$p(style = "color: #999; font-style: italic; padding: 15px;", "No distribution data available."))
}


#' Render Histogram Section Only
#'
#' @description Renders only the histogram (no boxplot)
#'
#' @param profile_data Profile data containing histogram
#' @param source_data Optional source data for comparison overlay
#' @param primary_color Color for primary data
#' @return shiny tags
#' @noRd
render_stats_histogram_section <- function(profile_data, source_data = NULL, primary_color = NULL) {
  colors <- get_stats_colors()
  has_source <- !is.null(source_data) &&
                !is.null(source_data$numeric_data) &&
                !is.null(source_data$numeric_data$p25) &&
                !is.na(source_data$numeric_data$p25)

  main_color <- if (!is.null(primary_color)) primary_color else if (has_source) colors$target else colors$source

  # Parse histogram data
  target_hist <- parse_histogram_data(profile_data$histogram)
  source_hist <- if (has_source) parse_histogram_data(source_data$histogram) else NULL

  # Create histogram plot
  hist_plot <- NULL
  if (!is.null(target_hist)) {
    # Calculate percentages
    target_hist$percentage <- target_hist$count / sum(target_hist$count, na.rm = TRUE) * 100

    if (!is.null(source_hist)) {
      source_hist$percentage <- source_hist$count / sum(source_hist$count, na.rm = TRUE) * 100

      # Combine for dual plot
      target_hist$source <- "Target"
      source_hist$source <- "Source"
      combined_df <- rbind(target_hist, source_hist)

      hist_plot <- ggplot2::ggplot(combined_df, ggplot2::aes(x = x, y = percentage, color = source, fill = source)) +
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
    } else {
      hist_plot <- ggplot2::ggplot(target_hist, ggplot2::aes(x = x, y = percentage)) +
        ggplot2::geom_area(fill = main_color, alpha = 0.3) +
        ggplot2::geom_line(color = main_color, linewidth = 1.2) +
        ggplot2::geom_point(color = main_color, size = 2) +
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
    }

    return(shiny::tags$div(
      style = "height: 100%; padding: 15px; display: flex; flex-direction: column;",
      shiny::tags$div(
        style = "flex: 1; min-height: 0;",
        shiny::renderPlot({ hist_plot }, height = 300)
      )
    ))
  }

  return(shiny::tags$p(style = "color: #999; font-style: italic; padding: 15px;", "No histogram data available."))
}
