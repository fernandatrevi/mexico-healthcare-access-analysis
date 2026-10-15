# Rebuild the analysis from the original workbook.
# Run from the project root: Rscript run_analysis.R

if (!file.exists(file.path("data", "raw", "pm_ef_2024.xlsx"))) {
  stop("Save the source workbook in data/raw/pm_ef_2024.xlsx first.")
}

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop("The readxl package is required. See README.md for installation.")
}

# Inspection scripts 01 and 06 are exploratory and are not needed here.
scripts <- file.path(
  "scripts",
  c(
    "02_extract_healthcare_data.R",
    "03_plot_healthcare_access.R",
    "04_compare_years.R",
    "05_analyze_full_period.R",
    "07_extract_national_data.R",
    "08_extract_state_counts.R",
    "09_plot_national_and_counts.R"
  )
)

# Check all script paths before starting.
missing_scripts <- scripts[!file.exists(scripts)]

if (length(missing_scripts) > 0) {
  stop("Missing scripts: ", paste(missing_scripts, collapse = ", "))
}

# Run each script in a separate R process.
# Stop immediately if a step fails.
rscript_path <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
)

for (script_path in scripts) {

  cat("\nRunning:", script_path, "\n")

  status <- system2(
    rscript_path,
    args = c("--vanilla", shQuote(script_path))
  )

  if (status != 0) {
    stop("Analysis stopped because this script failed: ", script_path)
  }
}

# Record the source fingerprint and the environment used for this run.
dir.create("reports", showWarnings = FALSE)

source_path <- file.path("data", "raw", "pm_ef_2024.xlsx")

write.csv(
  data.frame(
    source_file = source_path,
    md5 = unname(tools::md5sum(source_path)),
    readxl_version = as.character(utils::packageVersion("readxl")),
    run_time_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  ),
  file.path("reports", "run_metadata.csv"),
  row.names = FALSE
)

writeLines(
  capture.output(sessionInfo()),
  file.path("reports", "session_info.txt")
)

cat("\nAnalysis completed successfully.\n")
cat("Tables: data/processed/\n")
cat("Charts: reports/figures/\n")
cat("Run information: reports/run_metadata.csv and reports/session_info.txt\n")
