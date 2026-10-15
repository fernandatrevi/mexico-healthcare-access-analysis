# Inspect the national table before extracting estimates.
library(readxl)

data_path <- file.path("data", "raw", "pm_ef_2024.xlsx")

if (!file.exists(data_path)) {
  stop("Dataset not found: ", data_path)
}

national_preview <- read_excel(
  data_path,
  sheet = "EUM",
  col_names = FALSE,
  col_types = "text",
  n_max = 25,
  .name_repair = "minimal"
)

# Print each row separately to keep titles and values together.
# Column numbers help distinguish population counts from percentages.
for (row_number in seq_len(nrow(national_preview))) {

  values <- as.character(
    unlist(national_preview[row_number, ], use.names = FALSE)
  )

  populated_columns <- which(!is.na(values) & nzchar(values))

  cat("\nRow", row_number, "\n")

  cat(
    paste(
      paste0(
        "Column ", populated_columns, ": ",
        values[populated_columns]
      ),
      collapse = " | "
    ),
    "\n"
  )
}
