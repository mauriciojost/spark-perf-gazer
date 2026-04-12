"""PerfGazer Analyzer MCP Server.

Reads PerfGazer SQL snippets, executes them in a local PySpark session
to create views, then queries job+stage to compute CPU usage per job.
"""

import re
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("perfgazer-analyzer")


def _extract_sql_statements(snippets_md: str) -> list[str]:
    """Extract individual SQL statements from the markdown content."""
    blocks = re.findall(r"```sql\s*\n(.*?)```", snippets_md, re.DOTALL)
    statements = []
    for block in blocks:
        for stmt in block.split(";"):
            stmt = stmt.strip()
            if stmt and stmt.upper().startswith("CREATE"):
                statements.append(stmt)
    return statements


def _run_spark_analysis(statements: list[str]) -> str:
    """Start PySpark, execute DDLs, run the join query, return results."""
    from pyspark.sql import SparkSession

    spark = (
        SparkSession.builder
        .master("local[*]")
        .appName("perfgazer-analyzer")
        .config("spark.driver.bindAddress", "127.0.0.1")
        .config("spark.driver.host", "127.0.0.1")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("ERROR")

    try:
        executed = []
        for stmt in statements:
            try:
                spark.sql(stmt)
                executed.append(stmt.split("\n")[0])
            except Exception as e:
                executed.append(f"FAILED: {stmt.split(chr(10))[0]} — {e}")

        query = """
            SELECT j.jobName,
                   ROUND(SUM(s.execCpuNs) / 1e9, 2) as totalCpuSecs,
                   ROUND(SUM(s.execRunNs) / 1e9, 2) as totalRunSecs,
                   ROUND(SUM(s.shuffleReadBytes) / 1e6, 1) as totalShuffleReadMB,
                   ROUND(SUM(s.shuffleWriteBytes) / 1e6, 1) as totalShuffleWriteMB,
                   ROUND(SUM(s.memoryBytesSpilled) / 1e6, 1) as memorySpilledMB,
                   ROUND(SUM(s.diskBytesSpilled) / 1e6, 1) as diskSpilledMB
              FROM job j
              JOIN stage s ON ARRAY_CONTAINS(j.stages, s.stageId)
             GROUP BY j.jobName
             ORDER BY totalCpuSecs DESC
        """

        df = spark.sql(query)
        rows = [row.asDict() for row in df.collect()]
        total_cpu = sum(r["totalCpuSecs"] for r in rows)

        lines = []
        lines.append("# PerfGazer CPU Analysis (via Spark SQL)")
        lines.append("")
        lines.append(f"Views created: {len([e for e in executed if not e.startswith('FAILED')])}")
        lines.append(f"Total executor CPU time: {total_cpu:.2f} seconds")
        lines.append("")
        lines.append("## CPU Usage per Job")
        lines.append("")

        for i, row in enumerate(rows, 1):
            pct = round(row["totalCpuSecs"] / total_cpu * 100, 1) if total_cpu > 0 else 0
            lines.append(f"### {i}. {row['jobName']}")
            lines.append(f"- CPU: {row['totalCpuSecs']}s ({pct}% of total)")
            lines.append(f"- Run time: {row['totalRunSecs']}s")
            lines.append(f"- Shuffle read: {row['totalShuffleReadMB']}MB, write: {row['totalShuffleWriteMB']}MB")
            if row["memorySpilledMB"] > 0 or row["diskSpilledMB"] > 0:
                lines.append(f"- ⚠️ SPILL: memory={row['memorySpilledMB']}MB, disk={row['diskSpilledMB']}MB")
            lines.append("")

        return "\n".join(lines)

    finally:
        spark.stop()


@mcp.tool()
def analyze_perfgazer(perfgazer_snippets: str) -> str:
    """Analyze PerfGazer output by executing SQL snippets via Spark.

    Parses CREATE VIEW statements from the PerfGazer snippets file,
    executes them in a local PySpark session, then joins job + stage
    tables to compute CPU usage per job.

    Args:
        perfgazer_snippets: Content of the output.md file containing
            the SQL snippets logged by PerfGazer at shutdown.

    Returns:
        CPU usage ranking per job with shuffle and spill details.
    """
    statements = _extract_sql_statements(perfgazer_snippets)
    if not statements:
        return "Error: No SQL statements found in the PerfGazer snippets."
    return _run_spark_analysis(statements)
