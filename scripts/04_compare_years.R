# Load the clean state-level dataset.
healthcare_data <- read.csv(
  file.path("data", "processed", "healthcare_access_states.csv"),
  fileEncoding = "UTF-8",
  stringsAsFactors = FALSE
)

# Select each year separately.
data_2022 <- subset(
  healthcare_data,
  year == 2022,
  select = c(state, healthcare_deprivation_pct)
)

data_2024 <- subset(
  healthcare_data,
  year == 2024,
  select = c(state, healthcare_deprivation_pct)
)

# Validate that each year has 32 unique states.
stopifnot(
  nrow(data_2022) == 32,
  nrow(data_2024) == 32,
  !anyDuplicated(data_2022$state),
  !anyDuplicated(data_2024$state)
)

# Join by state name so values cannot be paired by mistake.
comparison <- merge(
  data_2022,
  data_2024,
  by = "state",
  suffixes = c("_2022", "_2024"),
  all = TRUE
)

stopifnot(nrow(comparison) == 32, !anyNA(comparison))

# Calculate changes in percentage points using unrounded values.
comparison$change_pp <-
  comparison$healthcare_deprivation_pct_2024 -
  comparison$healthcare_deprivation_pct_2022

# Place the largest decreases first.
comparison <- comparison[order(comparison$change_pp), ]

# Save full precision for future analysis.
dir.create(
  file.path("data", "processed"),
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  comparison,
  file.path("data", "processed", "healthcare_change_2022_2024.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Round only the displayed table.
display_table <- comparison
display_table[-1] <- lapply(display_table[-1], round, digits = 2)

cat("\nChange in healthcare access deprivation, 2022 to 2024:\n")
print(display_table, row.names = FALSE)

cat("\nStates with a decrease:", sum(comparison$change_pp < 0), "\n")
cat("States with an increase:", sum(comparison$change_pp > 0), "\n")
cat("States with no change:", sum(comparison$change_pp == 0), "\n")

# Order changes so the largest decrease appears at the top.
plot_data <- comparison[order(comparison$change_pp, decreasing = TRUE), ]

# Use different colors for decreases and increases.
bar_colors <- ifelse(plot_data$change_pp < 0, "#25637A", "#D97706")

dir.create(
  file.path("reports", "figures"),
  recursive = TRUE,
  showWarnings = FALSE
)

chart_path <- file.path(
  "reports", "figures", "healthcare_change_2022_2024.png"
)

# Save a horizontal bar chart with room for state names.
png(chart_path, width = 1800, height = 2100, res = 180)
par(mar = c(6, 13, 5, 2))

bar_positions <- barplot(
  plot_data$change_pp,
  names.arg = plot_data$state,
  horiz = TRUE,
  las = 1,
  col = bar_colors,
  border = NA,
  cex.names = 0.75,
  xlim = c(
    min(0, plot_data$change_pp) - 4,
    max(0, plot_data$change_pp) + 4
  ),
  xlab = "Change in percentage points (2024 minus 2022)",
  main = "Change in healthcare access deprivation, 2022–2024"
)

# Mark zero to separate decreases from increases.
abline(v = 0, col = "#555555", lwd = 1)

# Place labels outside the bars.
text(
  x = plot_data$change_pp,
  y = bar_positions,
  labels = sprintf("%+.2f", plot_data$change_pp),
  pos = ifelse(plot_data$change_pp < 0, 2, 4),
  cex = 0.7
)

mtext(
  "Blue: decrease | Orange: increase",
  side = 1, line = 3.5, cex = 0.75
)

mtext(
  "Source: INEGI, PM 2024 | Descriptive changes; significance not assessed",
  side = 1, line = 4.5, cex = 0.65
)

invisible(dev.off())
cat("Chart saved to:", chart_path, "\n")