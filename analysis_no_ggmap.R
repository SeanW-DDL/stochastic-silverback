#Load some libraries
library(dplyr)
library(ggplot2)

#Load the data
crimedata <- read.csv("SFPD_Incidents_-_Current_Year__2015_.csv")

#Define the variables from the command line
args <- commandArgs(TRUE)
if(length(args) < 1){
  crime <- 'ASSAULT' 
  day <- 'Monday' 
} else {
  crime <- toupper(commandArgs(TRUE)[1])
  day <- commandArgs(TRUE)[2]
  day <- paste0(toupper(substr(commandArgs(TRUE)[2], 1, 1)), 
                tolower(substr(commandArgs(TRUE)[2], 2, nchar(commandArgs(TRUE)[2]))))
}

#Define map coordinates for SF
SF_COORDINATES <- c(37.76, -122.45)

#Define function to filter the data
get_filtered <- function(crime, day){
  filter(crimedata,crimedata$DayOfWeek == day & crimedata$Category == crime)
}

get_number_crimes <- function(crime, day){
  df <- get_filtered(crime,day)
  nrow(df)
}

#Explore some of the raw data
filtered_crimedata<- get_filtered(crime, day)
print(unique(filtered_crimedata$Category), max.levels = 40, quote=TRUE)
head(filtered_crimedata)

#Plot where the crimes are on a map
sf <-ggplot() + geom_point(data=filtered_crimedata, aes(X, Y) , alpha=1)+labs(x="Longitude", y="Latitude")
sf
png('simple.png')
sf
dev.off()


#Do k-means to cluster and find areas of crime
X <- data.frame(filtered_crimedata$X, filtered_crimedata$Y)
Y<-kmeans(X,4)
X_with_clusters <- cbind(X, Y$cluster)
names(X_with_clusters)[3] <- ".cluster"
kmeans_plot <- sf + geom_point(data=X_with_clusters, 
                                     aes(x=filtered_crimedata.X, y=filtered_crimedata.Y),
                                     size=1, color=X_with_clusters$.cluster) +
  labs(x="Longitude", y="Latitude")
png('kmeans.png')
kmeans_plot
dev.off()

#Prepare the data to look at the time that crimes are occuring
time_data <- as.POSIXct(filtered_crimedata$Time,format="%H:%M")
df <- data.frame(time =  time_data)
df$time = strptime(df$time, "%Y-%m-%d %H:%M") 
df$x2 = paste0(substr(df$time, 1, 14), "00:00")
df2 = data.frame(table(df$x2))
names(df2) = c("Hour","Freq")
df2$Freq<-as.numeric(df2$Freq)
df2$Hour<-as.numeric(df2$Hour)

#Do a linear fit of the crimes by hour
fit <- lm(formula = Freq ~ Hour, data=df2)
summary(fit)
png('linear_regression.png')
p <-qplot(df2$Hour, df2$Freq)
p+ geom_abline(aes(intercept=fit$coefficients[1], 
                   slope=fit$coefficients[2]), col="red")
dev.off()

#Do a random forst regression of crime by hour
library(randomForest)
rf <- randomForest(Freq ~ Hour, data = df2, ntree=24)
pred <- data.frame(predict(rf, df2))
names(pred)[1] <- "Pred"
pred$Hour <- df2$Hour
p <-ggplot() + geom_point(data=df2, aes(Hour, Freq, color = "Actual") , alpha=1)
p<- p + geom_point(aes(x = Hour, y = Pred, color="Predicted"), data=pred, alpha =1)
p<- p+ labs(color="Actual vs Predicted")
png('rf.png')
p
dev.off()

#Save some diagnostic statistics for later use
diagnostics = list("crime" = crime, "day" = day, "n_crimes" = nrow(filtered_crimedata))
library(jsonlite)
fileConn<-file("dominostats.json")
writeLines(toJSON(diagnostics), fileConn)
close(fileConn)
