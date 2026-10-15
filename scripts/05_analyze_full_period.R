# Analyze state-level healthcare access deprivation over all five years.
# Run this script from the project root.

input_path <- file.path(
  "data", "processed", "healthcare_access_states.csv"
)

if (!file.exists(input_path)) {
  stop("Processed dataset not found. Run script 02 first.")
}

healthcare_data <- read.csv(
  input_path,
  fileEncoding = "UTF-8",
  stringsAsFactors = FALSE
)

# Check required columns before using the dataset.
required_columns <- c(
  "state", "year", "healthcare_deprivation_pct"
)

if (!all(required_columns %in% names(healthcare_data))) {
  stop("Required columns are missing.")
}

expected_years <- c(2016, 2018, 2020, 2022, 2024)

# Validate the complete state-year panel.
stopifnot(
  nrow(healthcare_data) == 160,
  length(unique(healthcare_data$state)) == 32,
  setequal(healthcare_data$year, expected_years),
  !anyNA(healthcare_data[required_columns]),
  !anyDuplicated(healthcare_data[c("state", "year")]),
  all(healthcare_data$healthcare_deprivation_pct >= 0),
  all(healthcare_data$healthcare_deprivation_pct <= 100)
)

# Verify that every state has all five expected years.
state_years <- split(healthcare_data$year, healthcare_data$state)

if (!all(vapply(
  state_years,
  function(x) setequal(x, expected_years),
  logical(1)
))) {
  stop("At least one state has an incomplete time series.")
}

processed_dir <- file.path("data", "processed")
figures_dir <- file.path("reports", "figures")

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 1. Describe differences across states for each year.
# ------------------------------------------------------------

yearly_summary <- do.call(
  rbind,
  lapply(expected_years, function(selected_year) {

    current <- subset(healthcare_data, year == selected_year)
    values <- current$healthcare_deprivation_pct

    data.frame(
      year = selected_year,
      minimum_pct = min(values),
      maximum_pct = max(values),

      # Range measures the distance between the two extremes.
      range_pp = max(values) - min(values),

      # The IQR describes the spread of the middle 50% of states.
      iqr_pp = as.numeric(IQR(values)),

      # This median gives each state equal weight.
      # It is not the national population deprivation rate.
      median_state_pct = median(values)
    )
  })
)

write.csv(
  yearly_summary,
  file.path(processed_dir, "healthcare_yearly_summary.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 2. Compare 2016 with 2024 for every state.
# ------------------------------------------------------------

start_data <- subset(
  healthcare_data,
  year == 2016,
  select = c(state, healthcare_deprivation_pct)
)

end_data <- subset(
  healthcare_data,
  year == 2024,
  select = c(state, healthcare_deprivation_pct)
)

long_term_change <- merge(
  start_data,
  end_data,
  by = "state",
  suffixes = c("_2016", "_2024"),
  all = TRUE
)

stopifnot(
  nrow(long_term_change) == 32,
  !anyNA(long_term_change)
)

# Positive values mean deprivation was higher in 2024.
long_term_change$change_pp <-
  long_term_change$healthcare_deprivation_pct_2024 -
  long_term_change$healthcare_deprivation_pct_2016

long_term_change <- long_term_change[
  order(long_term_change$change_pp),
]

write.csv(
  long_term_change,
  file.path(processed_dir, "healthcare_change_2016_2024.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 3. Plot every state's five-year trajectory.
# ------------------------------------------------------------

# Use separate panels to avoid 32 overlapping lines.
# Keep identical axes so states can be compared visually.
states <- sort(unique(healthcare_data$state))

plot_upper <- min(
  100,
  ceiling(max(healthcare_data$healthcare_deprivation_pct) / 10) * 10 + 5
)

trajectory_path <- file.path(
  figures_dir, "healthcare_state_trends_2016_2024.png"
)

png(
  trajectory_path,
  width = 3000,
  height = 3400,
  res = 180
)

par(
  mfrow = c(8, 4),
  mar = c(2.4, 2.8, 2.5, 0.8),
  oma = c(4, 4, 4, 1)
)

for (state_name in states) {

  current <- subset(healthcare_data, state == state_name)
  current <- current[order(current$year), ]

  line_color <- if (state_name == "Nuevo León") {
    "#D97706"
  } else {
    "#25637A"
  }

  plot(
    current$year,
    current$healthcare_deprivation_pct,
    type = "n",
    ylim = c(0, plot_upper),
    xlim = c(2016, 2024),
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = paste(strwrap(state_name, width = 24), collapse = "\n"),
    cex.main = 0.8,
    cex.axis = 0.75,
    las = 1
  )

  axis(
    side = 1,
    at = expected_years,
    labels = expected_years,
    cex.axis = 0.7
  )

  abline(
    h = seq(0, plot_upper, by = 20),
    col = "#E5E7EB",
    lty = 1
  )

  lines(
    current$year,
    current$healthcare_deprivation_pct,
    type = "b",
    pch = 16,
    col = line_color,
    lwd = 2,
    cex = 0.7
  )
}

mtext(
  "Healthcare access deprivation across Mexican states, 2016–2024",
  side = 3, outer = TRUE, line = 1, cex = 1.2, font = 2
)

mtext(
  "Population with healthcare access deprivation (%)",
  side = 2, outer = TRUE, line = 1.5, cex = 1
)

mtext(
  "Source: INEGI, PM 2024 | Same scale in every panel",
  side = 1, outer = TRUE, line = 1.5, cex = 0.9
)

invisible(dev.off())

# ------------------------------------------------------------
# 4. Plot how the spread across states changed.
# ------------------------------------------------------------

gap_path <- file.path(
  figures_dir, "healthcare_state_gaps_2016_2024.png"
)

png(gap_path, width = 1800, height = 1200, res = 180)

par(mar = c(6, 5, 4, 2))

plot(
  yearly_summary$year,
  yearly_summary$range_pp,
  type = "b",
  pch = 16,
  col = "#25637A",
  lwd = 2,
  ylim = c(
    0,
    max(yearly_summary$range_pp, yearly_summary$iqr_pp) + 8
  ),
  xaxt = "n",
  xlab = "Year",
  ylab = "Percentage points",
  main = "Spread in healthcare access deprivation across states"
)

axis(1, at = expected_years, labels = expected_years)

lines(
  yearly_summary$year,
  yearly_summary$iqr_pp,
  type = "b",
  pch = 17,
  col = "#D97706",
  lwd = 2
)

legend(
  "topleft",
  legend = c(
    "Range: highest minus lowest state rate",
    "IQR: spread of the middle 50% of states"
  ),
  col = c("#25637A", "#D97706"),
  pch = c(16, 17),
  lwd = 2,
  bty = "n",
  cex = 0.8
)

mtext(
  "Source: INEGI, PM 2024 | Descriptive measures; states have equal weight",
  side = 1, line = 4, cex = 0.7
)

invisible(dev.off())

# ------------------------------------------------------------
# 5. Print results without rounding the saved datasets.
# ------------------------------------------------------------

display_summary <- yearly_summary
display_summary[-1] <- lapply(
  display_summary[-1], round, digits = 2
)

display_change <- long_term_change
display_change[-1] <- lapply(
  display_change[-1], round, digits = 2
)

cat("\nYEARLY SUMMARY\n")
print(display_summary, row.names = FALSE)

cat("\nSTATE CHANGES: 2016 TO 2024\n")
print(display_change, row.names = FALSE)

cat(
  "\nStates with higher estimated deprivation in 2024 than 2016:",
  sum(long_term_change$change_pp > 0),
  "\n"
)

cat(
  "States with lower estimated deprivation in 2024 than 2016:",
  sum(long_term_change$change_pp < 0),
  "\n"
)

cat("\nCharts saved to:\n")
cat(trajectory_path, "\n")
cat(gap_path, "\n")
