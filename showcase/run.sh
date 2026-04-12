#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   PerfGazer Showcase: CPU Hotspot Analysis       ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# Step 1: Publish PerfGazer locally
echo -e "${BOLD}Step 1/3: Publishing PerfGazer locally...${RESET}"
VERSION="0.0.0-showcase-$$-$(date +%s)"
echo "  Version: $VERSION"
(cd "$PROJECT_DIR" && sbt -warn "set ThisBuild / version := \"$VERSION\"" publishLocal)
echo -e "${GREEN}  ✓ Published${RESET}"
echo ""

# Step 2: Run the ETL with PerfGazer
echo -e "${BOLD}Step 2/3: Running ETL with PerfGazer enabled...${RESET}"
spark-shell \
  --packages "io.github.amadeusitgroup:perfgazer_spark_3-5-2_2.12:$VERSION" \
  --conf spark.extraListeners=com.amadeus.perfgazer.PerfGazer \
  --conf spark.perfgazer.sink.class=com.amadeus.perfgazer.JsonSink \
  --conf "spark.perfgazer.sink.json.destination=/tmp/perfgazer/showcase/date={{perfgazer.now.year}}-{{perfgazer.now.month}}-{{perfgazer.now.day}}/time={{perfgazer.now.hour}}-{{perfgazer.now.minute}}-{{perfgazer.now.second}}/applicationId={{spark.app.id}}/runId={{perfgazer.runid}}/" \
  --conf spark.perfgazer.stages.enabled=true \
  --conf "spark.driver.bindAddress=127.0.0.1" \
  --conf "spark.driver.host=127.0.0.1" \
  -i "$SCRIPT_DIR/etl.scala"
echo -e "${GREEN}  ✓ ETL complete. Snippets written to showcase/output.md${RESET}"
echo ""

# Step 3: Show next steps
echo -e "${BOLD}Step 3/3: Ready for Kiro${RESET}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Now open Kiro and paste this in the chat:${RESET}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${CYAN}  Read #showcase/output.md and pass its content to the"
echo -e "  perfgazer-analyzer tool. Then read #showcase/etl.scala"
echo -e "  and tell me which code blocks I should optimize first,"
echo -e "  matching each job description to its code.${RESET}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
