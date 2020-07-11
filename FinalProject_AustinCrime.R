library(tidyverse)
library(caret)
library(janitor)
library(lubridate)
library(RColorBrewer)
library(scales)
library(rpart)
library(MASS)
library(randomForest)
library(rpart.plot)
library(psych)

# Read in data
austin_crime <- read_csv('Crime_Reports.csv')

# Clean up variable names
austin_crime <- clean_names(austin_crime, 'snake')

# Structure of the data
str(austin_crime)

# Change occurred_date, report_date, and clearance_date from character to date
austin_crime$occurred_date <- mdy(austin_crime$occurred_date)
austin_crime$report_date <- mdy(austin_crime$report_date)
austin_crime$clearance_date <- mdy(austin_crime$clearance_date)

# Factor family_violence, location_type, and clearance_status
austin_crime$family_violence <- as.factor(austin_crime$family_violence)
austin_crime$location_type <- as.factor(austin_crime$location_type)
austin_crime$clearance_status <- as.factor(austin_crime$clearance_status)

# Extract year and month
austin_crime <- austin_crime %>%
    mutate(year = year(austin_crime$occurred_date)) %>% 
    mutate(month = month(austin_crime$occurred_date))

# Remove variables X-coordinate, Y-coordinate, Latitude, Longitude, and Location
austin_crime <- austin_crime[, -c(23, 24, 25, 26, 27)]

# Formatting for visuals
point <- format_format(big.mark = ",", decimal.mark = ".", scientific = FALSE)

# Crime totals for entire data set by year
crime_total <- ggplot(austin_crime, aes(x = year)) +
    geom_bar(fill = '#377eb8') +
    labs(title = 'Number of Crimes - 2003-2020',
         x = 'Year',
         y = 'Number of Crimes') +
    theme_bw()

crime_total + scale_y_continuous(labels = point)

# Filter data for last 5 years
crime1519 <- austin_crime %>% 
    filter(occurred_date >= as.Date('2015-01-01') & occurred_date <= as.Date('2019-12-31'))

# Crime total for 2015-2019
crime_total1519 <- ggplot(crime1519, aes(x = year)) +
    geom_bar(fill = '#377eb8') +
    labs(title = 'Number of Crimes - 2015-2019',
         x = 'Year',
         y = 'Number of Crimes') +
    theme_bw()

crime_total1519 + scale_y_continuous(labels = point)



# Omit the NA values
crime_clean <- na.omit(crime1519)

# Get just cleared by arrest and not cleared
crime_clean <- crime_clean %>% 
    filter(clearance_status == 'C' | clearance_status == 'N')

# Calculate days between occurred_data and report_date
crime_clean <- crime_clean %>% 
    mutate(days_to_report = report_date - occurred_date)

# Recode clearance_status to 1 = cleared 0 = not cleared
crime_clean <- crime_clean %>% 
    mutate(cleared = ifelse(clearance_status == 'C', 1, 0))

# Factor the variable cleared
crime_clean$cleared <- as.factor(crime_clean$cleared)

# Factor highest_offense_description
crime_clean$highest_offense_description <- as.factor(crime_clean$highest_offense_description)

# This crime only occurs once
sum(crime_clean$highest_offense_description == 'ARSON WITH BODILY INJURY')

# Find row with ARSON WITH BODILY INJURY
which(grepl('ARSON WITH BODILY INJURY', crime_clean$highest_offense_description))

# Remove that row
crime_clean <- crime_clean[-131900, ]

# Verify
sum(crime_clean$highest_offense_description == 'ARSON WITH BODILY INJURY')

# This location only occurs twice
sum(crime_clean$location_type == 'TRIBAL LANDS')

# Find rows with TRIBAL LANDS
which(grepl('TRIBAL LANDS', crime_clean$location_type))

# Remove rows
crime_clean <- crime_clean[-c(41567, 129551), ]

# Verify
sum(crime_clean$location_type == 'TRIBAL LANDS')

# Factor the variable category_description
crime_clean$category_description <- as.factor(crime_clean$category_description)

# Make crime_clean a data frame (was a tibble)
crime_clean <- as.data.frame(crime_clean)

# Train/Test split
set.seed(122)
inTrain <- createDataPartition(crime_clean$cleared, p = 0.8, list = FALSE)
crime_train <- crime_clean[inTrain, ]
crime_test <- crime_clean[-inTrain, ]

# Formula for the models
formula <- cleared ~ category_description + family_violence + location_type + zip_code +
    days_to_report

# Logistic Regression
log_model <- glm(formula, data = crime_train, family = 'binomial')
summary(log_model)

# Logistic Regression predictions
log_preds <- predict(log_model, newdata = crime_test, type = 'response')
log_class <- ifelse(log_preds >= 0.5, 1, 0)
confusionMatrix(as.factor(log_class), crime_test$cleared)

# Random Forest
rf_model <- randomForest(formula2, data = crime_train, 
                         ntree = 500, importance = TRUE)
rf_model

# Variable importance
importance(rf_model)

# Random Forest predictions
rf_pred <- predict(rf_model, newdata = crime_test, type = 'class')
confusionMatrix(rf_pred, crime_test$cleared)

