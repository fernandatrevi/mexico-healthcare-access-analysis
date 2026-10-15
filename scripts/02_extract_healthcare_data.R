library(readxl)

# Locate the source workbook.
data_path <- file.path("data", "raw", "pm_ef_2024.xlsx")

if (!file.exists(data_path)) {
  stop("Dataset not found: ", data_path)
}

# Explicitly select the 32 state sheets.
# Exclude national totals, charts, and IP sheets.
state_sheets <- c(
  "Ags.", "BC", "BCS", "Camp.", "Coah.", "Col.",
  "Chis.", "Chih.", "CDMX", "Dgo.", "Gto.", "Gro.",
  "Hgo.", "Jal.", "Mex.", "Mich.", "Mor.", "Nay.",
  "NL", "Oax.", "Pue.", "Qro.", "Q. Roo", "SLP",
  "Sin.", "Son.", "Tab.", "Tamps.", "Tlax.", "Ver.",
  "Yuc.", "Zac."
)

years <- c(2016, 2018, 2020, 2022, 2024)
percentage_columns <- 11:15
indicator <- "Carencia por acceso a los servicios de salud"

# Define a reusable function that processes one state.
extract_state <- function(sheet_name) {
  raw <- read_excel(
    data_path,
    sheet = sheet_name,
    col_names = FALSE,
    col_types = "text",
    n_max = 25,
    .name_repair = "minimal"
  )

  # Check the expected percentage heading and year order.
  header_years <- as.numeric(
    unlist(raw[8, percentage_columns], use.names = FALSE)
  )

  if (!isTRUE(raw[[11]][7] == "Porcentaje") ||
      !identical(header_years, as.numeric(years))) {
    stop("Unexpected percentage headers in sheet: ", sheet_name)
  }

  # Find the indicator by its label instead of a fixed row number.
  indicator_row <- which(trimws(raw[[1]]) == indicator)

  if (length(indicator_row) != 1) {
    stop("Healthcare indicator missing or duplicated: ", sheet_name)
  }

  percentages <- as.numeric(
    unlist(raw[indicator_row, percentage_columns], use.names = FALSE)
  )

  # Reject missing values or percentages outside the valid range.
  if (anyNA(percentages) ||
      any(percentages < 0 | percentages > 100)) {
    stop("Invalid healthcare percentages in sheet: ", sheet_name)
  }

  # Read the full state name from the sheet title.
  state_name <- trimws(raw[[1]][4])

  if (is.na(state_name) || state_name == "") {
    stop("Missing state name in sheet: ", sheet_name)
  }

  data.frame(
    state = state_name,
    year = years,
    healthcare_deprivation_pct = percentages
  )
}

# Apply the function to every state and combine the results.
healthcare_data <- do.call(
  rbind,
  lapply(state_sheets, extract_state)
)

# Confirm that every state-year pair appears exactly once.
stopifnot(
  nrow(healthcare_data) == 160,
  length(unique(healthcare_data$state)) == 32,
  !anyDuplicated(healthcare_data[c("state", "year")])
)

# Save the clean dataset without rounding the source values.
dir.create(file.path("data", "processed"), recursive = TRUE,
           showWarnings = FALSE)

output_path <- file.path(
  "data", "processed", "healthcare_access_states.csv"
)

write.csv(
  healthcare_data,
  output_path,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("States:", length(unique(healthcare_data$state)), "\n")
cat("Rows:", nrow(healthcare_data), "\n")
cat("Saved to:", output_path, "\n")
print(head(healthcare_data, 10), row.names = FALSE)
