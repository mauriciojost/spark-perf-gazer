# PerfGazer Showcase: CPU Hotspot Analysis with Kiro

Demonstrates how PerfGazer + Kiro identify which parts of a Spark ETL consume the most CPU.

## Prerequisites

- `sbt`, `spark-shell` (Spark 3.5.x), `uv` ([install](https://docs.astral.sh/uv/getting-started/installation/)), Kiro IDE

## Setup

### 1. Configure the MCP server in Kiro

Create or edit `.kiro/settings/mcp.json` in the workspace root:

```json
{
  "mcpServers": {
    "perfgazer-analyzer": {
      "command": "uv",
      "args": ["run", "--directory", "<absolute-path-to-repo>/showcase/mcp-server", "perfgazer-analyzer"],
      "env": {},
      "disabled": false,
      "autoApprove": ["analyze_perfgazer"]
    }
  }
}
```

Replace `<absolute-path-to-repo>` with the full path to this repository (e.g. `/Users/you/workspace/spark-perf-gazer`).

Restart Kiro to pick up the new MCP server.

### 2. Run the showcase

```bash
./showcase/run.sh
```

This will:
1. Build and publish PerfGazer locally
2. Run `etl.scala` via `spark-shell` with PerfGazer enabled (dynamic destination with date/time/appId/runId)
3. Write the PerfGazer SQL snippets to `showcase/output.md`
4. Print the prompt to paste into Kiro

### 3. Ask Kiro

Paste the suggested prompt into Kiro chat. The MCP server executes the snippets
via PySpark, joins job+stage to get CPU per job, and Kiro correlates the results
with the ETL code to tell you where to focus.
