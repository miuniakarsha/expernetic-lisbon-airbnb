# Lisbon Airbnb — Data Quality Report
Generated from raw files scraped by Inside Airbnb (2026-07-02).
## Row counts
- listings: 24,876
- calendar: 9,092,881
- reviews: 1,886,932
- neighbourhoods: 134

## Referential integrity
- Calendar rows with no matching listing: 13,140
- Review rows with no matching listing: 195
- Listings with unrecognized neighbourhood: 0

## Duplicates
- Exact duplicate rows: 0
- Duplicate listing IDs: 0
- Fuzzy duplicate candidates (same host+location+capacity): 2704

## Validation rule violations
- price is negative or zero: 0 (0.00%)
- latitude out of Lisbon bounds (38.6-38.9): 2584 (10.39%)
- longitude out of Lisbon bounds (-9.5 to -9.0): 84 (0.34%)
- accommodates <= 0: 0 (0.00%)
- bedrooms is null: 4458 (17.92%)
- minimum_nights > 365: 1 (0.00%)
- review score present but n_reviews == 0: 0 (0.00%)
