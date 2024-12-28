# Load the saved PCA, K-means models, and column names of the subset_numeric
load("pca_model.RData")  # name of the variable is pca_result
load("kmeans_model.RData")  # name of the variable is kmeans_result
load("subset_numeric_columns.RData")  # Load only the column names

# Directory containing your batch files
batch_dir <- "data/processed_batches"  # Adjust to your directory

# List all CSV files in the directory
batch_files <- list.files(batch_dir, pattern = "\\.csv$", full.names = TRUE)

# -------------------
# Apply Clustering to Remaining Batch Files and Save
# -------------------

# Loop through each batch file and apply the PCA + K-means clustering
for (file in batch_files) {
  # Read batch file
  batch_data <- read.csv(file)
  
  # Preprocess: Remove 'bought' column and convert day phase columns to numeric
  batch_data <- batch_data[, !(names(batch_data) %in% c("bought"))]
  batch_data$day_phase_morning <- as.numeric(batch_data$day_phase_morning == "True")
  batch_data$day_phase_afternoon <- as.numeric(batch_data$day_phase_afternoon == "True")
  batch_data$day_phase_evening <- as.numeric(batch_data$day_phase_evening == "True")
  
  batch_data_numeric <- batch_data[, sapply(batch_data, is.numeric)]  # Ensure only numeric columns
  batch_data_numeric <- batch_data_numeric[, apply(batch_data_numeric, 2, var) != 0]  # Remove constant columns
  batch_data_numeric[is.na(batch_data_numeric)] <- 0  # Imputes NA with 0
  batch_data_numeric <- as.data.frame(lapply(batch_data_numeric, as.numeric))
  batch_data_scaled <- scale(as.matrix(batch_data_numeric))
  
  print(dim(batch_data_scaled))
  
  
  batch_data_scaled <- as.data.frame(batch_data_scaled)
  
  
  # Find the columns that are in the batch data but not in the subset_numeric_columns
  extra_cols <- setdiff(colnames(batch_data_scaled), subset_numeric_columns)
  
  # Remove extra columns
  batch_data_scaled <- batch_data_scaled[, !colnames(batch_data_scaled) %in% extra_cols]
  
  # Ensure columns align with the saved subset_numeric column names
  missing_cols <- setdiff(subset_numeric_columns, colnames(batch_data_scaled))
  
  # Impute missing columns with 0
  batch_data_scaled[missing_cols] <- sapply(missing_cols, function(col) {
    numeric(0)
  })
  
  batch_data_scaled <- scale(batch_data_scaled)

  
  # Apply PCA transformation to the batch data
  new_pca_data <- predict(pca_result, newdata = batch_data_scaled)[, 1:50]
  print(dim(new_pca_data))  # Check PCA projection dimensions
  print(head(new_pca_data))  # Inspect PCA-transformed data
  
  # Compute distances and assign clusters
  distances <- as.matrix(dist(rbind(kmeans_result$centers, new_pca_data)))
  print(dim(distances))  # Check the dimensions of the distance matrix
  
  # Assign clusters based on the nearest centroid
  cluster_assignments <- apply(distances[(nrow(kmeans_result$centers) + 1):nrow(distances), ], 1, which.min)
  print(length(cluster_assignments))  # Check the number of cluster assignments
  

  # Assign the cluster labels to batch data
  batch_data$cluster <- cluster_assignments
  
  # Add binary cluster columns
  for (i in 1:nrow(kmeans_result$centers)) {
    batch_data[paste0("cluster_", i)] <- as.numeric(batch_data$cluster == i)
  }
  
  # Define output directory and ensure it exists
  output_dir <- "data/output_batches"  # Specify your output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir)
  }
  
  # Save the clustered batch file
  output_file <- file.path(output_dir, basename(file))
  write.csv(batch_data, output_file, row.names = FALSE)
  
  # Free memory
  rm(batch_data, batch_data_scaled, new_pca_data)
  gc()
}
