# Lisbon Airbnb Market Intelligence

**Data Engineer Intern — Technical Assignment | Expernetic (Pvt) Ltd**

Candidate: Miuni Akarsha Praghnarathna
Submission date: 12/07/2026

---

## 1. Project Overview

This project transforms the public Inside Airbnb dataset (https://insideairbnb.com/) for
Lisbon, Portugal (scraped 2 July 2026) into a cleaned, modeled, analytics-ready dataset, and
derives statistically-grounded, business-relevant insights for a hypothetical Airbnb market
intelligence consultancy. The pipeline covers ingestion and profiling, cleaning and
enrichment, a SQL Server star schema, exploratory and statistical analysis, an NLP sentiment
experiment on guest reviews, and an interactive Power BI dashboard.

Scope decision: this assignment is explicitly designed to exceed what one person can
complete in a week. Per the brief's own guidance ("quality outweighs quantity"), I chose to
go deep on one city (Lisbon) rather than shallow across many, and prioritized the mandatory
and highest-weighted rubric sections (Data Engineering, Statistical Thinking, Analytical
Storytelling) over lower-weighted optional sections (cloud-native deployment, recommendation
systems, multi-city comparison). Full rationale is in reports/Final_Report.pdf, Section 2.

## 2. Repository Structure

data/
    raw/            Original Inside Airbnb files (gitignored, see download instructions below)
    processed/      Cleaned and enriched CSV outputs from the pipeline (gitignored)
notebooks/          Jupyter notebooks, run in the order listed below
    01_ingestion_profiling.ipynb
    02_data_cleaning_engineering.ipynb
    03_exploratory_data_analysis.ipynb
    04_review_sentiment_analysis.ipynb
    run_load_data.ipynb
sql/                 SQL Server DDL (star schema) and Python load script
    create_star_schema.sql
    load_data_to_sql.py
powerbi/              Power BI dashboard
    Lisbon Airbnb Market Intelligence dashboard.pbix
reports/
    Final_Report.pdf
    figures/         PNG exports referenced in the report
docs/                 Data quality report, schema profile, decisions log
requirements.txt
README.md

## 3. How to Reproduce

### 3.1 Prerequisites

- Python 3.10+ with Jupyter Lab (Anaconda distribution)
- SQL Server (local instance, e.g. SQL Server Express) with SQL Server Management Studio
- ODBC Driver 17 for SQL Server (required by pyodbc)
- Power BI Desktop (optional, for the dashboard)
- Approximately 2 GB free disk space (calendar and reviews files are large uncompressed)

### 3.2 Get the data

Data is not committed to this repo (raw files are approximately 290 MB compressed).

1. Go to https://insideairbnb.com/get-the-data/
2. Find Lisbon, Lisboa, Portugal, dated 2026-07-02 (or latest available)
3. Download: listings.csv.gz (detailed), calendar.csv.gz, reviews.csv.gz (detailed),
   neighbourhoods.csv, neighbourhoods.geojson
4. Place all files in data/raw/

### 3.3 Environment setup

    python -m venv venv
    source venv/bin/activate        (Windows: venv\Scripts\activate)
    pip install -r requirements.txt

### 3.4 Run order

1. notebooks/01_ingestion_profiling.ipynb — load raw files, profile, generate a data quality
   report (writes to data/processed/data_quality_report.md and schema_profile.csv)
2. notebooks/02_data_cleaning_engineering.ipynb — clean, standardize, impute, and enrich into
   data/processed/listings_enriched.csv
3. notebooks/03_exploratory_data_analysis.ipynb — exploratory analysis, hypothesis tests, and
   figures saved to reports/figures/
4. notebooks/04_review_sentiment_analysis.ipynb — rule-based sentiment analysis on a review
   sample, writes data/processed/listings_enriched_with_sentiment.csv
5. sql/create_star_schema.sql — run in SSMS to create the AirbnbLisbon database and star
   schema (dim_listing, dim_host, dim_neighbourhood, fact_performance)
6. notebooks/run_load_data.ipynb — loads the enriched CSV into the SQL Server star schema
7. powerbi/Lisbon Airbnb Market Intelligence dashboard.pbix — open in Power BI Desktop,
   refresh to pull the latest data from SQL Server

Note: dim_listing.listing_id must be BIGINT, not INT, to hold the full range of Airbnb
listing IDs. This is already corrected in create_star_schema.sql; see the Engineering
Decision Log in the Final Report for details on why this matters.

## 4. Key Deliverables Checklist

- [x] Source code (this repo)
- [x] Reproducibility instructions (this README)
- [x] Professional PDF report (reports/Final_Report.pdf)
- [x] Assumptions and decisions log (in Final_Report.pdf, Engineering Decision Log)
- [x] Summary of completed and incomplete work (Final_Report.pdf, Sections 13-14)
- [x] AI usage disclosure (Final_Report.pdf, Appendix A)
- [x] Power BI dashboard (powerbi/)
- [x] SQL Server star schema (sql/)

## 5. AI Usage

This project was built with AI assistance from two tools: ChatGPT (GPT-4), used for initial
code drafting, debugging, SQL schema design, and DAX measures; and Claude (Anthropic), used
for cross-checking the final report's claims against actual notebook output, diagnosing and
fixing the SQL Server listing_id overflow bug, and correcting statistical and EDA figures
that did not match the underlying data. Full disclosure of tools used, AI-assisted sections,
key prompts, validation steps, and what was rejected or modified is documented in
Final_Report.pdf, Section 10 and Appendix A, per the assignment's AI Tools Usage Policy.

## 6. Dataset Attribution

Data sourced from Inside Airbnb (https://insideairbnb.com/), an independent, non-commercial
project. Used here under its stated public-use terms for this academic and assessment
purpose.
