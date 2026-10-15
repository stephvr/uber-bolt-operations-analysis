/*Query 1 – Overall Profitability by Ride Category
  Measures completed trips, driver payout totals, average payouts,
  and average payouts per km/minute across all four ride categories. 
  Techniques: 2-table join, GROUP BY, aggregate functions (SUM, AVG, ROUND).
*/
SELECT 
    h.ride_category,
    COUNT(*) AS completed_trips,
    ROUND(SUM(f.driver_payout_zar), 2) AS total_driver_payout_zar,
    ROUND(AVG(f.driver_payout_zar), 2) AS avg_driver_payout_zar,
    ROUND(AVG(f.driver_payout_zar / NULLIF(f.distance_km, 0)), 2) AS avg_payout_per_km_zar,
    ROUND(AVG(f.driver_payout_zar / NULLIF(f.duration_minutes, 0)), 2) AS avg_payout_per_min_zar
FROM TRIP_HEADERS h
JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
WHERE h.trip_status = 'COMPLETED'
GROUP BY h.ride_category
ORDER BY avg_driver_payout_zar DESC;

/*Query 2 – Category Profitability Comparison Across Cities
  Evaluates how category-level earnings shift across different city pricing zones. 
  Techniques: 4-table join, GROUP BY, conditional aggregation (CASE statements for cross-tabulation/pivot).
*/
SELECT 
    c.city_name,
    ROUND(AVG(CASE WHEN h.ride_category = 'Budget (Uber Go/Bolt Go)' THEN f.driver_payout_zar END), 2) AS budget_avg_payout_zar,
    ROUND(AVG(CASE WHEN h.ride_category = 'Standard (UberX/Bolt)' THEN f.driver_payout_zar END), 2) AS standard_avg_payout_zar,
    ROUND(AVG(CASE WHEN h.ride_category = 'Comfort (Uber Comfort)' THEN f.driver_payout_zar END), 2) AS comfort_avg_payout_zar,
    ROUND(AVG(CASE WHEN h.ride_category = 'Large Capacity (UberXL/Bolt XL)' THEN f.driver_payout_zar END), 2) AS xl_avg_payout_zar,
    ROUND(
        AVG(CASE WHEN h.ride_category = 'Large Capacity (UberXL/Bolt XL)' THEN f.driver_payout_zar END) - 
        AVG(CASE WHEN h.ride_category = 'Budget (Uber Go/Bolt Go)' THEN f.driver_payout_zar END), 2
    ) AS xl_vs_budget_premium_zar
FROM TRIP_HEADERS h
JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
JOIN PRICING_SURGE_ZONES z ON h.zone_id = z.zone_id
JOIN CITIES c ON z.city_id = c.city_id
WHERE h.trip_status = 'COMPLETED'
GROUP BY c.city_name
ORDER BY xl_avg_payout_zar DESC;

/*Query 3 – Relative Earnings Multiplier (Category vs Base/Budget Tier)
Compares the relative earning multiplier of higher-tier ride categories against the baseline Budget category across completed trips. 
Techniques: CTEs (WITH), ratio calculations.
*/
WITH CategoryPayouts AS (
    SELECT 
        h.ride_category,
        AVG(f.driver_payout_zar) AS avg_payout
    FROM TRIP_HEADERS h
    JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
    WHERE h.trip_status = 'COMPLETED'
    GROUP BY h.ride_category
),
BasePayout AS (
    SELECT avg_payout AS budget_payout
    FROM CategoryPayouts
    WHERE ride_category = 'Budget (Uber Go/Bolt Go)'
)
SELECT 
    cp.ride_category,
    ROUND(cp.avg_payout, 2) AS avg_payout_zar,
    ROUND(cp.avg_payout - bp.budget_payout, 2) AS premium_over_budget_zar,
    ROUND(cp.avg_payout / bp.budget_payout, 2) AS earning_multiplier_vs_budget
FROM CategoryPayouts cp
CROSS JOIN BasePayout bp
ORDER BY cp.avg_payout DESC;