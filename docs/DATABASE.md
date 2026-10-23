# DATABASE.md - Database design (Task 2, Part 1a)

This document explains the schema of the `viwell_2` database (MySQL 8): the tables, why each column has its data type, and the keys, rules and indexes.

---

## 1. The tables

| Table | One row is | Purpose |
|---|---|---|
| `companies` | a client company | who the members work for |
| `members` | a member | the person (no name, email or phone number is stored) |
| `raw_daily_metrics` | one member's wearable data for one day, exactly as received | keeps bad readings for audit, so it has no range checks |
| `daily_metrics` | the same day, cleaned | has range checks; NULL when the wearable did not sync |
| `engagement` | one member's app use for one day | app opens, content views, challenge joined |
| `mood_checkins` | one mood check-in | only days where the member checked in |
| `member_snapshots` | one member's summary for one date | the compact JSON summary that the VI service reads |
| `cleaning_log` | one line of the cleaning log | how many values were removed from each column in a run |

---

## 2. ER diagram

```mermaid
erDiagram
    companies ||--o{ members : "has (RESTRICT)"
    members ||--o{ raw_daily_metrics : "has (CASCADE)"
    members ||--o{ daily_metrics : "has (CASCADE)"
    members ||--o{ engagement : "has (CASCADE)"
    members ||--o{ mood_checkins : "has (CASCADE)"
    members ||--o{ member_snapshots : "has (CASCADE)"

    companies {
        SMALLINT_UNSIGNED company_id PK
        VARCHAR name UK
        CHAR country
        DATE created_date
    }
    members {
        INT_UNSIGNED member_id PK
        CHAR member_code UK
        SMALLINT_UNSIGNED company_id FK
        ENUM age_band
        ENUM gender
        ENUM job_type
        DATE join_date
    }
    raw_daily_metrics {
        INT_UNSIGNED member_id PK_FK
        DATE metric_date PK
        INT steps
        INT active_minutes
        DECIMAL sleep_hours
        SMALLINT resting_hr
        TINYINT wearable_synced
    }
    daily_metrics {
        INT_UNSIGNED member_id PK_FK
        DATE metric_date PK
        SMALLINT_UNSIGNED steps
        SMALLINT_UNSIGNED active_minutes
        DECIMAL sleep_hours
        TINYINT_UNSIGNED resting_hr
        TINYINT wearable_synced
    }
    engagement {
        INT_UNSIGNED member_id PK_FK
        DATE activity_date PK
        SMALLINT_UNSIGNED app_opens
        SMALLINT_UNSIGNED content_views
        TINYINT challenge_joined
    }
    mood_checkins {
        INT_UNSIGNED member_id PK_FK
        DATE checkin_date PK
        TINYINT_UNSIGNED mood_score
    }
    member_snapshots {
        INT_UNSIGNED member_id PK_FK
        DATE as_of PK
        JSON snapshot
        DATETIME created_at
    }
    cleaning_log {
        INT_UNSIGNED log_id PK
        CHAR run_id
        DATETIME run_at
        VARCHAR column_name
        VARCHAR rule_text
        INT_UNSIGNED values_received
        INT_UNSIGNED values_removed
    }
```

`companies` is the parent of `members`, and `members` is the parent of the data tables. `cleaning_log` is left alone with no relation.

---

## 3. Database settings

```sql
CREATE DATABASE IF NOT EXISTS viwell_2
  CHARACTER SET UTF8MB4
  COLLATE utf8mb4_0900_ai_ci;
```

Every table repeats the same engine, character set and collation, so nobody has to guess.

| Setting | Choice | Why |
|---|---|---|
| Storage engine | `InnoDB` | It supports transactions (changes succeed or fail together) and foreign keys. MyISAM supports neither. |
| Character set | `utf8mb4` | UTF8 for storing all characters including Arabic letters, English, and Emojis. MB4 (4 bytes) helps use Emojis as character. If we use MB3 and user inserts an emoji, their data might be lost. |
| Collation | `utf8mb4_0900_ai_ci` | utf8mb4 matching character set, 0900 Unicode 9, newest version that MySQL supports, ai for letters with marks such as in the french language or Arabic, ci for case-insensitivity. |

---

## 4. Columns and data types

Quick guide to the sizes: `TINYINT` is 1 byte (unsigned 0 to 255), `SMALLINT` is 2 bytes (unsigned 0 to 65,535), `INT` is 4 bytes (unsigned 0 to about 4.29 billion). `UNSIGNED` means no negative numbers. The general rule is to use the smallest type that fits the valid range.

### companies

| Column | Type | NULL? | Why |
|---|---|---|---|
| `company_id` | `SMALLINT UNSIGNED`, auto-increment | NOT NULL | SMALLINT + UNSIGNED = 0-65,535 range, more than enough, auto_increment as it is the primary key and registers company_id, required (cannot be null) |
| `name` | `VARCHAR(100)` | NOT NULL | Names vary in length. 100 characters is enough |
| `country` | `CHAR(2)` | NOT NULL | A country code is always exactly 2 letters. AE, SA in our case. |
| `created_date` | `DATE` | NOT NULL | A calendar day, no timestamp needed. |

### members

| Column | Type | NULL? | Why |
|---|---|---|---|
| `member_id` | `INT UNSIGNED`, auto-increment | NOT NULL | Internal key used in every join. Members can exceed 65,535, so I chose `INT`. |
| `member_code` | `CHAR(6)` | NOT NULL | The member code the VI sees, such as M0042, CHAR(6) leaves room for up to M99999 |
| `company_id` | `SMALLINT UNSIGNED` | NOT NULL | Must match `companies.company_id` exactly or the foreign key fails. |
| `age_band` | `ENUM(...)` | NOT NULL | A small fixed list. ENUM is used since the list doesn't change often, takes less size than check constraint using VARCHAR |
| `gender` | `ENUM('female','male','undisclosed')` | NOT NULL | Same reason |
| `job_type` | `ENUM('desk','field','shift')` | NOT NULL | Same Reason |
| `join_date` | `DATE` | NOT NULL | A calendar day, no timestamp needed. |

### raw_daily_metrics (wide, signed types so bad readings can still be stored)

| Column | Type | NULL? | Why |
|---|---|---|---|
| `member_id` | `INT UNSIGNED` | NOT NULL | Same type as `members.member_id`. |
| `metric_date` | `DATE` | NOT NULL | The member's local day. no timestamp needed. |
| `steps` | `INT` | NULL | Signed and wide so an impossible value like 150,000 is still kept. NULL if the wearable sent nothing. |
| `active_minutes` | `INT` | NULL | Same reason. |
| `sleep_hours` | `DECIMAL(5,2)` | NULL | Exact decimals, with room for wrong values like 23.5 or -1.5. |
| `resting_hr` | `SMALLINT` | NULL | Signed, so 0 or 220 bpm are kept. |
| `wearable_synced` | `TINYINT(1)` | NOT NULL | 1 = synced, 0 = not. It must always be known. |

### daily_metrics (narrow, unsigned types because only valid values are allowed)

| Column | Type | NULL? | Why |
|---|---|---|---|
| `member_id` | `INT UNSIGNED` | NOT NULL | Same as the parent key. |
| `metric_date` | `DATE` | NOT NULL | The calendar day. |
| `steps` | `SMALLINT UNSIGNED` | NULL | The valid range 0 to 60,000 fits in 2 bytes. NULL means no valid value. |
| `active_minutes` | `SMALLINT UNSIGNED` | NULL | The range 0 to 600 does not fit `TINYINT` (maximum 255). |
| `sleep_hours` | `DECIMAL(3,1)` | NULL | Exact, one decimal such as 7.3. |
| `resting_hr` | `TINYINT UNSIGNED` | NULL | The range 30 to 120 fits in one byte. |
| `wearable_synced` | `TINYINT(1)` | NOT NULL | 1 = synced, 0 = not synced. |

### engagement

| Column | Type | NULL? | Why |
|---|---|---|---|
| `member_id` | `INT UNSIGNED` | NOT NULL | Same as the parent key. |
| `activity_date` | `DATE` | NOT NULL | The calendar day. |
| `app_opens` | `SMALLINT UNSIGNED`, default 0 | NOT NULL | More than 255 opens in a day is possible in theory, so not `TINYINT`. Zero is a real value, so default 0 instead of NULL. |
| `content_views` | `SMALLINT UNSIGNED`, default 0 | NOT NULL | Same reason. |
| `challenge_joined` | `TINYINT(1)`, default 0 | NOT NULL | A yes/no flag. 0 means did not join. |

### mood_checkins

| Column | Type | NULL? | Why |
|---|---|---|---|
| `member_id` | `INT UNSIGNED` | NOT NULL | Same as the parent key. |
| `checkin_date` | `DATE` | NOT NULL | The day of the check-in. |
| `mood_score` | `TINYINT UNSIGNED` | NOT NULL | Values 1 to 5 need one byte. A row exists only if a check-in happened, so it is never NULL. |

### member_snapshots

| Column | Type | NULL? | Why |
|---|---|---|---|
| `member_id` | `INT UNSIGNED` | NOT NULL | Same as the parent key. |
| `as_of` | `DATE` | NOT NULL | The date the snapshot describes. |
| `snapshot` | `JSON` | NOT NULL | MySQL checks that the text is valid JSON. |
| `created_at` | `DATETIME`, default current time | NOT NULL | Filled in automatically. `DATETIME` is used instead of `TIMESTAMP` because `TIMESTAMP` stops in 2038 and converts time zones. Stored in UTC. |

### cleaning_log

| Column | Type | NULL? | Why |
|---|---|---|---|
| `log_id` | `INT UNSIGNED`, auto-increment | NOT NULL | The database numbers each line. |
| `run_id` | `CHAR(36)` | NOT NULL | A UUID is always 36 characters. It groups the lines of one run. |
| `run_at` | `DATETIME` | NOT NULL | When the run started (UTC). |
| `column_name` | `VARCHAR(32)` | NOT NULL | Short names that vary in length. |
| `rule_text` | `VARCHAR(120)` | NOT NULL | A short sentence that varies in length. |
| `values_received` | `INT UNSIGNED` | NOT NULL | A count, never negative, and it can reach hundreds of thousands. |
| `values_removed` | `INT UNSIGNED` | NOT NULL | Same reason. |

---

## 5. Keys and rules

### Primary keys

| Table | Primary key | Meaning |
|---|---|---|
| `companies` | `company_id` | one row per company |
| `members` | `member_id` | one row per member |
| `raw_daily_metrics`, `daily_metrics` | `(member_id, metric_date)` | one row per member per day |
| `engagement` | `(member_id, activity_date)` | one row per member per day |
| `mood_checkins` | `(member_id, checkin_date)` | one check-in per member per day |
| `member_snapshots` | `(member_id, as_of)` | one snapshot per member per date |
| `cleaning_log` | `log_id` | one log line |

### Unique keys

- `uq_companies_name`: no two companies share a name.
- `uq_members_code`: no two members share a code.

### CHECK constraints

| Constraint | Rule |
|---|---|
| `ck_companies_country` | country is `AE` or `SA` |
| `ck_dm_steps` | steps between 0 and 60,000 |
| `ck_dm_active` | active minutes between 0 and 600 |
| `ck_dm_sleep` | sleep between 2.0 and 14.0 hours |
| `ck_dm_hr` | resting heart rate between 30 and 120 |
| `ck_dm_synced` | if the wearable did not sync, all four metrics must be NULL |
| `ck_eng_opens`, `ck_eng_views` | at most 500 |
| `ck_eng_challenge` | `challenge_joined` is 0 or 1 |
| `ck_mood_score` | mood score between 1 and 5 |

A `CHECK` passes when the value is NULL, so the metric columns can still be NULL.

### Foreign keys (what happens when a parent row is deleted)

| Foreign key | Rule | Why |
|---|---|---|
| `members.company_id` to `companies` | `RESTRICT` | A company that still has members cannot be deleted by accident. |
| `member_id` to `members` in the five data tables | `CASCADE` | When a member is erased, all of their health data is erased with them, so no orphaned data is left behind. |

`CASCADE` can be dangerous for health data: a delete with a wrong condition silently removes the full history of every member it matches. Backups and checking the number of affected rows before committing protect against this.

---

## 6. Indexes

Primary keys and unique keys are indexes too.

| Index | Table and column | Reason |
|---|---|---|
| Primary key `(member_id, date)` | the four daily tables | finds one member's rows over a date range quickly |
| `uq_companies_name` | `companies(name)` | enforces unique names and speeds lookup by name |
| `uq_members_code` | `members(member_code)` | enforces unique codes and speeds lookup by code |
| `idx_members_company` | `members(company_id)` | fast "all members of one company"; also used by the foreign key |
| `idx_cleaning_log_run` | `cleaning_log(run_id)` | fast "show the lines of one cleaning run" |

---

## 7. Roles and least privilege

vi_etl can read and write the data tables but cannot change the schema or grant rights. vi_app can only read member_snapshots. Each account gets only what its job needs. The data is health data (mood, heart rate, sleep), 
so a leaked password or a bug should expose as little as possible. If the VI service is hacked or has an SQL bug, it can only read snapshots. It cannot read raw member data, change or delete rows, or drop tables. The ETL 
account cannot drop tables either, so a bad loader script can’t destroy the schema. Separate accounts also show who did what in the logs.

---

## 8. Data generation, loading and cleaning (1d)

**Generation.** `scripts/generate_data.py` creates 500 members (45,000 daily rows) and 5,000 members (450,000 daily rows) over 90 days. It writes one CSV per table. It is the Task 1 generator, adapted to write CSV files.

**Loading.** `scripts/load_data.py` uses `LOAD DATA LOCAL INFILE`, not row-by-row inserts. It runs in one transaction, so a failed load leaves nothing behind. `LOCAL` turns bad rows into warnings instead of errors, so the script checks the row count and warnings for every table.

| Size | Raw daily rows | Load time |
|---|---|---|
| 500 members | 45,000 | 1.50 s |
| 5,000 members | 450,000 | 14.20 s |

**Server setting changed.** `LOAD DATA LOCAL INFILE` is off by default in MySQL 8 (error 3948). I ran `SET PERSIST local_infile = 1;` as root. The client also has to allow it (`local_infile=True` in the Python connection).

**Cleaning in SQL.** `sql/clean_daily_metrics.sql` copies `raw_daily_metrics` into `daily_metrics` with `INSERT ... SELECT`. A `CASE` expression sets values outside the allowed range to NULL. The ranges match the CHECK constraints. The number removed per column is saved in `cleaning_log`.

| Column | Rule | 500 members: removed | 5,000 members: removed |
|---|---|---|---|
| steps | 0 to 60,000 | 10 of 41,788 | 86 of 415,904 |
| active_minutes | 0 to 600 | 4 of 41,788 | 42 of 415,904 |
| sleep_hours | 2.0 to 14.0 | 8 of 41,788 | 86 of 415,904 |
| resting_hr | 30 to 120 | 8 of 41,788 | 86 of 415,904 |

**Planted cases fixed.** In Task 1, 2 of the 14 members planted to trigger escalation had only 2 low check-ins in their last 5 (the rule needs 3). Two near-miss members had only 1 low check-in instead of 2. 
I corrected the patterns. The generator now stops with an error if a pattern does not match its name. `tests/test_planted_cases.py` also asks MySQL, with a window function, to check every planted case in the 
loaded data: every escalation member has 3 or more low check-ins among the last 5, and every near-miss member has exactly 2. Ordinary members cannot meet the rule by accident.
