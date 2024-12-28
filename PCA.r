# Load necessary libraries
library(ggplot2)
library(dplyr)
library(factoextra)
library(cluster)

options(max.print = 10000)


# Directory containing processed batches
batch_dir <- "data/processed_batches"
output_dir <- "data/clustered_batches"  # Directory for saving clustered files

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

# List all CSV files in the directory
batch_files <- list.files(batch_dir, pattern = "\\.csv$", full.names = TRUE)

# Randomly sample 25 files for PCA and clustering
set.seed(123)  # Ensure reproducibility
random_batch_files <- sample(batch_files, size = 50)

# Combine selected batch files into one data frame for PCA and clustering
subset_data <- do.call(rbind, lapply(random_batch_files, read.csv))

# Remove the 'bought' column
subset_data <- subset_data[, -which(names(subset_data) %in% c("bought"))]

# Convert "False"/"True" columns to numeric (1/0)
subset_data$day_phase_morning <- as.numeric(subset_data$day_phase_morning == "True")
subset_data$day_phase_afternoon <- as.numeric(subset_data$day_phase_afternoon == "True")
subset_data$day_phase_evening <- as.numeric(subset_data$day_phase_evening == "True")

# Select only numeric columns for PCA
subset_numeric <- subset_data[, sapply(subset_data, is.numeric)]

# Remove columns with zero variance
subset_numeric <- subset_numeric[, apply(subset_numeric, 2, var) != 0]

#save only names of the remaining columns dont save its data
#save(colnames(subset_numeric), file = "subset_numeric_columns.RData")


# Perform PCA
pca_result <- prcomp(scale(subset_numeric), center = TRUE, scale. = TRUE)


subset_numeric_cols <- colnames(subset_numeric)



# Choose the number of principal components (e.g., 50 or based on variance explained)
X <- 50  # Adjust based on analysis
pca_data <- pca_result$x[, 1:X]

# Perform K-Means clustering on the PCA-transformed subset
# For reproducibility
num_clusters <- 22  # Adjust based on your needs
kmeans_result <- kmeans(pca_data, centers = num_clusters, nstart = 15)

# Add cluster labels to the subset data
subset_data$cluster <- kmeans_result$cluster

# Save the clustered subset data for reference
#write.csv(subset_data, file.path(output_dir, "subset_clustered.csv"), row.names = FALSE)


# save the pca model
#save(pca_result, file = "pca_model.RData")

# save the kmeans model
#save(kmeans_result, file = "kmeans_model.RData")


# List all CSV files in the directory
batch_files <- list.files(batch_dir, pattern = "\\.csv$", full.names = TRUE)


# release memory of subset_numeric
rm(subset_numeric)
rm(subset_data)
gc()


# -------------------
# Apply Clustering to Remaining Batch Files and Save

# Align columns with the original PCA input
align_columns <- function(data, reference_columns) {
  # Remove extra columns
  data <- data[, colnames(data) %in% reference_columns, drop = FALSE]
  
  # Add missing columns with zeros
  missing_cols <- setdiff(reference_columns, colnames(data))
  data[missing_cols] <- 0
  
  # Ensure column order matches
  data <- data[, reference_columns]
  
  return(data)
}

# Function to assign clusters using pre-trained k-means model
assign_clusters <- function(pca_data, kmeans_model) {
  apply(pca_data, 1, function(row) {
    # Compute the squared Euclidean distance to each centroid
    distances <- colSums((t(kmeans_model$centers) - row)^2)
    # Return the index of the closest centroid
    which.min(distances)
  })
}
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
  
  # Example usage in the batch processing loop:
  batch_data_scaled <- align_columns(batch_data_numeric, subset_numeric_cols)
  
  # Apply PCA transformation
  new_pca_data <- predict(pca_result, newdata = batch_data_scaled)[, 1:X]

  
  # Add cluster labels to the batch data
  batch_data$cluster <- assign_clusters(new_pca_data, kmeans_result)
  
  #make column for each cluster except the last one
  for (i in 1:(num_clusters-1)){
    batch_data[paste0("cluster_", i)] <- as.numeric(batch_data$cluster == i)
  }
  
  
  # Save the clustered batch data
  write.csv(batch_data, file.path(output_dir, basename(file)), row.names = FALSE)
}



