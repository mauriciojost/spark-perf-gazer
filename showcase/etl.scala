// Simple Spark ETL with 3 jobs of significantly different durations
// Each job uses setJobDescription so PerfGazer can track it

import org.apache.spark.sql.SparkSession
import java.io.{File, PrintWriter}

val spark = SparkSession.builder().getOrCreate()
import spark.implicits._

sc.setLogLevel("INFO")

// ============================================================
// Job 1: Light transformation (~few seconds)
// Simple filter + projection on a small dataset
// ============================================================
sc.setJobDescription("Job 1: Light filter on small dataset")
spark.range(0, 500000)
  .filter($"id" % 2 === 0)
  .selectExpr("id", "id * 2 as doubled")
  .write.mode("overwrite").parquet("/tmp/showcase_etl/job1_output")

// ============================================================
// Job 2: Medium transformation (~moderate duration)
// Aggregation with shuffle on a larger dataset
// ============================================================
sc.setJobDescription("Job 2: Aggregation with shuffle on medium dataset")
spark.range(0, 5000000)
  .selectExpr("id", "id % 100 as group_key", "id * rand() as value")
  .groupBy("group_key")
  .agg(
    org.apache.spark.sql.functions.count("*").as("cnt"),
    org.apache.spark.sql.functions.sum("value").as("total_value"),
    org.apache.spark.sql.functions.avg("value").as("avg_value")
  )
  .write.mode("overwrite").parquet("/tmp/showcase_etl/job2_output")

// ============================================================
// Job 3: Heavy transformation (~longest duration)
// Large self-join + aggregation causing significant shuffle and CPU
// ============================================================
sc.setJobDescription("Job 3: Heavy self-join on large dataset")
val large = spark.range(0, 50000)
  .selectExpr("id", "id % 500 as join_key", "id * rand() as metric")

large.as("a")
  .join(large.as("b"), $"a.join_key" === $"b.join_key")
  .groupBy($"a.join_key")
  .agg(
    org.apache.spark.sql.functions.count("*").as("pair_count"),
    org.apache.spark.sql.functions.sum($"a.metric").as("sum_a"),
    org.apache.spark.sql.functions.sum($"b.metric").as("sum_b")
  )
  .write.mode("overwrite").parquet("/tmp/showcase_etl/job3_output")

// ============================================================
// Write PerfGazer snippets to showcase/output.md
// ============================================================
def writeSnippetsToFile(outputPath: String): Unit = {
  import com.amadeus.perfgazer.PerfGazer
  val pg = PerfGazer.instance.getOrElse(throw new RuntimeException("PerfGazer not found"))
  val snippets = pg.getSnippets

  val writer = new PrintWriter(new File(outputPath))
  try {
    writer.println("# PerfGazer Snippets")
    writer.println()
    writer.println("SQL snippets to create views over PerfGazer JSON reports.")
    writer.println()
    writer.println("```sql")
    snippets.foreach { s =>
      writer.println(s)
      writer.println()
    }
    writer.println("```")
  } finally {
    writer.close()
  }
  println(s"PerfGazer snippets written to $outputPath")
}

writeSnippetsToFile("showcase/output.md")

System.exit(0)
