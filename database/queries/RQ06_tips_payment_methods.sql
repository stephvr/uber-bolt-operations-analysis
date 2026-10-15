/*Query 1 – Tipping Behavior by Payment Method
  Analyzes tip frequency, average tip size, total tips, 
  and the proportion of driver payout derived from tips across payment channels. 
  Techniques: 3-table join (TRIP_HEADERS, TRIP_FARE_BREAKDOWN, SA_DRIVERS), 
  GROUP BY, conditional aggregation using CASE, and ROUND().
 */
SELECT 
    f.payment_method,
    COUNT(*) AS completed_trips,
    SUM(CASE WHEN f.tip_zar > 0 THEN 1 ELSE 0 END) AS tipped_trips,
    ROUND(100.0 * SUM(CASE WHEN f.tip_zar > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS tip_frequency_pct,
    ROUND(AVG(f.tip_zar), 2) AS avg_tip_overall_zar,
    ROUND(AVG(CASE WHEN f.tip_zar > 0 THEN f.tip_zar END), 2) AS avg_tip_when_tipped_zar,
    ROUND(SUM(f.tip_zar), 2) AS total_tips_zar,
    ROUND(SUM(f.driver_payout_zar), 2) AS total_driver_payout_zar,
    ROUND(100.0 * SUM(f.tip_zar) / SUM(f.driver_payout_zar), 2) AS tip_share_of_payout_pct
FROM TRIP_HEADERS h
JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
WHERE h.trip_status = 'COMPLETED'
GROUP BY f.payment_method
ORDER BY tip_frequency_pct DESC;

/*Query 2 - Tipping Behavior by Ride Category and City
  Examines how tip frequency and average tipping amounts vary across vehicle tiers and South African geographic regions. 
  Techniques: 4-table join (TRIP_HEADERS, TRIP_FARE_BREAKDOWN, PRICING_SURGE_ZONES, CITIES), 
  GROUP BY, conditional aggregation.
 */
SELECT 
    c.city_name,
    h.ride_category,
    COUNT(*) AS completed_trips,
    ROUND(100.0 * SUM(CASE WHEN f.tip_zar > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS tip_frequency_pct,
    ROUND(AVG(f.tip_zar), 2) AS avg_tip_zar,
    ROUND(AVG(f.driver_payout_zar), 2) AS avg_payout_zar,
    ROUND(100.0 * SUM(f.tip_zar) / SUM(f.driver_payout_zar), 2) AS tip_share_of_payout_pct
FROM TRIP_HEADERS h
JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
JOIN PRICING_SURGE_ZONES z ON h.zone_id = z.zone_id
JOIN CITIES c ON z.city_id = c.city_id
WHERE h.trip_status = 'COMPLETED'
GROUP BY c.city_name, h.ride_category
ORDER BY c.city_name, avg_tip_zar DESC;

/*Query 3 – Significance of Tips in Total Driver Payout Structure
  Ranks tipping contribution relative to metered fares and surge pricing. 
  Techniques: CTEs (WITH), window function (RANK()).
 */
WITH PayoutComponents AS (
    SELECT 
        h.ride_category,
        SUM(f.driver_payout_zar) AS total_payout,
        SUM(f.tip_zar) AS total_tips,
        SUM(f.tolls_zar) AS total_tolls,
        SUM(f.total_fare_zar - f.tip_zar - f.tolls_zar) AS total_fare_less_extras
    FROM TRIP_HEADERS h
    JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
    WHERE h.trip_status = 'COMPLETED'
    GROUP BY h.ride_category
)
SELECT 
    ride_category,
    ROUND(total_payout, 2) AS total_payout_zar,
    ROUND(total_tips, 2) AS total_tips_zar,
    ROUND(100.0 * total_tips / total_payout, 2) AS tip_pct_of_payout,
    RANK() OVER (ORDER BY (100.0 * total_tips / total_payout) DESC) AS tip_dependency_rank
FROM PayoutComponents
ORDER BY tip_dependency_rank;