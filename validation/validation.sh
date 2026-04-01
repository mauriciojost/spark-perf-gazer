#!/usr/bin/env bash
#
# Validates that spark-shell starts correctly with PerfGazer listener
# using a locally published (sbt publishLocal) snapshot.
#
# Usage:
#   ./validation/validation.sh <jdks_conf> <combinations_file>
#
# Example:
#   ./validation/validation.sh validation/jdks.conf validation/combinations.txt

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <jdks_conf> <combinations_file>"
  exit 1
fi

JDKS_CONF="$1"
COMBINATIONS_FILE="$2"

for f in "$JDKS_CONF" "$COMBINATIONS_FILE"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: File not found: $f"
    exit 1
  fi
done

# Resolve JDK path from config file
resolve_java_home() {
  local jdk_version="$1"
  grep -v '^ *#' "$JDKS_CONF" | grep -v '^ *$' | while read -r ver path; do
    if [ "$ver" = "$jdk_version" ]; then
      echo "$path"
      return
    fi
  done
}

# --- Publish locally and resolve version ---
echo "Publishing locally with sbt..."
sbt publishLocal
echo ""

VERSION=$(sbt -no-colors "print version" 2>/dev/null | tail -1 | xargs)
if [ -z "$VERSION" ]; then
  echo "ERROR: Could not resolve sbt project version."
  exit 1
fi
echo "Resolved version: $VERSION"
echo ""

# Runs a single validation. Returns 0 on success, 1 on failure.
validate() {
  local spark_version="$1" scala_version="$2" jdk_version="$3"

  local java_home
  java_home=$(resolve_java_home "$jdk_version")
  if [ -z "$java_home" ]; then
    echo "SKIP: JDK $jdk_version is not configured in $JDKS_CONF."
    return 1
  fi
  if [ ! -d "$java_home" ]; then
    echo "SKIP: JDK $jdk_version path not found: $java_home"
    return 1
  fi

  export JAVA_HOME="$java_home"
  export PATH="$JAVA_HOME/bin:$PATH"

  local spark_suffix
  spark_suffix=$(echo "$spark_version" | tr '.' '-')
  local artifact="io.github.amadeusitgroup:perfgazer_spark_${spark_suffix}_${scala_version}:${VERSION}"

  echo "=== Validation ==="
  echo "  Spark:     $spark_version"
  echo "  Scala:     $scala_version"
  echo "  Version:   $VERSION"
  echo "  Artifact:  $artifact"
  echo "  JDK:       $jdk_version ($JAVA_HOME)"
  echo "  Java:      $(java -version 2>&1 | head -1)"
  echo ""

  local dest="/tmp/perfgazer/validation_$$_${spark_version}_${scala_version}_jdk${jdk_version}"
  local log_file="/tmp/perfgazer_validation_$$_${spark_version}_${scala_version}_jdk${jdk_version}.log"

  echo "Running spark-shell (will send a simple query and exit)..."
  echo ""

  set +e
  echo 'spark.sql("SELECT 1 AS test").show(); System.exit(0)' \
    | spark-shell \
        --packages "$artifact" \
        --conf "spark.driver.bindAddress=127.0.0.1" \
        --conf "spark.driver.host=127.0.0.1" \
        --conf "spark.extraListeners=com.amadeus.perfgazer.PerfGazer" \
        --conf "spark.perfgazer.sink.class=com.amadeus.perfgazer.JsonSink" \
        --conf "spark.perfgazer.sink.json.destination=$dest" \
      > "$log_file" 2>&1
  local exit_code=$?
  set -e

  if [ $exit_code -eq 0 ] && grep -q "+----+" "$log_file"; then
    grep -A3 "+----+" "$log_file"
    echo ""
    echo "--- JSON sink output (destination: $dest) ---"
    if [ -d "$dest" ]; then
      find "$dest" -type f | sort
      echo ""
      for f in $(find "$dest" -type f -name "*.json" | sort); do
        echo ">> $f"
        head -5 "$f"
        echo "..."
        echo ""
      done
    else
      echo "(no output directory created — query may have been too short to trigger reports)"
    fi
    rm -f "$log_file"
    echo "PASS: Spark $spark_version / Scala $scala_version / JDK $jdk_version"
    return 0
  else
    echo "--- Last 40 lines of output ---"
    tail -40 "$log_file"
    echo ""
    echo "Full log: $log_file"
    echo "JSON sink destination: $dest"
    echo ""
    echo "FAIL: Spark $spark_version / Scala $scala_version / JDK $jdk_version (exit code: $exit_code)"
    return 1
  fi
}

# --- Main ---
TOTAL=0
PASSED=0
FAILED=0
FAILED_COMBOS=()

while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | sed 's/#.*//' | xargs)
  [ -z "$line" ] && continue

  read -r spark_ver scala_ver jdk_ver <<< "$line"
  TOTAL=$((TOTAL + 1))

  echo "========================================"
  echo "Combination $TOTAL: Spark $spark_ver / Scala $scala_ver / JDK $jdk_ver"
  echo "========================================"

  if validate "$spark_ver" "$scala_ver" "$jdk_ver"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    FAILED_COMBOS+=("Spark $spark_ver / Scala $scala_ver / JDK $jdk_ver")
  fi
  echo ""
done < "$COMBINATIONS_FILE"

echo "========================================"
echo "Results: $PASSED/$TOTAL passed, $FAILED failed"
if [ $FAILED -gt 0 ]; then
  echo "Failed:"
  for combo in "${FAILED_COMBOS[@]}"; do
    echo "  - $combo"
  done
  exit 1
fi
exit 0
