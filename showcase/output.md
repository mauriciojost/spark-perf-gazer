# PerfGazer Snippets

SQL snippets to create views over PerfGazer JSON reports.

```sql
CREATE OR REPLACE TEMPORARY VIEW sql
USING json
OPTIONS (
  path "/tmp/perfgazer/showcase/date=2026-04-12/time=05-19-45/applicationId=local-1775963985165/runId=d4f37b6a-b264-41d3-8b91-72c9d411a3c9/sql-reports-*.json"
);

CREATE OR REPLACE TEMPORARY VIEW job
USING json
OPTIONS (
  path "/tmp/perfgazer/showcase/date=2026-04-12/time=05-19-45/applicationId=local-1775963985165/runId=d4f37b6a-b264-41d3-8b91-72c9d411a3c9/job-reports-*.json"
);

CREATE OR REPLACE TEMPORARY VIEW stage
USING json
OPTIONS (
  path "/tmp/perfgazer/showcase/date=2026-04-12/time=05-19-45/applicationId=local-1775963985165/runId=d4f37b6a-b264-41d3-8b91-72c9d411a3c9/stage-reports-*.json"
);

CREATE OR REPLACE TEMPORARY VIEW task
USING json
OPTIONS (
  path "/tmp/perfgazer/showcase/date=2026-04-12/time=05-19-45/applicationId=local-1775963985165/runId=d4f37b6a-b264-41d3-8b91-72c9d411a3c9/task-reports-*.json"
);

```
