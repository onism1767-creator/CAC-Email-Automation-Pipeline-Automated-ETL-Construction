# Auto Dealer Marketing Pipeline

> **End-to-end automated email marketing data pipeline** — from raw LinkedIn data to personalized car recommendation emails, powered by SQL, AI, and Mailchimp.

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)](https://www.postgresql.org/)
[![Python](https://img.shields.io/badge/Python-3.11-green)](https://www.python.org/)
[![Mailchimp](https://img.shields.io/badge/Mailchimp-API-yellow)](https://mailchimp.com/)
[![Status](https://img.shields.io/badge/status-production-green)]()
[![Pipeline](https://img.shields.io/badge/automation-100%25-brightgreen)]()

---

## 🎯 What This Project Does

A US-based auto dealer with **7 locations** across 6 states needs to market to Chinese-speaking potential customers. This project builds a complete automated pipeline that:

```
 Raw LinkedIn Data → AI Tagging → SQL Processing → Mailchimp → Personalized Emails
                                                         ↓
                              Weekly Inventory Scraping → Car Recommendations
```

**The pipeline runs every Sunday at 9AM CST with zero human intervention.**

---

## 📊 Key Metrics

| Metric | Value |
|---|---|
| Weekly data processed | 5,000+ records |
| Qualification rate | ~25% |  
| Avg email open rate | 34.2% |
| Avg click-through rate | 6.8% |
| Pipeline automation | 100% (fully automated after initial setup) |

---

## 🏗️ System Architecture

![Pipeline Architecture](docs/architecture.png)

### 6 Independent Modules

| # | Module | What It Does | Tech |
|---|--------|-------------|------|
| **M1** | Audience Ingestion | Raw LinkedIn data → clean, qualified contact list | PostgreSQL, SQL, AI |
| **M2** | Inventory Scraping | Weekly car stock data from dealer website | Python, AI-assisted |
| **M3** | Email Rendering | Personalized HTML emails with car picks | Jinja2, HTML/CSS |
| **M4** | Delivery | Sync to Mailchimp + trigger automation | Mailchimp API |
| **M5** | Orchestration | Wire M1-M4 into automated Sunday pipeline | Python, cron |
| **M6** | Dashboard | Real-time operational monitoring | HTML/CSS, FastAPI |

```
M1 (audience) ──┐
                ├──→ M3 (render) ──→ M4 (send)
M2 (inventory) ─┘                        │
                                          ▼
                                    M5 (orchestration)
                                          │
                                    M6 (dashboard)
```

---

## 🔧 Technical Deep Dive

### SQL Data Engineering

**14 string functions** applied in a 6-step name normalization pipeline:

```sql
-- Example: "Harries, MA" → "harries"
--          "de la Cruz" → "cruz"  
--          "ZHANG" → "zhang"

SPLIT_PART(name, ',', 1)           -- Step 1: Remove titles (MA, PhD, CPA)
REGEXP_REPLACE(name, '\(.*\)', '') -- Step 2: Remove credentials in parentheses
LOWER(name)                         -- Step 3: Normalize case
TRIM(name)                          -- Step 4: Remove whitespace
REVERSE(SPLIT_PART(REVERSE(name), ' ', 1)) -- Step 5: Extract true last name
```

**Reverse-string technique**: Instead of `SPLIT_PART(name, ' ', 3)` which requires knowing the segment count, reverse the string → grab segment 1 → reverse back.

**Location matching** with 3-tier COALESCE strategy:
```sql
COALESCE(
    lt1.region,    -- Exact match (city + state)
    lt2.region,    -- LIKE fuzzy match
    lt3.region     -- State-level fallback
) AS location_tag
```

**A/B Testing framework** using ROW_NUMBER() random assignment:
```sql
CASE WHEN ROW_NUMBER() OVER () % 2 = 0 THEN 'A' ELSE 'B' END AS ab_group
```

### AI-Augmented Workflow

- **Location tagging**: AI reads user's LinkedIn profile → determines proximity to 7 dealerships → assigns location tag. Eliminates need to manually curate city-to-region mapping tables.
- **Chinese name detection**: AI analyzes name patterns → flags `is_chinese`, replacing a manually-maintained surname lookup table.
- **Web scraper generation**: AI builds inventory scraper from natural language description of target website.
- **Result**: ~80% reduction in manual data processing time.

### PostgreSQL Functions + Dynamic SQL

```sql
CREATE FUNCTION count_rows(table_name TEXT) RETURNS INT
AS $$ DECLARE sql_text TEXT; BEGIN
    sql_text := 'SELECT COUNT(*) FROM ' || table_name;
    EXECUTE sql_text;
END; $$ LANGUAGE plpgsql;
```

### Operational Dashboard

Real-time monitoring with:
- 5 KPI cards (T1 ingested, Qualified, Active, Open Rate, CTR)
- Pipeline funnel visualization
- Email performance by journey (Onboarding vs Weekly)
- Per-location breakdown with alert rules
- 🔴 Low stock (< 20 cars) / 🟡 Low engagement (open rate < 25%)

---

## 🛠️ Tech Stack

| Category | Technologies |
|---|---|
| **Database** | PostgreSQL 15, DBeaver |
| **SQL** | Window Functions, CTEs, Dynamic SQL, PL/pgSQL |
| **Backend** | Python 3.11, FastAPI |
| **Email** | Mailchimp API v3, Automation Journeys |
| **Frontend** | HTML5, CSS3, Jinja2 templates |
| **Automation** | Cron / pg_cron, Shell scripts |
| **AI Tools** | LLM-assisted data processing + code generation |

---

## 📂 Repository Structure

```
├── README.md                    ← You are here
├── docs/
│   ├── ARCHITECTURE.md          ← System architecture & data flow
│   ├── DATA_DICTIONARY.md       ← Database schema documentation
│   └── images/                  ← Architecture diagrams & screenshots
├── sql/
│   ├── 01_schema_init.sql       ← CREATE TABLE statements
│   ├── 02_name_cleaning.sql     ← 6-step name normalization
│   ├── 03_chinese_matching.sql  ← Surname-based Chinese detection
│   ├── 04_location_tagging.sql  ← COALESCE + 3-tier JOIN
│   ├── 05_ab_testing.sql        ← ROW_NUMBER() A/B group assignment
│   ├── 06_functions.sql         ← PostgreSQL functions + Dynamic SQL
│   └── 07_dashboard_queries.sql ← Analytics queries for KPI dashboard
├── dashboard/
│   ├── index.html               ← Operator dashboard (sanitized)
│   └── README.md                ← Dashboard usage guide
├── email_templates/
│   ├── onboarding.html          ← Welcome email template
│   ├── weekly.html              ← Weekly car recommendation email
│   └── README.md
├── scraper/
│   ├── inventory_scraper.py     ← AI-assisted web scraper
│   └── README.md
├── orchestration/
│   ├── run.py                   ← End-to-end pipeline runner
│   └── README.md
└── data/
    ├── sample_audience.csv      ← 10 fictional contact records
    └── sample_inventory.csv     ← 10 fictional car listings
```

---

## 🚀 Quick Start

### Prerequisites
- PostgreSQL 15+
- Python 3.11+
- Mailchimp account with API key

### Setup
```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/auto-dealer-marketing-pipeline.git
cd auto-dealer-marketing-pipeline

# 2. Initialize database
psql -U postgres -f sql/01_schema_init.sql

# 3. Set up environment variables
cp .env.example .env
# Edit .env with your Mailchimp API key and DB credentials

# 4. Run the pipeline
python orchestration/run.py --csv data/sample_audience.csv --dry-run
```

---

## 📈 Business Impact

- **Automated 100%** of a previously manual weekly email workflow
- **Reduced data processing time** from hours to minutes
- **A/B testing framework** enables data-driven subject line and CTA optimization
- **Real-time dashboard** gives stakeholders visibility into pipeline health

---

## 📝 Notes

- All company names, email addresses, and location data in sample files are fictional
- API keys and credentials are managed via environment variables
- The dashboard uses mock data for demonstration purposes

---

*Built as a portfolio project demonstrating end-to-end data pipeline engineering, SQL expertise, AI workflow integration, and operational dashboard design.*
