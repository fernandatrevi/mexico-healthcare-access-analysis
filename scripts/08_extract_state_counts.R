# Extract state population counts and validate them against national totals.
library(readxl)

data_path <- file.path("data", "raw", "pm_ef_2024.xlsx")
processed_dir <- file.path("data", "processed")

state_data <- read.csv(
  file.path(processed_dir, "healthcare_access_states.csv"),
  fileEncoding = "UTF-8",
  stringsAsFactors = FALSE
)

national_data <- read.csv(
  file.path(processed_dir, "healthcare_national.csv")
)

state_sheets <- c(
  "Ags.", "BC", "BCS", "Camp.", "Coah.", "Col.",
  "Chis.", "Chih.", "CDMX", "Dgo.", "Gto.", "Gro.",
  "Hgo.", "Jal.", "Mex.", "Mich.", "Mor.", "Nay.",
  "NL", "Oax.", "Pue.", "Qro.", "Q. Roo", "SLP",
  "Sin.", "Son.", "Tab.", "Tamps.", "Tlax.", "Ver.",
  "Yuc.", "Zac."
)

years <- c(2016, 2018, 2020, 2022, 2024)

extract_counts <- function(sheet_name) {

  raw <- read_excel(
    data_path,
    sheet = sheet_name,
    col_names = FALSE,
    col_types = "text",
    n_max = 25,
    .name_repair = "minimal"
  )

  # State counts must be expressed in thousands of people.
  if (!isTRUE(grepl("miles de personas", raw[[1]][6],
                   fixed = TRUE)) ||
      !isTRUE(raw[[5]][7] == "Población")) {
    stop("Unexpected population units or header: ", sheet_name)
  }

  header_years <- as.numeric(
    unlist(raw[8, 5:9], use.names = FALSE)
  )

  if (!identical(header_years, as.numeric(years))) {
    stop("Unexpected population years: ", sheet_name)
  }

  indicator_row <- which(
    trimws(raw[[1]]) ==
      "Carencia por acceso a los servicios de salud"
  )

  if (length(indicator_row) != 1) {
    stop("Healthcare indicator missing or duplicated: ", sheet_name)
  }

  counts <- as.numeric(
    unlist(raw[indicator_row, 5:9], use.names = FALSE)
  )

  if (any(!is.finite(counts)) || any(counts < 0)) {
    stop("Invalid population counts: ", sheet_name)
  }

  data.frame(
    state = trimws(raw[[1]][4]),
    year = years,
    people_thousands = counts,

    # Convert thousands to millions for comparison with national data.
    people_millions = counts / 1000
  )
}

state_counts <- do.call(
  rbind,
  lapply(state_sheets, extract_counts)
)

# Join counts with the previously validated percentages.
complete_data <- merge(
  state_data,
  state_counts,
  by = c("state", "year"),
  all = TRUE
)

stopifnot(
  nrow(complete_data) == 160,
  length(unique(complete_data$state)) == 32,
  !anyDuplicated(complete_data[c("state", "year")]),
  !anyNA(complete_data)
)

# Check whether state counts sum to the published national estimate.
state_totals <- aggregate(
  people_millions ~ year,
  data = complete_data,
  FUN = sum
)

names(state_totals)[2] <- "state_sum_millions"

reconciliation <- merge(
  state_totals,
  national_data[c("year", "national_people_millions")],
  by = "year",
  all = TRUE
)

stopifnot(nrow(reconciliation) == 5, !anyNA(reconciliation))

reconciliation$difference_people <- (
  reconciliation$state_sum_millions -
  reconciliation$national_people_millions
) * 1000000

# Allow up to 100 people for rounding in the published tables.
# This is a numerical consistency check, not a statistical test.
if (any(abs(reconciliation$difference_people) > 100)) {
  stop("State and national totals differ by more than 100 people.")
}

write.csv(
  complete_data,
  file.path(processed_dir, "healthcare_states_with_counts.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  reconciliation,
  file.path(processed_dir, "healthcare_population_reconciliation.csv"),
  row.names = FALSE
)

# Rank states by estimated number of people experiencing deprivation.
ranking <- subset(complete_data, year == 2024)
ranking <- ranking[order(ranking$people_millions, decreasing = TRUE), ]

display_ranking <- ranking[
  , c("state", "healthcare_deprivation_pct", "people_millions")
]

display_ranking[-1] <- lapply(
  display_ranking[-1], round, digits = 2
)

cat("\nSTATES BY NUMBER OF PEOPLE EXPERIENCING DEPRIVATION: 2024\n")
print(display_ranking, row.names = FALSE)

cat("\nSTATE AND NATIONAL TOTAL CHECK\n")
print(reconciliation, row.names = FALSE)

cat("\nValidated datasets saved successfully.\n")
