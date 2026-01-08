-- For the PROJECT I use the 'Bikeshare_en' database. 
-- It is part of a dataset derived from a bycicle sharing service in the city of Chicago, IL (USA) 
-- The service is similar to Lyon's "Velo'v". 
-- The database has multiple tables: 
-- that correspond to various trips done by users, 
-- and bike stations, which contains some data on each of the stations from which you start and end bike trips.

-- ------
-- Question 1: Station usage
-- Find the station that records the highest number of trip departures 
-- over the past 12 months?
SELECT
    s.id AS station_id,
    s.name AS station_name,
    COUNT(*) AS departures_last_12m
FROM trips t
JOIN stations s ON t.start_station_id = s.id
WHERE t.start_datetime IS NOT NULL
  AND t.start_datetime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
  AND t.end_datetime > t.start_datetime
GROUP BY s.id, s.name
ORDER BY departures_last_12m DESC
LIMIT 1;

-- Question 2: Station maintenance
-- Which stations have a high defective dock rate of their total capacity?
-- Find what means "high" in this use case
WITH rates AS (
    SELECT
        id,
        name,
        capacity,
        defective_docks,
        defective_docks / capacity AS defective_rate,
        PERCENT_RANK() OVER (ORDER BY defective_docks / capacity) AS pr
    FROM stations
    WHERE capacity >= 10
      AND defective_docks <= capacity
)
SELECT
    id,
    name,
    capacity,
    defective_docks,
    ROUND(defective_rate, 3) AS defective_rate
FROM rates
WHERE pr >= 0.90
ORDER BY defective_rate DESC;
-- Comment:
-- I delete the restriction of dock capacity smaller than 10 because this is not going to bias the result and we should consider all circumstances


-- Question 3: Operational anomaly detection
-- Identify all the trips that present data issues. 
-- Detail what kind of issues are they
-- And how would you intent to solve them.
SELECT
    id AS trip_id,
    user_id,
    bike_id,
    start_station_id,
    end_station_id,
    start_datetime,
    end_datetime,
    duration_minutes,
    km,
    TRIM(BOTH ';' FROM CONCAT_WS(';',
        IF(start_datetime IS NULL OR end_datetime IS NULL, 'MISSING_DATETIME', NULL),
        IF(end_datetime <= start_datetime, 'END_BEFORE_START', NULL),
        IF(duration_minutes IS NULL, 'MISSING_DURATION', NULL),
        IF(duration_minutes <= 0, 'NON_POSITIVE_DURATION', NULL),
        IF(km IS NULL, 'MISSING_DISTANCE', NULL),
        IF(km < 0, 'NEGATIVE_DISTANCE', NULL),
        IF(km = 0 AND duration_minutes > 0, 'ZERO_DISTANCE_WITH_DURATION', NULL),
       IF(km = 2000, 'EXTREME_DISTANCE', NULL),

       IF(user_id IS NULL, 'MISSING_USER', NULL),
        IF(start_station_id IS NULL OR end_station_id IS NULL, 'MISSING_STATION', NULL)
    )) AS anomaly_type
FROM trips
HAVING anomaly_type != ''
ORDER BY trip_id;
-- Comment:
-- The detected anomalies correspond to structurally invalid or logically inconsistent trips 
-- (e.g. missing timestamps, negative durations, or impossible distances).
-- For this dataset, replacing such values with a global mean would introduce bias, 
-- Therefore these records should be excluded from analytical calculations.
-- In some cases (e.g. missing distance), an alternative solution could be to estimate the value 
-- based on average speed and trip duration, but this would require additional business assumptions.


-- Question 4: Ride monitoring
-- What is the average trip duration (in minutes) 
-- and the average distance (in kilometers) across all valid trips?
SELECT
    ROUND(AVG(duration_minutes), 2) AS avg_trip_duration_minutes,
    ROUND(AVG(km), 2) AS avg_trip_distance_km,
    COUNT(*) AS valid_trip_count
FROM trips
WHERE end_datetime > start_datetime
  AND duration_minutes > 0
  AND km > 0
AND km <> 2000
  AND user_id IS NOT NULL
  AND start_station_id IS NOT NULL
  AND end_station_id IS NOT NULL;
-- comment：the average trip distance (in kilometers) across all valid trips.
-- A valid trip is defined as:
-- 1) end time is later than start time
-- 2) duration and distance are greater than 0
-- 3) distance is not an outlier value (km <> 2000)
-- 4) user ID, start station ID, and end station ID are not NULL
-- The results are rounded to 2 decimal places.


-- Question 5: User loyalty
-- Among users who registered before January 1st, 2024, 
-- Which ones have completed the biggest number of trips in total?
-- Compared to the average number of trips. 
-- Provide an output as a monitoring table to summarize this, 
-- that includes number of trips and average number at each row of the table.
WITH user_trip_counts AS (
    SELECT
        u.id AS user_id,
        u.first_name,
        u.last_name,
        u.registration_date,
        COUNT(t.id) AS trips_count
    FROM users u
    LEFT JOIN trips t ON t.user_id = u.id
        AND t.end_datetime > t.start_datetime
        AND t.duration_minutes > 0
        AND t.km > 0
        AND t.km <>2000
    WHERE u.registration_date < '2024-01-01'
    GROUP BY u.id, u.first_name, u.last_name, u.registration_date
),
avg_trips AS (
    SELECT AVG(trips_count) AS avg_trips_count
    FROM user_trip_counts
)
SELECT
    user_id,
      CONCAT(first_name," ",last_name) as full_name,
    registration_date,
    trips_count,
    ROUND(avg_trips_count, 2) AS avg_trips_count,
    ROUND(trips_count - avg_trips_count, 2) AS trips_vs_avg,
    ROUND(trips_count / avg_trips_count, 2) AS ratio_vs_avg
FROM user_trip_counts
CROSS JOIN avg_trips
ORDER BY trips_count DESC
LIMIT 20;
-- comment:
-- Count valid trips for pre-2024 users, merge user names, exclude outliers,
-- Rank the top 20 users by total trips against the average.


-- Question 6: User segmentation 
-- Classify users into 3 segments based on their total kilometers (total_km):
-- Find which kind of categories you may define. 
-- Detail how and why you choose it like this 
-- Then display each segment and the number of users in each category.
WITH ranked_users AS (
    SELECT
        total_km,
        NTILE(3) OVER (ORDER BY total_km) AS tertile
    FROM users
    WHERE total_km >= 0 and total_km <>1000000
   )
SELECT
    CASE tertile
        WHEN 1 THEN 'Low usage (bottom third)'
        WHEN 2 THEN 'Medium usage (middle third)'
        WHEN 3 THEN 'High usage (top third)'
    END AS km_segment,
    COUNT(*) AS users_count,
    ROUND(MIN(total_km), 2) AS min_km_in_segment,
    ROUND(MAX(total_km), 2) AS max_km_in_segment
FROM ranked_users
GROUP BY tertile
ORDER BY tertile;
-- Comment:
-- 1. Segmentation approach:
-- We use tertiles to divide users into three groups based on total_km, ordered from lowest to highest.
-- This method is chosen because:
-- It avoids arbitrary threshold selection and relies on the data distribution;
-- Each segment contains approximately the same number of users, enabling fair comparison;
-- 2. Segment definition:
-- Low usage    : users in the bottom third of total_km
-- Medium usage : users in the middle third of total_km
-- High usage   : users in the top third of total_km
-- 3. Data cleaning:
-- Exclude negative values of total_km
-- Exclude extreme outliers (total_km = 1,000,000), likely due to data errors or test records


-- Question 7: Data consistency check
-- Identify users whose profile total_km in users.total_km differs 
-- by more than 5% from the sum of their trip distances recorded in trips.km.
-- Exclude NULL (missing) values & Evaluate the volume they represent
WITH trip_km_sum AS (
    SELECT
        user_id,
        SUM(km) AS sum_trip_km
    FROM trips
    WHERE end_datetime > start_datetime
      AND duration_minutes > 0
      AND km > 0
AND km<>2000
    GROUP BY user_id
),
comparison AS (
    SELECT
        u.id AS user_id,
        u.first_name,
        u.last_name,
        u.total_km AS profile_total_km,
        tk.sum_trip_km,
        ABS(u.total_km - tk.sum_trip_km) / tk.sum_trip_km AS rel_diff
    FROM users u
    JOIN trip_km_sum tk ON tk.user_id = u.id
    WHERE u.total_km >= 0 and u.total_km <>1000000

      AND tk.sum_trip_km > 0
)
SELECT
    user_id,
    first_name,
    last_name,
    ROUND(profile_total_km, 2) AS profile_total_km,
    ROUND(sum_trip_km, 2) AS sum_trip_km,
    ROUND(rel_diff * 100, 2) AS rel_diff_pct,
    COUNT(*) OVER () AS flagged_users,
    ROUND(COUNT(*) OVER () * 100.0 / (SELECT COUNT(*) FROM comparison), 2) AS flagged_pct_of_compared,
    ROUND(COUNT(*) OVER () * 100.0 / (SELECT COUNT(*) FROM users WHERE total_km >= 0 and total_km <>1000000), 2) AS flagged_pct_of_all_users
FROM comparison
WHERE rel_diff > 0.05
ORDER BY rel_diff DESC;
-- Comment
-- Aggregate trip distances per user
-- Compare profile total_km with summed trip kilometers
-- Compute the relative difference between the two values


