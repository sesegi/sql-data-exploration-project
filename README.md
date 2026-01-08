# sql-data-exploration-project
velov' bicycle business dataset exploration
This project is grounded in a real-world bike-sharing business context. With the rapid expansion of urban bike-sharing services (such as Velo’v), platforms generate large volumes of data every day related to user trips, station operations, bike usage, and maintenance. Companies rely on well-structured databases and data analysis to support operational management and strategic decision-making.

In this project, SQL queries are used to analyse an existing bike-sharing database and address several key business-oriented questions, including:

Station usage analysis: identifying the station with the highest number of departures over the past 12 months to highlight high-demand locations.
Station maintenance analysis: detecting stations with a high proportion of defective docks and defining what constitutes “high” based on data distribution, in order to support maintenance decisions.
Operational data anomaly detection: identifying trips with data quality issues (such as abnormal timestamps, invalid distances, or missing values) and discussing appropriate handling approaches.
Overall ride performance monitoring: computing the average trip duration and average distance across all valid trips as core performance indicators of the system.
User loyalty analysis: identifying the most active users among those registered before 2024 and comparing their activity levels with the overall average.
User segmentation: classifying users into low, medium, and high usage groups based on their total accumulated riding distance and reporting the size of each segment.
Data consistency checks: comparing total kilometers recorded in user profiles with the sum of distances from their trip records to identify users with discrepancies greater than 5%.

In addition, the results were visualised, and an ER model of the company’s existing database was created to support further database redesign and analysis.
