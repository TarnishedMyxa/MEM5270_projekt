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


# Fit a logistic regression model (logit link)
logit_model <- glm(bought ~ ., data = train_data, family = binomial(link = "logit"))

# Summary of the model
summary(logit_model)

# Predict probabilities
predictions_logit <- predict(logit_model, newdata = test_data, type = "response")

# Convert probabilities to class labels (0 or 1)
predicted_classes_logit <- ifelse(predictions_logit > 0.5, 1, 0)


# Confusion matrix
confusion_matrix_logit <- table(Predicted = predicted_classes_logit, Actual = test_data$bought)
print(confusion_matrix_logit)

# Accuracy
accuracy_logit <- sum(diag(confusion_matrix_logit)) / sum(confusion_matrix_logit)
print(paste("Accuracy:", round(accuracy_logit, 2)))



# Get the coefficients (log-odds)
coefficients_logit <- coef(logit_model)

# Plot feature importance (absolute value of coefficients)
importance_logit <- abs(coefficients_logit)
importance_logit <- importance_logit[-1]  # Exclude intercept term
barplot(sort(importance_logit, decreasing = TRUE), main = "Feature Importance (Logit)", las = 2)
