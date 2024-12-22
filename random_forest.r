library(randomForest)
library(ranger)

# Load the data
data <- read.csv("data/maindt_mini_clustered.csv")



# Convert "False"/"True" columns to logical (TRUE/FALSE) and then to numeric (1/0)
data$day_phase_morning <- as.numeric(data$day_phase_morning == "True")
data$day_phase_afternoon <- as.numeric(data$day_phase_afternoon == "True")
data$day_phase_evening <- as.numeric(data$day_phase_evening == "True")
#maindt$day_phase_night <- as.numeric(data$day_phase_night == "True")


# Select only numeric columns for PCA
data_num <- data[, sapply(data, is.numeric)]


# bruh...
data_num <- data_num[, apply(data_num, 2, var) != 0]

# shouldn´t be any but just to be sure
data_num <- na.omit(data_num)


data_num$bought <- as.factor(data_num$bought)


set.seed(123)  # For reproducibility
sample_index <- sample(1:nrow(data_num), 0.7 * nrow(data_num))  # 70% training data
train_data <- data_num[sample_index, ]
test_data <- data_num[-sample_index, ]


rf_model <- ranger(bought ~ ., data = train_data, num.trees = 100, mtry = 3, importance = "impurity")
print(rf_model)  # View the model summary


predictions <- predict(rf_model, newdata = test_data)

confusion_matrix <- table(predictions, test_data$Species)
print(confusion_matrix)

accuracy <- sum(diag(confusion_matrix)) / sum(confusion_matrix)
print(paste("Accuracy:", round(accuracy, 2)))


importance(rf_model)
varImpPlot(rf_model)

