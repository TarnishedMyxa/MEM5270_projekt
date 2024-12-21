# Load necessary libraries
library(ggplot2)
library(dplyr) #used in row names creation as well
library(factoextra) #for nice cluster graph
library(cluster) #another library for clustering plot

# Read the data
maindt <- read.csv("data/maindt_mini.csv")

# View the structure of the data
str(maindt)

# Convert "False"/"True" columns to logical (TRUE/FALSE) and then to numeric (1/0)
maindt$day_phase_morning <- as.numeric(maindt$day_phase_morning == "True")
maindt$day_phase_afternoon <- as.numeric(maindt$day_phase_afternoon == "True")
maindt$day_phase_evening <- as.numeric(maindt$day_phase_evening == "True")
#maindt$day_phase_night <- as.numeric(maindt$day_phase_night == "True")


# Select only numeric columns for PCA
maindt_numeric <- maindt[, sapply(maindt, is.numeric)]


# bruh...
maindt_numeric <- maindt_numeric[, apply(maindt_numeric, 2, var) != 0]

# shouldn´t be any but just to be sure
maindt_numeric <- na.omit(maindt_numeric)

# maybe unneccessary
maindt_scaled <- scale(maindt_numeric)

# Perform PCA
pca_result <- prcomp(maindt_scaled, center = TRUE, scale. = TRUE)

# View summary of PCA
summary(pca_result)

# Scree plot to show the proportion of variance explained by each principal component
screeplot(pca_result, main = "Scree Plot", col = "blue")


# Optionally, you can also view the first few principal components
head(pca_result$x)


# Select the first X components for clustering
X <- 15  # Adjust this based on your analysis
pca_data <- pca_result$x[, 1:X]


# Set the number of clusters
num_clusters <- 5  # Adjust this as needed

# Perform K-Means clustering
set.seed(123)  # For reproducibility


wss <- function(k) {
  kmeans(pca_data, k, nstart = 10 )$tot.withinss
}
k_values <- 1:15
wss_values <- sapply(k_values,wss)
plot(k_values, wss_values,
     type="b", pch = 19, frame = FALSE,
     xlab="Number of clusters K",
     ylab="Total within-clusters sum of squares")


sampled_data <- pca_data[sample(1:nrow(pca_data), size = 25000), ]  # Adjust sample size


nclust_silh <- fviz_nbclust(sampled_data, kmeans, method = "silhouette")
nclust_silh$data
nclust_silh

gap_stat <- clusGap(sampled_data, FUN = kmeans, nstart = 10,
                    K.max = 40, B = 50)
fviz_gap_stat(gap_stat)


kmeans_result <- kmeans(pca_data, centers = num_clusters, nstart = 25)

# Add cluster labels to the original data
maindt$cluster <- kmeans_result$cluster



# Scatter plot of the first two principal components
ggplot(data = as.data.frame(pca_data), aes(x = PC1, y = PC2, color = as.factor(kmeans_result$cluster))) +
  geom_point(size = 2) +
  labs(title = "Clustering Based on PCA", color = "Cluster") +
  theme_minimal()

