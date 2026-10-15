

/*
   REFERENCE TABLES
*/

CREATE TABLE PROVINCES (
    province_id NUMBER NOT NULL,
    province_name VARCHAR2(20) NOT NULL
);

CREATE TABLE CITIES (
    city_id NUMBER NOT NULL,
    province_id NUMBER NOT NULL,
    city_name VARCHAR2(20) NOT NULL
);

CREATE TABLE PLATFORM_AFFILIATION (
    affiliation_id NUMBER NOT NULL,
    affiliation_name VARCHAR2(20) NOT NULL,
    commission_pct NUMBER(3,2) NOT NULL
);


/*
   CORE / SUPPORTING TABLES
*/

CREATE TABLE SA_DRIVERS (
    driver_id VARCHAR2(9) NOT NULL,
    affiliation_id NUMBER NOT NULL,
    city_id NUMBER NOT NULL,
    first_name VARCHAR2(20) NOT NULL,
    last_name VARCHAR2(20) NOT NULL,
    driver_rating NUMBER(3,2) NOT NULL,
    total_lifetime_trips NUMBER(6) NOT NULL,
    onboarding_date DATE NOT NULL
);

CREATE TABLE SA_RIDERS (
    rider_id VARCHAR2(12) NOT NULL,
    city_id NUMBER NOT NULL,
    first_name VARCHAR2(20) NOT NULL,
    last_name VARCHAR2(20) NOT NULL,
    mobile_number VARCHAR2(11) NOT NULL,
    preferred_payment VARCHAR2(13) NOT NULL,
    account_created_date DATE NOT NULL
);

CREATE TABLE PRICING_SURGE_ZONES (
    zone_id VARCHAR2(21) NOT NULL,
    city_id NUMBER NOT NULL,
    zone_name VARCHAR2(40) NOT NULL,
    base_fare_zar NUMBER(6,2) NOT NULL,
    per_km_rate_zar NUMBER(6,2) NOT NULL,
    per_min_rate_zar NUMBER(4,2) NOT NULL
);

CREATE TABLE VEHICLES (
    vehicle_id VARCHAR2(9) NOT NULL,
    driver_id VARCHAR2(9) NOT NULL,
    make VARCHAR2(10) NOT NULL,
    model VARCHAR2(13) NOT NULL,
    year NUMBER(4) NOT NULL,
    license_plate VARCHAR2(11) NOT NULL,
    category_type VARCHAR2(31) NOT NULL
);

CREATE TABLE TRIP_HEADERS (
    trip_id VARCHAR2(17) NOT NULL,
    driver_id VARCHAR2(9) NOT NULL,
    rider_id VARCHAR2(12) NOT NULL,
    zone_id VARCHAR2(21) NOT NULL,
    ride_category VARCHAR2(31) NOT NULL,
    request_timestamp TIMESTAMP NOT NULL,
    trip_status VARCHAR2(19) NOT NULL,
    cancellation_reason VARCHAR2(14)
);

CREATE TABLE TRIP_FARE_BREAKDOWN (
    trip_id VARCHAR2(17) NOT NULL,
    distance_km NUMBER(5,2) NOT NULL,
    duration_minutes NUMBER(3) NOT NULL,
    surge_multiplier NUMBER(2,1) NOT NULL,
    base_fare_zar NUMBER(6,2) NOT NULL,
    tolls_zar NUMBER(6,2) NOT NULL,
    tip_zar NUMBER(6,2) NOT NULL,
    total_fare_zar NUMBER(10,2) NOT NULL,
    platform_commission_zar NUMBER(10,2) NOT NULL,
    driver_payout_zar NUMBER(10,2) NOT NULL,
    payment_method VARCHAR2(13) NOT NULL
);

CREATE TABLE TRIP_REVIEWS (
    review_id VARCHAR2(11) NOT NULL,
    trip_id VARCHAR2(17) NOT NULL,
    rider_rating_of_driver NUMBER(1) NOT NULL,
    driver_rating_of_rider NUMBER(1) NOT NULL,
    feedback_comment VARCHAR2(100)
);