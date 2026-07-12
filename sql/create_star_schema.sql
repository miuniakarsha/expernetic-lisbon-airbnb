-- ============================================
-- Expernetic Data Engineer Assessment
-- Lisbon Airbnb Star Schema
-- SQL Server Management Studio
-- ============================================

-- Create database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'AirbnbLisbon')
BEGIN
    CREATE DATABASE AirbnbLisbon;
END
GO

USE AirbnbLisbon;
GO

-- ============================================
-- Dimension: Neighbourhood
-- ============================================
DROP TABLE IF EXISTS dim_neighbourhood;
CREATE TABLE dim_neighbourhood (
    neighbourhood_key INT IDENTITY(1,1) PRIMARY KEY,
    neighbourhood_group VARCHAR(100),
    neighbourhood VARCHAR(100) NOT NULL,
    CONSTRAINT uk_neighbourhood UNIQUE (neighbourhood_group, neighbourhood)
);

-- ============================================
-- Dimension: Host
-- ============================================
DROP TABLE IF EXISTS dim_host;
CREATE TABLE dim_host (
    host_key INT IDENTITY(1,1) PRIMARY KEY,
    host_id BIGINT NOT NULL,
    host_name NVARCHAR(200),
    host_tenure_years DECIMAL(5,2),
    is_superhost CHAR(1),
    host_total_listings INT,
    CONSTRAINT uk_host UNIQUE (host_id)
);

-- ============================================
-- Dimension: Listing
-- ============================================
DROP TABLE IF EXISTS dim_listing;
CREATE TABLE dim_listing (
    listing_key INT IDENTITY(1,1) PRIMARY KEY,
    listing_id INT NOT NULL,
    listing_name NVARCHAR(500),
    property_type VARCHAR(100),
    room_type VARCHAR(50),
    accommodates INT,
    bedrooms DECIMAL(5,2),
    bathrooms DECIMAL(5,2),
    min_nights INT,
    max_nights INT,
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    neighbourhood VARCHAR(100),
    neighbourhood_group VARCHAR(100),
    CONSTRAINT uk_listing UNIQUE (listing_id)
);

-- ============================================
-- Fact: Listing Performance
-- ============================================
DROP TABLE IF EXISTS fact_performance;
CREATE TABLE fact_performance (
    performance_key INT IDENTITY(1,1) PRIMARY KEY,
    listing_key INT NOT NULL,
    host_key INT NOT NULL,
    neighbourhood_key INT NOT NULL,
    price DECIMAL(10,2),
    price_per_bedroom DECIMAL(10,2),
    availability_365 INT,
    occupancy_rate DECIMAL(5,2),
    estimated_revenue DECIMAL(12,2),
    review_count INT,
    review_score DECIMAL(3,2),
    first_review_date DATE,
    last_review_date DATE,
    -- Foreign Keys
    CONSTRAINT fk_perf_listing FOREIGN KEY (listing_key) REFERENCES dim_listing(listing_key),
    CONSTRAINT fk_perf_host FOREIGN KEY (host_key) REFERENCES dim_host(host_key),
    CONSTRAINT fk_perf_neighbourhood FOREIGN KEY (neighbourhood_key) REFERENCES dim_neighbourhood(neighbourhood_key)
);

-- ============================================
-- Create Indexes for Performance
-- ============================================
CREATE INDEX idx_perf_price ON fact_performance(price);
CREATE INDEX idx_perf_occupancy ON fact_performance(occupancy_rate);
CREATE INDEX idx_perf_revenue ON fact_performance(estimated_revenue);
CREATE INDEX idx_listing_neighbourhood ON dim_listing(neighbourhood);

-- ============================================
-- Key Analytical Queries
-- ============================================

-- Q1: Top 10 neighbourhoods by average price
GO
CREATE OR ALTER VIEW vw_top_neighbourhoods AS
SELECT TOP 10
    n.neighbourhood,
    COUNT(DISTINCT l.listing_id) as listing_count,
    AVG(f.price) as avg_price,
    AVG(f.occupancy_rate) as avg_occupancy,
    SUM(f.estimated_revenue) as total_revenue
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
JOIN dim_neighbourhood n ON f.neighbourhood_key = n.neighbourhood_key
GROUP BY n.neighbourhood
ORDER BY avg_price DESC;
GO

-- Q2: Superhost vs Non-Superhost performance
GO
CREATE OR ALTER VIEW vw_superhost_comparison AS
SELECT 
    h.is_superhost,
    COUNT(DISTINCT l.listing_id) as listing_count,
    AVG(f.price) as avg_price,
    AVG(f.occupancy_rate) as avg_occupancy,
    AVG(f.review_score) as avg_review_score,
    AVG(f.estimated_revenue) as avg_revenue
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
JOIN dim_host h ON f.host_key = h.host_key
GROUP BY h.is_superhost;
GO

-- Q3: Price distribution by room type 
GO
CREATE OR ALTER VIEW vw_price_by_room_type AS
WITH price_with_rank AS (
    SELECT 
        l.room_type,
        f.price,
        ROW_NUMBER() OVER (PARTITION BY l.room_type ORDER BY f.price) as row_num,
        COUNT(*) OVER (PARTITION BY l.room_type) as total_count
    FROM fact_performance f
    JOIN dim_listing l ON f.listing_key = l.listing_key
    WHERE f.price IS NOT NULL
)
SELECT 
    room_type,
    COUNT(*) as count,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    -- Calculate median using row number
    AVG(CASE 
        WHEN row_num IN ((total_count + 1) / 2, (total_count + 2) / 2) 
        THEN price 
        ELSE NULL 
    END) as median_price
FROM price_with_rank
GROUP BY room_type;
GO

-- Alternative simpler version without median (for compatibility)
GO
CREATE OR ALTER VIEW vw_price_by_room_type_simple AS
SELECT 
    l.room_type,
    COUNT(*) as count,
    AVG(f.price) as avg_price,
    MIN(f.price) as min_price,
    MAX(f.price) as max_price,
    STDEV(f.price) as std_dev_price
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
WHERE f.price IS NOT NULL
GROUP BY l.room_type;
GO

-- Q4: Host concentration (Pareto analysis) - FIXED
GO
CREATE OR ALTER VIEW vw_host_concentration AS
SELECT 
    h.host_id,
    h.host_name,
    COUNT(l.listing_id) as listing_count,
    SUM(f.estimated_revenue) as total_revenue,
    RANK() OVER (ORDER BY COUNT(l.listing_id) DESC) as host_rank
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
JOIN dim_host h ON f.host_key = h.host_key
GROUP BY h.host_id, h.host_name;
GO

-- Q5: Occupancy analysis
GO
CREATE OR ALTER VIEW vw_occupancy_analysis AS
SELECT 
    l.room_type,
    AVG(f.occupancy_rate) as avg_occupancy,
    COUNT(CASE WHEN f.occupancy_rate > 0.8 THEN 1 END) as high_occupancy_count,
    AVG(f.price) as avg_price,
    COUNT(*) as total_listings,
    CAST(COUNT(CASE WHEN f.occupancy_rate > 0.8 THEN 1 END) AS FLOAT) / COUNT(*) * 100 as pct_high_occupancy
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
WHERE f.occupancy_rate IS NOT NULL
GROUP BY l.room_type;
GO

-- Q6: Price distribution by neighbourhood 
GO
CREATE OR ALTER VIEW vw_price_by_neighbourhood AS
SELECT TOP 20
    n.neighbourhood,
    COUNT(*) as listing_count,
    AVG(f.price) as avg_price,
    MIN(f.price) as min_price,
    MAX(f.price) as max_price,
    AVG(f.occupancy_rate) as avg_occupancy,
    AVG(f.review_score) as avg_review_score
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
JOIN dim_neighbourhood n ON f.neighbourhood_key = n.neighbourhood_key
WHERE f.price IS NOT NULL
GROUP BY n.neighbourhood
HAVING COUNT(*) >= 10  -- Only neighbourhoods with at least 10 listings
ORDER BY avg_price DESC;
GO

-- Q7: Monthly revenue trend 
GO
CREATE OR ALTER VIEW vw_occupancy_trend AS
SELECT 
    l.room_type,
    AVG(f.occupancy_rate) as avg_occupancy,
    AVG(f.price) as avg_price,
    AVG(f.estimated_revenue) as avg_revenue
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
GROUP BY l.room_type;
GO

-- ============================================
-- Test Queries 
-- ============================================

-- Test Q1
SELECT * FROM vw_top_neighbourhoods;
GO

-- Test Q2
SELECT * FROM vw_superhost_comparison;
GO

-- Test Q3
SELECT * FROM vw_price_by_room_type;
GO

-- Test Q4
SELECT TOP 10 * FROM vw_host_concentration;
GO

-- Test Q5
SELECT * FROM vw_occupancy_analysis;
GO

-- Test Q6
SELECT * FROM vw_price_by_neighbourhood;
GO

-- ============================================
-- Business Intelligence Queries
-- ============================================

-- 1. Market Summary
GO
CREATE OR ALTER VIEW vw_market_summary AS
SELECT
    COUNT(DISTINCT l.listing_id) as total_listings,
    COUNT(DISTINCT h.host_id) as total_hosts,
    AVG(f.price) as avg_price,
    AVG(f.occupancy_rate) as avg_occupancy,
    AVG(f.review_score) as avg_review_score,
    SUM(f.estimated_revenue) as total_market_revenue,
    AVG(f.estimated_revenue) as avg_listing_revenue
FROM fact_performance f
JOIN dim_listing l ON f.listing_key = l.listing_key
JOIN dim_host h ON f.host_key = h.host_key;
GO

-- 2. Price segments 
GO
CREATE OR ALTER VIEW vw_price_segments AS
SELECT
    CASE 
        WHEN f.price < 50 THEN 'Budget (<$50)'
        WHEN f.price < 100 THEN 'Economy ($50-$100)'
        WHEN f.price < 200 THEN 'Mid-Range ($100-$200)'
        WHEN f.price < 300 THEN 'Premium ($200-$300)'
        ELSE 'Luxury ($300+)'
    END as price_segment,
    COUNT(*) as listing_count,
    AVG(f.occupancy_rate) as avg_occupancy,
    AVG(f.review_score) as avg_review_score,
    AVG(f.estimated_revenue) as avg_revenue,
    -- Add sorting order as a column
    CASE 
        WHEN f.price < 50 THEN 1
        WHEN f.price < 100 THEN 2
        WHEN f.price < 200 THEN 3
        WHEN f.price < 300 THEN 4
        ELSE 5
    END as sort_order
FROM fact_performance f
WHERE f.price IS NOT NULL
GROUP BY 
    CASE 
        WHEN f.price < 50 THEN 'Budget (<$50)'
        WHEN f.price < 100 THEN 'Economy ($50-$100)'
        WHEN f.price < 200 THEN 'Mid-Range ($100-$200)'
        WHEN f.price < 300 THEN 'Premium ($200-$300)'
        ELSE 'Luxury ($300+)'
    END,
    CASE 
        WHEN f.price < 50 THEN 1
        WHEN f.price < 100 THEN 2
        WHEN f.price < 200 THEN 3
        WHEN f.price < 300 THEN 4
        ELSE 5
    END;
GO

