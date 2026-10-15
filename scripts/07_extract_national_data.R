# Extract official national estimates and compare states with them.
library(readxl)

data_path <- file.path("data", "raw", "pm_ef_2024.xlsx")
state_path <- file.path(
  "data", "processed", "healthcare_access_states.csv"
)

if (!file.exists(data_path) || !file.exists(state_path)) {
  stop("Source workbook or processed state dataset is missing.")
}

raw <- read_excel(
  data_path,
  sheet = "EUM",
  col_names = FALSE,
  col_types = "text",
  n_max = 25,
  .name_repair = "minimal"
)

years <- c(2016, 2018, 2020, 2022, 2024)
population_columns <- 5:9
percentage_columns <- 11:15

# Validate units and headers before extracting values.
if (!isTRUE(grepl("millones de personas", raw[[1]][6],
                 fixed = TRUE))) {
  stop("Unexpected national population units.")
}

if (!isTRUE(raw[[5]][7] == "Población") ||
    !isTRUE(raw[[11]][7] == "Porcentaje")) {
  stop("Unexpected national table headers.")
}

for (columns in list(population_columns, percentage_columns)) {
  header_years <- as.numeric(
    unlist(raw[8, columns], use.names = FALSE)
  )

  if (!identical(header_years, as.numeric(years))) {
    stop("Unexpected year order in the national table.")
  }
}

# Locate the healthcare indicator by its label.
indicator_row <- which(
  trimws(raw[[1]]) ==
    "Carencia por acceso a los servicios de salud"
)

if (length(indicator_row) != 1) {
  stop("National healthcare indicator missing or duplicated.")
}

national_data <- data.frame(
  year = years,
  national_deprivation_pct = as.numeric(
    unlist(raw[indicator_row, percentage_columns],
           use.names = FALSE)
  ),
  national_people_millions = as.numeric(
    unlist(raw[indicator_row, population_columns],
           use.names = FALSE)
  )
)

stopifnot(
  !anyNA(national_data),
  all(is.finite(as.matrix(national_data))),
  all(national_data$national_deprivation_pct >= 0),
  all(national_data$national_deprivation_pct <= 100),
  all(national_data$national_people_millions >= 0)
)

# Join each state-year observation with the official national estimate.
state_data <- read.csv(
  state_path,
  fileEncoding = "UTF-8",
  stringsAsFactors = FALSE
)

stopifnot(
  nrow(state_data) == 160,
  !anyDuplicated(state_data[c("state", "year")]),
  setequal(state_data$year, years)
)

comparison <- merge(
  state_data,
  national_data[c("year", "national_deprivation_pct")],
  by = "year",
  all.x = TRUE
)

stopifnot(nrow(comparison) == 160, !anyNA(comparison))

# Positive values mean the state rate exceeds the national rate.
# This is a descriptive difference, not a statistical test.
comparison$gap_vs_national_pp <-
  comparison$healthcare_deprivation_pct -
  comparison$national_deprivation_pct

output_dir <- file.path("data", "processed")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(
  national_data,
  file.path(output_dir, "healthcare_national.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  comparison,
  file.path(output_dir, "healthcare_states_vs_national.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Round only the displayed results.
display_national <- national_data
display_national[-1] <- lapply(
  display_national[-1], round, digits = 2
)

cat("\nOFFICIAL NATIONAL ESTIMATES\n")
print(display_national, row.names = FALSE)

comparison_2024 <- subset(comparison, year == 2024)
comparison_2024 <- comparison_2024[
  order(comparison_2024$gap_vs_national_pp, decreasing = TRUE),
  c("state", "healthcare_deprivation_pct",
    "national_deprivation_pct", "gap_vs_national_pp")
]

display_comparison <- comparison_2024
display_comparison[-1] <- lapply(
  display_comparison[-1], round, digits = 2
)

cat("\nSTATE COMPARISON WITH THE NATIONAL RATE: 2024\n")
print(display_comparison, row.names = FALSE)

cat("\nCSV files saved successfully.\n")
