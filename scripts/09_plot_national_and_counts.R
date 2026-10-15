# Visualize national trends and state population counts.
# Run this script from the project root.

processed_dir <- file.path("data", "processed")
figures_dir <- file.path("reports", "figures")

national <- read.csv(
  file.path(processed_dir, "healthcare_national.csv")
)

states <- read.csv(
  file.path(processed_dir, "healthcare_states_with_counts.csv"),
  fileEncoding = "UTF-8",
  stringsAsFactors = FALSE
)

national <- national[order(national$year), ]

stopifnot(
  nrow(national) == 5,
  !anyDuplicated(national$year),
  !anyNA(national)
)

dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 1. Show national percentages and counts in separate panels.
# Separate axes avoid mixing percentages with millions of people.
# ------------------------------------------------------------

national_chart <- file.path(
  figures_dir, "healthcare_national_trend.png"
)

png(national_chart, width = 2200, height = 1100, res = 180)

par(
  mfrow = c(1, 2),
  mar = c(5, 5, 4, 2),
  oma = c(3, 0, 2, 0)
)

draw_national_panel <- function(values, title, y_label, color) {

  plot(
    national$year,
    values,
    type = "b",
    pch = 16,
    lwd = 2,
    col = color,
    xaxt = "n",
    ylim = c(0, max(values) * 1.2),
    xlim = c(2015.5, 2024.5),
    xlab = "Year",
    ylab = y_label,
    main = title
  )

  axis(1, at = national$year, labels = national$year)

  text(
    national$year,
    values,
    labels = sprintf("%.2f", values),
    pos = 3,
    cex = 0.8
  )
}

draw_national_panel(
  national$national_deprivation_pct,
  "National deprivation rate",
  "Population (%)",
  "#25637A"
)

draw_national_panel(
  national$national_people_millions,
  "People experiencing deprivation",
  "Millions of people",
  "#D97706"
)

mtext(
  "Mexico: healthcare access deprivation, 2016–2024",
  side = 3, outer = TRUE, line = 0, font = 2
)

mtext(
  "Source: INEGI, PM 2024 | Points represent the five available survey years",
  side = 1, outer = TRUE, line = 1, cex = 0.8
)

invisible(dev.off())

# ------------------------------------------------------------
# 2. Rank the ten states with the largest affected populations.
# ------------------------------------------------------------

states_2024 <- subset(states, year == 2024)

stopifnot(
  nrow(states_2024) == 32,
  !anyDuplicated(states_2024$state),
  !anyNA(states_2024),
  all(is.finite(states_2024$people_millions)),
  all(states_2024$people_millions >= 0)
)

top_ten <- head(
  states_2024[order(states_2024$people_millions, decreasing = TRUE), ],
  10
)

# Reverse the order so the largest bar appears at the top.
plot_data <- top_ten[nrow(top_ten):1, ]

counts_chart <- file.path(
  figures_dir, "healthcare_top10_people_2024.png"
)

png(counts_chart, width = 2200, height = 1500, res = 180)
par(mar = c(6, 14, 5, 2))

positions <- barplot(
  plot_data$people_millions,
  names.arg = plot_data$state,
  horiz = TRUE,
  las = 1,
  col = "#25637A",
  border = NA,
  cex.names = 0.85,
  xlim = c(0, max(plot_data$people_millions) * 1.3),
  xlab = "People experiencing healthcare access deprivation (millions)",
  main = "Ten states with the largest affected populations, 2024"
)

# Include both counts and percentages in the labels.
text(
  x = plot_data$people_millions,
  y = positions,
  labels = sprintf(
    "%.2f M | %.1f%%",
    plot_data$people_millions,
    plot_data$healthcare_deprivation_pct
  ),
  pos = 4,
  cex = 0.8
)

mtext(
  "Labels: millions of people | percentage of the state's population",
  side = 1, line = 3.5, cex = 0.75
)

mtext(
  "Source: INEGI, PM 2024 | Ranked by counts, not percentages",
  side = 1, line = 4.5, cex = 0.75
)

invisible(dev.off())

cat("Charts saved:\n")
cat(national_chart, "\n")
cat(counts_chart, "\n")

# Clarify the state name in the chart without changing the source data.
plot_data$state[plot_data$state == "México"] <- "Estado de México"
