# Load the clean dataset created by the extraction script.
data_path <- file.path(
  "data", "processed", "healthcare_access_states.csv"
)

healthcare_data <- read.csv(
  data_path,
  fileEncoding = "UTF-8",
  stringsAsFactors = FALSE
)

# Select 2024 and check that each state appears once.
data_2024 <- subset(healthcare_data, year == 2024)

stopifnot(
  nrow(data_2024) == 32,
  !anyDuplicated(data_2024$state),
  !anyNA(data_2024$healthcare_deprivation_pct)
)

# Sort in ascending order so the largest bar appears at the top.
data_2024 <- data_2024[
  order(data_2024$healthcare_deprivation_pct),
]

# Highlight Nuevo Leon to make it easier to locate.
bar_colors <- ifelse(
  data_2024$state == "Nuevo León",
  "#D97706",
  "#25637A"
)

# Create the output folder.
dir.create(
  file.path("reports", "figures"),
  recursive = TRUE,
  showWarnings = FALSE
)

output_path <- file.path(
  "reports", "figures", "healthcare_access_2024.png"
)

# Open a PNG file: the following plotting commands draw into it.
png(output_path, width = 1800, height = 2100, res = 180)

# Leave enough space on the left for state names.
par(mar = c(5, 13, 5, 2))

bar_positions <- barplot(
  data_2024$healthcare_deprivation_pct,
  names.arg = data_2024$state,
  horiz = TRUE,
  las = 1,
  col = bar_colors,
  border = NA,
  cex.names = 0.75,
  xlim = c(0, max(data_2024$healthcare_deprivation_pct) + 8),
  xlab = "Population with healthcare access deprivation (%)",
  main = "Healthcare access deprivation by state, 2024"
)

# Add percentage labels at the end of each bar.
text(
  x = data_2024$healthcare_deprivation_pct,
  y = bar_positions,
  labels = sprintf("%.1f%%", data_2024$healthcare_deprivation_pct),
  pos = 4,
  cex = 0.7
)

mtext(
  "Source: INEGI, Multidimensional Poverty 2024 | Orange: Nuevo Leon",
  side = 1,
  line = 3.5,
  cex = 0.7
)

# Close the file to finish saving the image.
invisible(dev.off())

cat("Chart saved to:", output_path, "\n")
