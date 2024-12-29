# Load necessary libraries
library(randomForest)
library(ranger)

# Directory containing clustered batches
clustered_batch_dir <- "data/clustered_batches"

# List all CSV files in the directory
clustered_files <- list.files(clustered_batch_dir, pattern = "\\.csv$", full.names = TRUE)

# Randomly sample 50 files for training
set.seed(321)  # Ensure reproducibility
train_files <- sample(clustered_files, size = 50)

# Combine the sampled training batch files into one data frame
train_data <- do.call(rbind, lapply(train_files, read.csv))

# remove "cluster" column
train_data <- train_data[, -which(names(train_data) %in% c("cluster"))]



train_data_num <- train_data[, sapply(train_data, is.numeric)]
train_data_num <- train_data_num[, apply(train_data_num, 2, var) != 0]  # Remove zero-variance columns

# set missing values to 0
train_data_num[is.na(train_data_num)] <- 0

class_counts <- table(train_data_num$bought)
class_weights <- 1 / class_counts
class_weights <- class_weights / sum(class_weights)  # Normalize weights

row_weights <- ifelse(train_data_num$bought == "0", class_weights["0"], class_weights["1"])

# Convert 'bought' column to a factor
train_data_num$bought <- as.factor(train_data_num$bought)

# Train the random forest model
rf_model <- ranger(
  formula = bought ~ ., 
  data = train_data_num, 
  num.trees = 151, 
  mtry = 7, 
  importance = "impurity", 
  case.weights = row_weights
)
print(rf_model)  # View model summary

# Testing on remaining files
test_files <- setdiff(clustered_files, train_files)
all_confusion_matrices <- list()  # To store confusion matrices for each test batch

traincolnames <- colnames(train_data_num)

#free memory
rm(train_data)
rm(train_data_num)
gc()

for (test_file in test_files) {
  # Read and preprocess the test batch
  test_data <- read.csv(test_file)
  
  #remove "cluster" column
  test_data <- test_data[, -which(names(test_data) %in% c("cluster"))]
  
  
  test_data_num <- test_data[, sapply(test_data, is.numeric)]
  test_data_num <- test_data_num[, apply(test_data_num, 2, var) != 0]  # Remove zero-variance columns
  test_data_num <- na.omit(test_data_num)
  
  missing_cols <- setdiff(traincolnames, colnames(test_data_num))
  for (col in missing_cols) {
    test_data_num[[col]] <- 0
  }
  
  # Ensure test data has the same columns as training data
  test_data_num <- test_data_num[, traincolnames, drop = FALSE]
  
  # Predict on the test batch
  predictions <- predict(rf_model, data = test_data_num)
  
  # Generate confusion matrix
  confusion_matrix <- table(Predicted = predictions$predictions, Actual = test_data_num$bought)
  all_confusion_matrices[[test_file]] <- confusion_matrix
  
  # Print confusion matrix for this batch
  #print(paste("Confusion Matrix for", test_file))
  #print(confusion_matrix)
}

# Combine results across all batches
overall_confusion_matrix <- Reduce(`+`, all_confusion_matrices)
print("Overall Confusion Matrix:")
print(overall_confusion_matrix)

# Calculate overall accuracy
overall_accuracy <- sum(diag(overall_confusion_matrix)) / sum(overall_confusion_matrix)
print(paste("Overall Accuracy:", round(overall_accuracy, 2)))
