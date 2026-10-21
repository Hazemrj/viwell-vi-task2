## Wed 21 Oct
Hours: ~4
Done: schema for companies, members (001_schema.sql draft)
Decisions: used TINYINT UNSIGNED for age_band index because ...
Problems: ERROR 1215 foreign key failed, cause: parent table created after child; fixed by reordering
Learned: difference between CHAR and VARCHAR for fixed-length codes
Next: remaining tables, then migrate.py
Commits: 4