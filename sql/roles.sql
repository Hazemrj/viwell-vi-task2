-- Part 1c: two roles and one user for each. 

-- Roles: named bundles of privileges.
CREATE ROLE IF NOT EXISTS 'vi_etl';   -- the data loading and cleaning job
CREATE ROLE IF NOT EXISTS 'vi_app';   -- the VI service

-- Privileges for each role.
-- vi_etl: READ and WRITE the raw and clean tables. No CREATE/ALTER/DROP, no GRANT.
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.companies         TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.members           TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.raw_daily_metrics TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.daily_metrics     TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.engagement        TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.mood_checkins     TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.member_snapshots  TO 'vi_etl';
GRANT SELECT, INSERT, UPDATE, DELETE ON viwell_2.cleaning_log      TO 'vi_etl';

-- vi_app: can only READ one table.
GRANT SELECT ON viwell_2.member_snapshots TO 'vi_app';

-- one user per role.
CREATE USER IF NOT EXISTS 'vi_etl_user'@'localhost' IDENTIFIED BY 'change_me_etl';
CREATE USER IF NOT EXISTS 'vi_app_user'@'localhost' IDENTIFIED BY 'change_me_app';
GRANT 'vi_etl' TO 'vi_etl_user'@'localhost';
GRANT 'vi_app' TO 'vi_app_user'@'localhost';

-- setting default role for user at login
SET DEFAULT ROLE 'vi_etl' TO 'vi_etl_user'@'localhost';
SET DEFAULT ROLE 'vi_app' TO 'vi_app_user'@'localhost';
