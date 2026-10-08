-- (a) Between the platforms, which provides the best payout per km?
/* After the query is run, it will show the 3 platforms with a total number of completed trips per platform, 
total payouts in ZAR, total kilometers per platform, then the average payout per kilometer per platform */

SELECT 
    pa.affiliation_name AS platform_affiliation,
    COUNT(th.trip_id) AS total_completed_trips,
    ROUND(SUM(tfb.driver_payout_zar), 2) AS total_driver_payout_zar,
    ROUND(SUM(tfb.distance_km), 2) AS total_distance_km,
    ROUND(SUM(tfb.driver_payout_zar) / NULLIF(SUM(tfb.distance_km), 0), 2) AS earnings_per_km_zar

FROM TRIP_HEADERS th
JOIN 
    TRIP_FARE_BREAKDOWN tfb ON th.trip_id = tfb.trip_id
JOIN
    SA_DRIVERS d ON th.driver_id = d.driver_id
JOIN
    PLATFORM_AFFILIATION pa ON d.affiliation_id = pa.affiliation_id
    
WHERE th.trip_status = 'COMPLETED'
GROUP BY pa.affiliation_name
ORDER BY earnings_per_km_zar DESC;

-- (b) Does surge pricing have an influence on the earnings per kilometer uniformly across all platforms?
/* After the query is run, it will show the surge payout per kilometer per platform in ZAR, 
the no surge payout per kilometer per platform, the uplift amount per kilometer per platform,
the uplift percentage per platform showing how much more is earned when a driver is accepting rides in a surge zone. */

SELECT platform,
       surge_payout_per_km,
       no_surge_payout_per_km,
       ROUND(surge_payout_per_km - no_surge_payout_per_km, 2) AS uplift_zar_per_km,
       ROUND((surge_payout_per_km - no_surge_payout_per_km)/ no_surge_payout_per_km * 100, 1) AS uplift_pct

FROM (
      SELECT pa.affiliation_name AS platform,
            ROUND(SUM(CASE WHEN f.surge_multiplier > 1.0 THEN f.driver_payout_zar END)
                 / SUM(CASE WHEN f.surge_multiplier > 1.0 THEN f.distance_km END), 2) AS surge_payout_per_km,
            ROUND(SUM(CASE WHEN f.surge_multiplier = 1.0 THEN f.driver_payout_zar END)
                 / SUM(CASE WHEN f.surge_multiplier = 1.0 THEN f.distance_km END), 2) AS no_surge_payout_per_km
      FROM trip_headers t
            JOIN 
                trip_fare_breakdown f ON t.trip_id = f.trip_id
            JOIN 
                sa_drivers d ON t.driver_id = d.driver_id
            JOIN 
                platform_affiliation pa ON d.affiliation_id = pa.affiliation_id

      WHERE t.trip_status = 'COMPLETED'
      AND f.distance_km > 0
      GROUP BY pa.affiliation_name
     ) sub     
ORDER BY uplift_pct DESC;