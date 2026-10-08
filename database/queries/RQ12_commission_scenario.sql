/* (a) If Uber’s commission rate were hypothetically reduced from 25% to 20%, 
how would total driver payouts change across completed trips, assuming all other trip values remain unchanged? */
/* After the query is run, it will show the total completed trips for the Uber platform, the previous total driver payout, 
the new simulated total driver payouts, the payout percentage increase */

SELECT 
    pa.affiliation_name AS platform_affiliation,
    COUNT(th.trip_id) AS total_completed_trips,
    ROUND(SUM(tfb.total_fare_zar), 2) AS total_gross_fare_zar,
    ROUND(SUM(tfb.driver_payout_zar), 2) AS current_driver_payout_zar,
    ROUND(SUM(tfb.driver_payout_zar + (tfb.total_fare_zar * 0.05)), 2) AS simulated_driver_payout_zar,
    ROUND(SUM(tfb.total_fare_zar * 0.05), 2) AS total_driver_payout_increase_zar,
    ROUND((SUM(tfb.total_fare_zar * 0.05) / NULLIF(SUM(tfb.driver_payout_zar), 0)) * 100, 2) AS payout_percentage_increase

FROM TRIP_HEADERS th
JOIN 
    TRIP_FARE_BREAKDOWN tfb ON th.trip_id = tfb.trip_id
JOIN 
    SA_DRIVERS d ON th.driver_id = d.driver_id
JOIN 
    PLATFORM_AFFILIATION pa ON d.affiliation_id = pa.affiliation_id
    
WHERE th.trip_status = 'COMPLETED'
  AND pa.affiliation_name = 'Uber'
GROUP BY pa.affiliation_name;

-- (b) How much platform commission revenue would Uber forego under this scenario?
/* After the query is run, it will show the total completed trips for the Uber platform, 
the total gross fare payout in ZAR, the current platform commision at 25%, 
the simulated commission platform at 20%, the total revenue loss with the new simulated commission,
the commission revenue loss percentage. */

SELECT 
    pa.affiliation_name AS platform_affiliation,
    COUNT(th.trip_id) AS total_completed_trips,
    ROUND(SUM(tfb.total_fare_zar), 2) AS total_gross_fare_zar,
    ROUND(SUM(tfb.platform_commission_zar), 2) AS current_platform_commission_zar, -- Current Baseline Commission (25%)
    ROUND(SUM(tfb.total_fare_zar * 0.20), 2) AS simulated_platform_commission_zar, -- Simulated Commission (20%)
    ROUND(SUM(tfb.total_fare_zar * 0.05), 2) AS uber_revunue_loss_commission_zar, -- Revenue Loss for Uber
    ROUND((SUM(tfb.total_fare_zar * 0.05) / NULLIF(SUM(tfb.platform_commission_zar), 0)) * 100, 2) AS commission_revenue_loss_pct

FROM TRIP_HEADERS th
JOIN 
    TRIP_FARE_BREAKDOWN tfb ON th.trip_id = tfb.trip_id
JOIN
    SA_DRIVERS d ON th.driver_id = d.driver_id
JOIN 
    PLATFORM_AFFILIATION pa ON d.affiliation_id = pa.affiliation_id

WHERE th.trip_status = 'COMPLETED'
  AND pa.affiliation_name = 'Uber'
GROUP BY pa.affiliation_name;

-- (c) How does the impact vary across cities and ride categories?
/* After the query is run, it will show the city name, the ride category, the total completed trips for each city and ride platform,
the gross fare for each city and ride platform, the current driver payout for each city and ride platform at 25%, 
the foregone commission at 20%, the average gain per trip at 20% commission */

SELECT 
    c.city_name,
    th.ride_category,
    COUNT(th.trip_id) AS completed_trips,
    ROUND(SUM(tfb.total_fare_zar), 2) AS gross_fare_zar,
    ROUND(SUM(tfb.driver_payout_zar), 2) AS current_driver_payout_zar,
    ROUND(SUM(tfb.platform_commission_zar), 2) AS current_uber_commission_zar,
    ROUND(SUM(tfb.total_fare_zar * 0.05), 2) AS foregone_commission_driver_gain_zar, -- 5% Shift Metrics
    ROUND(AVG(tfb.total_fare_zar * 0.05), 2) AS avg_gain_per_trip_zar
    
FROM TRIP_HEADERS th
JOIN 
    TRIP_FARE_BREAKDOWN tfb ON th.trip_id = tfb.trip_id
JOIN
    SA_DRIVERS d ON th.driver_id = d.driver_id
JOIN 
    PLATFORM_AFFILIATION pa ON d.affiliation_id = pa.affiliation_id
JOIN 
    PRICING_SURGE_ZONES psz ON th.zone_id = psz.zone_id
JOIN 
    CITIES c ON psz.city_id = c.city_id
    
WHERE th.trip_status = 'COMPLETED'
  AND pa.affiliation_name = 'Uber'

GROUP BY 
    c.city_name,
    th.ride_category

ORDER BY 
    c.city_name ASC, 
    foregone_commission_driver_gain_zar DESC;