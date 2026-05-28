# System Architecture

## Overview

The Auto Dealer Marketing Pipeline is a modular, end-to-end data processing system that transforms raw LinkedIn profile data into personalized marketing emails. The system is designed around 6 independent modules that communicate only through shared database tables — no shared state, no hidden dependencies.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                                      │
│                                                                          │
│  ┌──────────────────────┐              ┌──────────────────────────────┐ │
│  │  LinkedIn T1 Data     │              │  Dealer Website Inventory    │ │
│  │  (Profiles + Emails)  │              │  (autocac.com/shop)          │ │
│  └──────────┬───────────┘              └────────────┬─────────────────┘ │
│             │                                        │                   │
│     ┌───────┴────────┐                    ┌─────────┴──────────┐        │
│     │ Lane A: History │                    │ Lane B: Weekly     │        │
│     │ (one-time CSV)  │                    │ (Sunday 9AM cron)  │        │
│     └───────┬─────────┘                    └─────────┬──────────┘        │
│             │                                        │                   │
└─────────────┼────────────────────────────────────────┼───────────────────┘
              │                                        │
              ▼                                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    CAC_MKT_PROD (PostgreSQL)                              │
│                                                                          │
│  ┌─────────────────────┐    ┌──────────────────────┐                    │
│  │   audience table     │    │   inventory table     │                    │
│  │  - member_id (PK)   │    │  - car_id (PK)       │                    │
│  │  - email, first_name│    │  - year, make, model  │                    │
│  │  - last_name        │    │  - price, mileage     │                    │
│  │  - location_raw     │    │  - photo_url          │                    │
│  │  - is_chinese       │    │  - shop_location      │                    │
│  │  - location_tag     │    │  - scraped_at         │                    │
│  │  - std_location     │    │                       │                    │
│  │  - ingested_at      │    │                       │                    │
│  └─────────┬───────────┘    └───────────┬───────────┘                   │
└────────────┼────────────────────────────┼───────────────────────────────┘
             │                            │
             └──────────┬─────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      PROCESSING LAYER                                     │
│                                                                          │
│  ┌──────────────────────┐   ┌──────────────────────┐                    │
│  │  M1: Audience        │   │  M2: Inventory        │                    │
│  │  Ingestion            │   │  Scraping             │                    │
│  │  - Read LinkedIn CSV  │   │  - Hit listings API   │                    │
│  │  - AI Location Tagger │   │  - Parse car data     │                    │
│  │  - Qualification      │   │  - Normalize shops    │                    │
│  │  - Upsert to DB       │   │  - Full REPLACE       │                    │
│  └──────────┬───────────┘   └──────────┬───────────┘                    │
│             └──────────┬───────────────┘                                 │
│                        ▼                                                 │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  M3: Email Rendering                                          │       │
│  │  - Jinja2 template engine                                     │       │
│  │  - Car selection: match by shop → fallback to global pool     │       │
│  │  - Shop info injection (address, phone, hours)                │       │
│  │  - Output: one HTML file per qualified contact                │       │
│  └──────────────────────────┬───────────────────────────────────┘       │
│                             ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  M4: Delivery                                                 │       │
│  │  - Mailchimp API v3 (POST /lists/{id}/members)                │       │
│  │  - Field mapping: member_id→EMAIL, first_name→FNAME, etc.     │       │
│  │  - Tag assignment: cac-<location> + source-linkedin            │       │
│  │  - Automation trigger: Onboarding (Day 0) + Weekly (Day 3+)   │       │
│  └──────────────────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      MONITORING LAYER                                     │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  M6: Operator Dashboard                                       │       │
│  │  - 5 KPI Cards (T1 Ingested, Qualified, Active, Open, CTR)   │       │
│  │  - Pipeline Funnel (100%→78%→25.9%→24.0%)                   │       │
│  │  - Email Performance (Onboarding vs Weekly)                  │       │
│  │  - Inventory Coverage (per-location)                         │       │
│  │  - Alert Rules: 🔴 Stock<20, 🟡 Open<25%, 🟡 Untagged>80%   │       │
│  │  - Backend: FastAPI + SQL queries                            │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  M5: Orchestration                                            │       │
│  │  - run.py: M1→M2→M3→M4                                       │       │
│  │  - CLI: --csv, --skip-scrape, --dry-run                       │       │
│  │  - Failure handling: halt downstream + fallback data          │       │
│  │  - Scheduling: cron job (Sunday 9AM CST)                      │       │
│  │  - Logging: per-run logs + stats for M6 consumption           │       │
│  └──────────────────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
1. LinkedIn CSV → M1 ingestion → audience table (with is_chinese + location_tag)
2. Dealer website → M2 scraper → inventory table (with normalized shop_location)
3. audience + inventory → M3 renderer → HTML email files (outputs/<email>.html)
4. HTML files → M4 Mailchimp API → Sent to recipients
5. M6 Dashboard reads audience + inventory + email_events → Real-time view
```

## Module Dependencies

```
M1 ──┐                    Independent: M1, M2 (can run in parallel)
      ├──→ M3 ──→ M4      M3 needs both M1 and M2
M2 ──┘                    M4 needs M3
                           M5 wraps M1-M4 (built last)
                           M6 is read-only (blocks nothing)
```

## Database Schema

### `audience` — Qualified Contacts
| Column | Type | Description |
|---|---|---|
| member_id | TEXT PK | LinkedIn unique identifier |
| email | TEXT NOT NULL | Contact email → Mailchimp EMAIL |
| first_name | TEXT NOT NULL | First name → Mailchimp FNAME |
| last_name | TEXT | Last name → Mailchimp LNAME |
| location_raw | TEXT | Original LinkedIn location string |
| is_chinese | INT | 1 = identified as Chinese-speaking |
| location_tag | TEXT | Assigned dealership tag (e.g., "CAC-Dallas") |
| std_location | TEXT | Standardized location → Mailchimp STD_LOC |
| ingested_at | TIMESTAMP | Record creation timestamp |

### `inventory` — Vehicle Stock
| Column | Type | Description |
|---|---|---|
| car_id | TEXT PK | Unique vehicle identifier |
| year | INT | Manufacturing year |
| make | TEXT | Brand (e.g., "Lexus") |
| model | TEXT | Model name |
| trim | TEXT | Trim level |
| mileage | INT | Odometer reading |
| price | DECIMAL(10,2) | Listed price |
| photo_url | TEXT | Primary photo URL |
| product_url | TEXT | Detail page URL |
| shop_location | TEXT | Normalized dealership tag |

## Key Technical Decisions

### Why 3-tier Location Matching?
A single JOIN on city+state covers ~80% of records. But LinkedIn locations are free-text — some users write "Dallas-Fort Worth Metroplex" while others write "DFW". Three cascading JOINs with COALESCE maximize coverage without requiring a perfect mapping table.

### Why Full REPLACE for Inventory?
Vehicle inventory is inherently stateful — cars get sold, new ones arrive. Incremental diff logic is fragile. A weekly full scrape + REPLACE is simpler and more reliable.

### Why Mailchimp (not self-hosted SMTP)?
IP reputation management, bounce handling, unsubscribe compliance (CAN-SPAM Act), and deliverability monitoring are complex operational burdens. Mailchimp handles these out of the box.

### Why Dynamic SQL + Functions?
The pipeline needs to work with weekly batch data where table names change. Hard-coding table names makes the pipeline brittle. Dynamic SQL allows the same logic to operate on any table name passed as a parameter.

## Scaling Considerations

- **Audience growth**: Upsert by member_id prevents duplicates as data volume grows
- **Inventory changes**: Full replace handles any number of cars
- **Regional expansion**: Adding new dealerships requires only: (1) new tag in the tagger dictionary, (2) new Mailchimp tag, (3) new dashboard filter option
- **Performance**: Most queries use indexed columns (member_id, location_tag). For 100K+ records, consider adding composite indexes on (location_tag, is_chinese)
