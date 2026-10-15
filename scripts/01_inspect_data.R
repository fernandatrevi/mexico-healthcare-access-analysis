# Load the package used to read Excel files.
library(readxl)

# Run this script from the project root.
data_path <- file.path("data", "raw", "pm_ef_2024.xlsx")

# Stop with a clear message if the source file is missing.
if (!file.exists(data_path)) {
  stop("Dataset not found: ", data_path)
}

# List the workbook sheets before choosing the tables to analyze.
sheet_names <- excel_sheets(data_path)

cat("Available sheets:\n")
print(sheet_names)

# Read the first 25 rows without assuming where the headers begin.
# Keep all columns as text during this initial inspection.
preview_nl <- read_excel(
  data_path,
  sheet = "NL",
  col_names = FALSE,
  col_types = "text",
  n_max = 25
)

# Display every column to inspect titles, years, and indicators.
cat("\nNuevo Leon: first 25 rows\n")
print(preview_nl, n = 25, width = Inf)

# Find the healthcare access indicator by its label.
health_row <- which(
  preview_nl[[1]] == "Carencia por acceso a los servicios de salud"
)

# Stop if the indicator is missing or appears more than once.
if (length(health_row) != 1) {
  stop("Expected exactly one healthcare access indicator.")
}

# Extract percentages for each year.
# These values are already percentages: do not multiply by 100.
healthcare_nl <- data.frame(
  state = "Nuevo León",
  year = c(2016, 2018, 2020, 2022, 2024),
  healthcare_deprivation_pct = as.numeric(
    unlist(preview_nl[health_row, 11:15], use.names = FALSE)
  )
)

# Display the clean table.
cat("\nHealthcare access deprivation in Nuevo Leon:\n")
print(healthcare_nl, row.names = FALSE)
