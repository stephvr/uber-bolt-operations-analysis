/*
   1. DRIVER PAYOUT BY CITY
*/

SELECT
    c.city_name,
    p.province_name,

    COUNT(*) AS completed_trips,

    COUNT(DISTINCT h.driver_id) AS active_drivers,

    ROUND(AVG(f.driver_payout_zar), 2)
        AS avg_payout_per_trip_zar,

    ROUND(SUM(f.driver_payout_zar), 2)
        AS total_payout_zar,

    ROUND(
        SUM(f.driver_payout_zar)
        / COUNT(DISTINCT h.driver_id),
        2
    ) AS payout_per_driver_zar,

    ROUND(
        100 * SUM(f.driver_payout_zar)
        / SUM(SUM(f.driver_payout_zar)) OVER (),
        2
    ) AS share_of_all_payouts_pct,

    RANK() OVER (
        ORDER BY AVG(f.driver_payout_zar) DESC
    ) AS avg_payout_rank

FROM TRIP_HEADERS h

JOIN TRIP_FARE_BREAKDOWN f
    ON h.trip_id = f.trip_id

JOIN PRICING_SURGE_ZONES z
    ON h.zone_id = z.zone_id

JOIN CITIES c
    ON z.city_id = c.city_id

JOIN PROVINCES p
    ON c.province_id = p.province_id

WHERE h.trip_status = 'COMPLETED'

GROUP BY
    c.city_name,
    p.province_name

ORDER BY
    avg_payout_per_trip_zar DESC;


/*
   2. WHAT IS DIFFERENT BETWEEN THE CITIES

   Compares the zone tariffs, trip length, surge, commission,
   tips and tolls per city. If a factor is about the same in
   every city, it cannot explain the payout differences above.
*/

SELECT
    c.city_name,

    ROUND(AVG(z.base_fare_zar), 2) AS avg_base_fare_zar,
    ROUND(AVG(z.per_km_rate_zar), 2) AS avg_per_km_rate_zar,
    ROUND(AVG(z.per_min_rate_zar), 2) AS avg_per_min_rate_zar,

    ROUND(AVG(f.distance_km), 2) AS avg_distance_km,
    ROUND(AVG(f.duration_minutes), 1) AS avg_duration_min,

    ROUND(
        100 *
        SUM(
            CASE
                WHEN f.surge_multiplier > 1
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS surge_trip_pct,

    ROUND(AVG(f.surge_multiplier), 3)
        AS avg_surge_multiplier,

    ROUND(
        100 * SUM(f.platform_commission_zar)
        / SUM(
            f.total_fare_zar
            - f.tip_zar
            - f.tolls_zar
        ),
        2
    ) AS effective_commission_pct,

    ROUND(AVG(f.tip_zar), 2) AS avg_tip_zar,
    ROUND(AVG(f.tolls_zar), 2) AS avg_tolls_zar

FROM TRIP_HEADERS h

JOIN TRIP_FARE_BREAKDOWN f
    ON h.trip_id = f.trip_id

JOIN PRICING_SURGE_ZONES z
    ON h.zone_id = z.zone_id

JOIN CITIES c
    ON z.city_id = c.city_id

WHERE h.trip_status = 'COMPLETED'

GROUP BY
    c.city_name

ORDER BY
    avg_per_km_rate_zar DESC;


/*
   3. PAYOUT PER TRIP SPLIT INTO ITS PARTS

   Every completed fare follows:
   (base fare + km rate x km + minute rate x minutes) x surge
   + tolls + tip
   (checked in query 5), so the average payout of each city can
   be split into:
       metered fare at the zone's rates
     + extra from surge
     - platform commission
     + tips
     + tolls

   The second half compares each city with the average over all
   completed trips, to show which part causes the difference.
*/

WITH trip_parts AS (
    SELECT
        c.city_name,

        z.base_fare_zar
        + z.per_km_rate_zar * f.distance_km
        + z.per_min_rate_zar * f.duration_minutes
            AS metered_fare,

        (f.total_fare_zar - f.tip_zar - f.tolls_zar)
        - (
            z.base_fare_zar
            + z.per_km_rate_zar * f.distance_km
            + z.per_min_rate_zar * f.duration_minutes
          ) AS surge_extra,

        f.platform_commission_zar AS commission,
        f.tip_zar AS tip,
        f.tolls_zar AS tolls,
        f.driver_payout_zar AS payout

    FROM TRIP_HEADERS h

    JOIN TRIP_FARE_BREAKDOWN f
        ON h.trip_id = f.trip_id

    JOIN PRICING_SURGE_ZONES z
        ON h.zone_id = z.zone_id

    JOIN CITIES c
        ON z.city_id = c.city_id

    WHERE h.trip_status = 'COMPLETED'
),

city_avg AS (
    SELECT
        city_name,
        AVG(metered_fare) AS metered_fare,
        AVG(surge_extra) AS surge_extra,
        AVG(commission) AS commission,
        AVG(tip) AS tip,
        AVG(tolls) AS tolls,
        AVG(payout) AS payout
    FROM trip_parts
    GROUP BY city_name
),

overall_avg AS (
    SELECT
        AVG(metered_fare) AS metered_fare,
        AVG(surge_extra) AS surge_extra,
        AVG(commission) AS commission,
        AVG(tip) AS tip,
        AVG(tolls) AS tolls,
        AVG(payout) AS payout
    FROM trip_parts
)

SELECT
    ca.city_name,

    ROUND(ca.metered_fare, 2) AS metered_fare_zar,
    ROUND(ca.surge_extra, 2) AS surge_extra_zar,
    ROUND(-ca.commission, 2) AS commission_zar,
    ROUND(ca.tip, 2) AS tip_zar,
    ROUND(ca.tolls, 2) AS tolls_zar,
    ROUND(ca.payout, 2) AS avg_payout_zar,

    ROUND(ca.payout - oa.payout, 2)
        AS diff_from_overall_zar,

    ROUND(ca.metered_fare - oa.metered_fare, 2)
        AS diff_metered_fare,

    ROUND(ca.surge_extra - oa.surge_extra, 2)
        AS diff_surge,

    ROUND(-(ca.commission - oa.commission), 2)
        AS diff_commission,

    ROUND(
        (ca.tip - oa.tip) + (ca.tolls - oa.tolls),
        2
    ) AS diff_tips_tolls

FROM city_avg ca

CROSS JOIN overall_avg oa

ORDER BY
    ca.payout DESC;


/*
   4. SAME TRIP IN EVERY CITY AND ON EVERY PLATFORM

   Prices the average completed trip (average km and minutes
   over all cities) at each zone's rates, with no surge, tip or
   tolls, and works out what the driver keeps on each platform.
   This shows the effect of the zone rates and the commission
   rate on their own.
*/

WITH typical_trip AS (
    SELECT
        AVG(f.distance_km) AS km,
        AVG(f.duration_minutes) AS minutes
    FROM TRIP_HEADERS h
    JOIN TRIP_FARE_BREAKDOWN f
        ON h.trip_id = f.trip_id
    WHERE h.trip_status = 'COMPLETED'
),

zone_fare AS (
    SELECT
        c.city_name,
        z.zone_name,
        z.base_fare_zar
        + z.per_km_rate_zar * t.km
        + z.per_min_rate_zar * t.minutes AS fare
    FROM PRICING_SURGE_ZONES z
    JOIN CITIES c
        ON z.city_id = c.city_id
    CROSS JOIN typical_trip t
)

SELECT
    zf.city_name,
    zf.zone_name,

    ROUND(zf.fare, 2) AS fare_zar,

    ROUND(
        MAX(CASE WHEN pa.affiliation_name = 'Bolt'
                 THEN zf.fare * (1 - pa.commission_pct) END),
        2
    ) AS bolt_driver_gets_zar,

    ROUND(
        MAX(CASE WHEN pa.affiliation_name = 'Dual-Platform (Both)'
                 THEN zf.fare * (1 - pa.commission_pct) END),
        2
    ) AS dual_driver_gets_zar,

    ROUND(
        MAX(CASE WHEN pa.affiliation_name = 'Uber'
                 THEN zf.fare * (1 - pa.commission_pct) END),
        2
    ) AS uber_driver_gets_zar,

    ROUND(
        MAX(zf.fare * (1 - pa.commission_pct))
        - MIN(zf.fare * (1 - pa.commission_pct)),
        2
    ) AS platform_gap_zar

FROM zone_fare zf

CROSS JOIN PLATFORM_AFFILIATION pa

GROUP BY
    zf.city_name,
    zf.zone_name,
    zf.fare

ORDER BY
    fare_zar DESC;


/*
   5. VALIDATE THE FARE FORMULA USED IN QUERY 3

   total fare - tip - tolls should equal
   (base fare + km rate x km + minute rate x minutes) x surge
*/

SELECT
    COUNT(*) AS completed_trips,

    SUM(
        CASE
            WHEN ABS(
                (f.total_fare_zar - f.tip_zar - f.tolls_zar)
                -
                (
                    z.base_fare_zar
                    + z.per_km_rate_zar * f.distance_km
                    + z.per_min_rate_zar * f.duration_minutes
                ) * f.surge_multiplier
            ) <= 0.01
            THEN 1
            ELSE 0
        END
    ) AS matching_fare_rows,

    SUM(
        CASE
            WHEN ABS(
                (f.total_fare_zar - f.tip_zar - f.tolls_zar)
                -
                (
                    z.base_fare_zar
                    + z.per_km_rate_zar * f.distance_km
                    + z.per_min_rate_zar * f.duration_minutes
                ) * f.surge_multiplier
            ) > 0.01
            THEN 1
            ELSE 0
        END
    ) AS non_matching_fare_rows

FROM TRIP_HEADERS h

JOIN TRIP_FARE_BREAKDOWN f
    ON h.trip_id = f.trip_id

JOIN PRICING_SURGE_ZONES z
    ON h.zone_id = z.zone_id

WHERE h.trip_status = 'COMPLETED';
