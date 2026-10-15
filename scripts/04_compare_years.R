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
