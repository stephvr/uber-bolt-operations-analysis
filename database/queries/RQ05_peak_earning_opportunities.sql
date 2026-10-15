-- QUERY 1: Earning Opportunities by City, Day of Week, and Time Period (Shift)
-- Purpose: Aggregates trip volume, surge frequency, average surge, and total 
--          driver payout across cities, days of the week, and operational shifts.
-- Techniques: 4-table inner join, TO_CHAR for date parts, CASE for shift 
--             categorization and surge frequency, GROUP BY aggregation.
-- ==============================================================================

SELECT 
    c.city_name,
    TO_CHAR(h.request_timestamp, 'Dy') AS day_of_week,
    CASE 
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 7 AND 9 THEN '07:00-09:59 (Morning Peak)'
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 10 AND 15 THEN '10:00-15:59 (Midday Off-Peak)'
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 16 AND 18 THEN '16:00-18:59 (Afternoon Peak)'
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 19 AND 21 THEN '19:00-21:59 (Evening)'
        ELSE '22:00-06:59 (Late Night / Early Morning)'
    END AS operating_period,
    COUNT(*) AS completed_trips,
    SUM(CASE WHEN f.surge_multiplier > 1.0 THEN 1 ELSE 0 END) AS surge_trips,
    ROUND(100.0 * SUM(CASE WHEN f.surge_multiplier > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS surge_frequency_pct,
    ROUND(AVG(f.surge_multiplier), 3) AS avg_surge_multiplier,
    ROUND(AVG(f.driver_payout_zar), 2) AS avg_driver_payout_zar,
    ROUND(SUM(f.driver_payout_zar), 2) AS total_driver_payout_zar
FROM TRIP_HEADERS h
JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
JOIN PRICING_SURGE_ZONES z ON h.zone_id = z.zone_id
JOIN CITIES c ON z.city_id = c.city_id
WHERE h.trip_status = 'COMPLETED'
GROUP BY 
    c.city_name,
    TO_CHAR(h.request_timestamp, 'Dy'),
    TO_CHAR(h.request_timestamp, 'D'),
    CASE 
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 7 AND 9 THEN '07:00-09:59 (Morning Peak)'
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 10 AND 15 THEN '10:00-15:59 (Midday Off-Peak)'
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 16 AND 18 THEN '16:00-18:59 (Afternoon Peak)'
        WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 19 AND 21 THEN '19:00-21:59 (Evening)'
        ELSE '22:00-06:59 (Late Night / Early Morning)'
    END
ORDER BY total_driver_payout_zar DESC;


-- ==============================================================================
-- QUERY 2: Top 15 Highest-Earning Time Windows Across South African Cities
-- Purpose: Ranks specific city-day-hour combinations to identify exact high-yield 
--          earning hotspots for drivers.
-- Techniques: Common Table Expressions (CTE), Window Function RANK() OVER,
--             Filtering top 15 ranks.
-- ==============================================================================

WITH CityTimeSlotEarnings AS (
    SELECT 
        c.city_name,
        TO_CHAR(h.request_timestamp, 'FMDay') AS full_day_name,
        TO_CHAR(h.request_timestamp, 'HH24') || ':00 - ' || 
        TO_CHAR(TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) + 1, 'FM00') || ':00' AS hourly_window,
        COUNT(*) AS completed_trips,
        ROUND(100.0 * SUM(CASE WHEN f.surge_multiplier > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS surge_frequency_pct,
        ROUND(AVG(f.surge_multiplier), 2) AS avg_surge,
        ROUND(AVG(f.driver_payout_zar), 2) AS avg_payout_per_trip_zar,
        ROUND(SUM(f.driver_payout_zar), 2) AS total_payout_zar
    FROM TRIP_HEADERS h
    JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
    JOIN PRICING_SURGE_ZONES z ON h.zone_id = z.zone_id
    JOIN CITIES c ON z.city_id = c.city_id
    WHERE h.trip_status = 'COMPLETED'
    GROUP BY 
        c.city_name,
        TO_CHAR(h.request_timestamp, 'FMDay'),
        TO_CHAR(h.request_timestamp, 'HH24')
)
SELECT 
    city_name,
    full_day_name,
    hourly_window,
    completed_trips,
    surge_frequency_pct,
    avg_surge,
    avg_payout_per_trip_zar,
    total_payout_zar,
    RANK() OVER (ORDER BY total_payout_zar DESC) AS earning_opportunity_rank
FROM CityTimeSlotEarnings
ORDER BY earning_opportunity_rank
FETCH FIRST 15 ROWS ONLY;


-- ==============================================================================
-- QUERY 3: Weekday vs Weekend Peak/Off-Peak Comparative Analysis by City
-- Purpose: Compares peak operating hours against off-peak operating hours across
--          weekdays and weekends to measure surge dependency and earning premium.
-- Techniques: Multi-level CASE logic, CTEs, ratio calculations.
-- ==============================================================================

WITH ShiftPerformance AS (
    SELECT 
        c.city_name,
        CASE 
            WHEN TO_CHAR(h.request_timestamp, 'Dy') IN ('Sat', 'Sun') THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type,
        CASE 
            WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 7 AND 9 OR 
                 TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 16 AND 18 THEN 'Peak Hours'
            ELSE 'Off-Peak Hours'
        END AS peak_status,
        COUNT(*) AS completed_trips,
        SUM(CASE WHEN f.surge_multiplier > 1.0 THEN 1 ELSE 0 END) AS surge_trips,
        SUM(f.driver_payout_zar) AS total_payout,
        AVG(f.driver_payout_zar) AS avg_payout,
        AVG(f.surge_multiplier) AS avg_surge
    FROM TRIP_HEADERS h
    JOIN TRIP_FARE_BREAKDOWN f ON h.trip_id = f.trip_id
    JOIN PRICING_SURGE_ZONES z ON h.zone_id = z.zone_id
    JOIN CITIES c ON z.city_id = c.city_id
    WHERE h.trip_status = 'COMPLETED'
    GROUP BY 
        c.city_name,
        CASE 
            WHEN TO_CHAR(h.request_timestamp, 'Dy') IN ('Sat', 'Sun') THEN 'Weekend'
            ELSE 'Weekday'
        END,
        CASE 
            WHEN TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 7 AND 9 OR 
                 TO_NUMBER(TO_CHAR(h.request_timestamp, 'HH24')) BETWEEN 16 AND 18 THEN 'Peak Hours'
            ELSE 'Off-Peak Hours'
        END
)
SELECT 
    city_name,
    day_type,
    peak_status,
    completed_trips,
    ROUND(100.0 * surge_trips / completed_trips, 2) AS surge_frequency_pct,
    ROUND(avg_surge, 3) AS avg_surge_multiplier,
    ROUND(avg_payout, 2) AS avg_payout_per_trip_zar,
    ROUND(total_payout, 2) AS total_driver_payout_zar,
    ROUND(100.0 * total_payout / SUM(total_payout) OVER (PARTITION BY city_name), 2) AS city_payout_share_pct
FROM ShiftPerformance
ORDER BY city_name, day_type DESC, peak_status DESC;