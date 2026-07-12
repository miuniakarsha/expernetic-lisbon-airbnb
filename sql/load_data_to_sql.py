# sql/load_data_to_sql.py
# Load enriched data into SQL Server

import pandas as pd
import pyodbc
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

print("="*60)
print("LOADING DATA TO SQL SERVER")
print("="*60)

# ============================================
# 1. CONNECTION SETUP
# ============================================
print("\n[1] Setting up connection...")

# Connection string - UPDATE THIS WITH YOUR SERVER INFO
conn_str = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost\\SQLEXPRESS;"  
    "DATABASE=AirbnbLisbon;"
    "Trusted_Connection=yes;"  # Windows Authentication
    # For SQL Authentication, use:
    # "UID=your_username;PWD=your_password;"
)

try:
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    print(" Connected to SQL Server successfully!")
except Exception as e:
    print(f"✗ Connection failed: {e}")
    print("\n Troubleshooting tips:")
    print("1. Make sure SQL Server is running")
    print("2. Check if the database 'AirbnbLisbon' exists")
    print("3. Verify your connection string (server name)")
    print("4. If using SQL Server Express, try: SERVER=localhost\\SQLEXPRESS")
    exit()

# ============================================
# 2. LOAD DATA
# ============================================
print("\n[2] Loading enriched data...")

project_root = Path.cwd().parent
processed_path = project_root / "data" / "processed" / "listings_enriched.csv"

if not processed_path.exists():
    print(f"✗ File not found: {processed_path}")
    print("Make sure you've run the data cleaning notebook first!")
    exit()

df = pd.read_csv(processed_path)
print(f" Loaded {len(df):,} rows from {processed_path}")

# Clean data - replace NaN with None for SQL
df = df.replace({np.nan: None})

# ============================================
# 3. LOAD DIM_NEIGHBOURHOOD
# ============================================
print("\n[3] Loading dim_neighbourhood...")

# Clear existing data
cursor.execute("TRUNCATE TABLE dim_neighbourhood")
conn.commit()

neighbourhoods = df[['neighbourhood', 'neighbourhood_group']].drop_duplicates()
for _, row in neighbourhoods.iterrows():
    cursor.execute("""
        INSERT INTO dim_neighbourhood (neighbourhood_group, neighbourhood)
        VALUES (?, ?)
    """, row['neighbourhood_group'], row['neighbourhood'])
conn.commit()
print(f" Loaded {len(neighbourhoods)} neighbourhoods")

# ============================================
# 4. LOAD DIM_HOST
# ============================================
print("\n[4] Loading dim_host...")

cursor.execute("TRUNCATE TABLE dim_host")
conn.commit()

hosts = df[['host_id', 'host_name', 'host_tenure_years', 'is_superhost', 'host_total_listings']].drop_duplicates('host_id')
for _, row in hosts.iterrows():
    cursor.execute("""
        INSERT INTO dim_host (host_id, host_name, host_tenure_years, is_superhost, host_total_listings)
        VALUES (?, ?, ?, ?, ?)
    """, 
    int(row['host_id']) if pd.notna(row['host_id']) else None,
    str(row['host_name'])[:200] if pd.notna(row['host_name']) else None,
    float(row['host_tenure_years']) if pd.notna(row['host_tenure_years']) else None,
    str(row['is_superhost']) if pd.notna(row['is_superhost']) else None,
    int(row['host_total_listings']) if pd.notna(row['host_total_listings']) else None
    )
conn.commit()
print(f" Loaded {len(hosts)} hosts")

# ============================================
# 5. LOAD DIM_LISTING
# ============================================
print("\n[5] Loading dim_listing...")

cursor.execute("TRUNCATE TABLE dim_listing")
conn.commit()

for _, row in df.iterrows():
    cursor.execute("""
        INSERT INTO dim_listing (
            listing_id, listing_name, property_type, room_type, 
            accommodates, bedrooms, bathrooms, min_nights, max_nights,
            latitude, longitude, neighbourhood, neighbourhood_group
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """,
    int(row['listing_id']) if pd.notna(row['listing_id']) else None,
    str(row['listing_name'])[:500] if pd.notna(row['listing_name']) else None,
    str(row['property_type']) if pd.notna(row['property_type']) else None,
    str(row['room_type']) if pd.notna(row['room_type']) else None,
    int(row['accommodates']) if pd.notna(row['accommodates']) else None,
    float(row['bedrooms']) if pd.notna(row['bedrooms']) else None,
    float(row['bathrooms']) if pd.notna(row['bathrooms']) else None,
    int(row['min_nights']) if pd.notna(row['min_nights']) else None,
    int(row['max_nights']) if pd.notna(row['max_nights']) else None,
    float(row['latitude']) if pd.notna(row['latitude']) else None,
    float(row['longitude']) if pd.notna(row['longitude']) else None,
    str(row['neighbourhood']) if pd.notna(row['neighbourhood']) else None,
    str(row['neighbourhood_group']) if pd.notna(row['neighbourhood_group']) else None
    )
conn.commit()
print(f" Loaded {len(df)} listings")

# ============================================
# 6. LOAD FACT_PERFORMANCE
# ============================================
print("\n[6] Loading fact_performance...")

cursor.execute("TRUNCATE TABLE fact_performance")
conn.commit()

for _, row in df.iterrows():
    # Get keys
    cursor.execute("SELECT listing_key FROM dim_listing WHERE listing_id = ?", int(row['listing_id']))
    listing_key_result = cursor.fetchone()
    if not listing_key_result:
        continue
    listing_key = listing_key_result[0]
    
    cursor.execute("SELECT host_key FROM dim_host WHERE host_id = ?", int(row['host_id']))
    host_key_result = cursor.fetchone()
    if not host_key_result:
        continue
    host_key = host_key_result[0]
    
    cursor.execute("""
        SELECT neighbourhood_key FROM dim_neighbourhood 
        WHERE neighbourhood = ? AND neighbourhood_group = ?
    """, 
    str(row['neighbourhood']) if pd.notna(row['neighbourhood']) else '',
    str(row['neighbourhood_group']) if pd.notna(row['neighbourhood_group']) else ''
    )
    neighbourhood_key_result = cursor.fetchone()
    if not neighbourhood_key_result:
        continue
    neighbourhood_key = neighbourhood_key_result[0]
    
    # Insert fact
    cursor.execute("""
        INSERT INTO fact_performance (
            listing_key, host_key, neighbourhood_key, 
            price, price_per_bedroom,
            availability_365, occupancy_rate, estimated_revenue,
            review_count, review_score, 
            first_review_date, last_review_date
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """,
    listing_key,
    host_key,
    neighbourhood_key,
    float(row['price']) if pd.notna(row['price']) else None,
    float(row['price_per_bedroom']) if pd.notna(row['price_per_bedroom']) else None,
    int(row['availability_365']) if pd.notna(row['availability_365']) else None,
    float(row['occupancy_rate']) if pd.notna(row['occupancy_rate']) else None,
    float(row['estimated_revenue']) if pd.notna(row['estimated_revenue']) else None,
    int(row['review_count']) if pd.notna(row['review_count']) else 0,
    float(row['review_score']) if pd.notna(row['review_score']) else None,
    row['first_review_date'] if pd.notna(row['first_review_date']) else None,
    row['last_review_date'] if pd.notna(row['last_review_date']) else None
    )
conn.commit()
print(f" Loaded {len(df)} fact records")

# ============================================
# 7. VERIFICATION
# ============================================
print("\n[7] Verification...")

# Check row counts
cursor.execute("SELECT COUNT(*) FROM dim_neighbourhood")
print(f"  - dim_neighbourhood: {cursor.fetchone()[0]:,} rows")

cursor.execute("SELECT COUNT(*) FROM dim_host")
print(f"  - dim_host: {cursor.fetchone()[0]:,} rows")

cursor.execute("SELECT COUNT(*) FROM dim_listing")
print(f"  - dim_listing: {cursor.fetchone()[0]:,} rows")

cursor.execute("SELECT COUNT(*) FROM fact_performance")
print(f"  - fact_performance: {cursor.fetchone()[0]:,} rows")

# Test a view
try:
    cursor.execute("SELECT TOP 5 * FROM vw_top_neighbourhoods")
    results = cursor.fetchall()
    print(f"   vw_top_neighbourhoods works! (returned {len(results)} rows)")
except Exception as e:
    print(f"  ✗ View test failed: {e}")

# ============================================
# 8. COMPLETE
# ============================================
print("\n" + "="*60)
print(" DATA LOAD COMPLETED SUCCESSFULLY!")
print("="*60)

conn.close()
