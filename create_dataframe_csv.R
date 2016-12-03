# Load the required libraries
library(stringr)
library(tidyr)

# Set the working directory
setwd("WORKING_DIRECTORY_HERE")

# Load functions
get_home_goals <- function(raw.string) {
  s <- strsplit(raw.string, "-")[[1]][1]
  substr(s, nchar(s), nchar(s))
}

get_away_goals <- function(raw.string) {
  s <- strsplit(raw.string, "-")[[1]][2]
  substr(s, 1, 1)
}

get_home_team <- function(raw.string) {
  team.name <- strsplit(raw.string, "-")[[1]][1]
  str_trim(substr(team.name, 1, nchar(team.name)-1))
}

get_away_team <- function(raw.string) {
  team.name <- strsplit(raw.string, "-")[[1]][2]
  str_trim(substr(team.name, 2, nchar(team.name)))
}

# Load the txt file and add some columns
df <- read.table(file = "mls.txt", header = FALSE, sep = "\n", col.names = "raw",
                 fill = TRUE, stringsAsFactors = FALSE)
df$day <- NA
df$dd.mm <- NA

# Create a column to discern which are dates and which are game results
df$has.date <- str_detect(df[,1], fixed("["))

# Split data into weekday and day.month
df$day[df$has.date == TRUE] <- sapply(df$raw[df$has.date == TRUE],
                                        function(x) strsplit(x, split = ". ")[[1]][1])
df$dd.mm[df$has.date == TRUE] <- sapply(df$raw[df$has.date == TRUE],
                                        function(x) strsplit(x, split = ". ")[[1]][2])

df <- df %>% fill(day)
df <- df %>% fill(dd.mm)

df$day <- sapply(df$day, function(x) str_replace(x, fixed("["), ""))
df$dd.mm <- sapply(df$dd.mm, function(x) str_replace(x, fixed(".]"), ""))

# Delete the game date rows
df <- df[df$has.date == FALSE,]
df$has.date <- NULL

# Get the home team, away team and score
df$home.team <- sapply(df$raw, function(x) get_home_team(x))
df$away.team <- sapply(df$raw, function(x) get_away_team(x))

df$home.score <- as.numeric(sapply(df$raw, function(x) get_home_goals(x)))
df$away.score <- as.numeric(sapply(df$raw, function(x) get_away_goals(x)))

# Print some of the dataframe
head(df, 20)

# Write the dataframe to a csv file
write.csv(x = df, file = "mls.2015.csv", row.names = FALSE)
