# AlloyDB Demo: Read Pools and Columnar Engine

## AlloyDB Overview

AlloyDB for PostgreSQL is a fully managed, PostgreSQL-compatible database service available on Google Cloud. It's specifically engineered to handle demanding, enterprise-grade workloads that require exceptional performance, high availability, and seamless scalability.

Think of it as PostgreSQL, significantly enhanced for performance and manageability.

### Key Feature: Integrated Columnar Engine

AlloyDB features an integrated columnar engine designed to dramatically accelerate analytical query performance. Here's how it works:

* **Efficient Data Storage:** Unlike traditional row-based storage, the columnar engine stores all values for a single column contiguously. This drastically reduces the I/O required for analytical queries that typically scan many rows but only need data from a few specific columns.
* **Intelligent Caching:** Frequently accessed data is automatically kept in a fast, in-memory cache.
* **ML-Powered Optimization:** Machine learning algorithms automatically determine which data benefits most from the columnar format and caching, eliminating the need for manual tuning.
* **Seamless Integration:** The columnar engine works transparently alongside AlloyDB's standard PostgreSQL query processing. You continue to use standard SQL, and AlloyDB automatically routes queries (or parts of queries) to the columnar engine whenever it provides a performance benefit.

## Purpose of this Demo

This demonstration showcases two key capabilities of AlloyDB:

1.  **Read Pool Isolation:** How utilizing AlloyDB Read Pools allows heavy analytical queries to run without impacting the write performance of the primary instance.
2.  **Columnar Engine Acceleration:** How the integrated columnar engine significantly speeds up analytical queries, leading to a better user experience for data analysis tasks.

---

***Important Note on Demo Scope:***

*This demo focuses on illustrating Read Pool isolation under write load and the analytical query acceleration provided by the Columnar Engine.*
*Demonstrating the Columnar Engine's performance characteristics during simultaneous, heavy insert operations *into the exact same table* being queried analytically is **not** currently in the scope of this specific demo.*
*To keep the demonstration clear and focused, the write load script (`insert.sh`) targets a separate table (e.g., `lineorder2`), while the analytical queries (`alloyDB-query.sh`) primarily run against a larger, pre-populated table.*

---

## Prerequisites

* An AlloyDB instance provisioned using the setup found at: [https://github.com/jk-kashe/gcp-database-demos/](https://github.com/jk-kashe/gcp-database-demos/)
* Access to the `alloydb-client` VM (or a similarly configured environment) associated with your AlloyDB instance.
* The IP address of your AlloyDB instance's **Read Pool**.
* Three separate terminal/console sessions connected to the `alloydb-client`.

## Setup Instructions

1.  Connect to your `alloydb-client` environment using the provided script:
    ```bash
    ./gcp-database-demos/alloydb/cymbal-air/alloydb-client.sh
    ```

2.  In your `alloydb-client` session, create a directory for the demo, clone the repository, and navigate into it:
    ```bash
    # Note: 'mk demo' might be a custom alias in your environment.
    # If not, use 'mkdir demo':
    # mkdir demo
    mk demo
    cd demo
    git clone [https://github.com/jk-kashe/AlloyDB-Demo](https://github.com/jk-kashe/AlloyDB-Demo)
    cd AlloyDB-Demo
    ```

3.  Make the demo scripts executable:
    ```bash
    chmod +x *.sh
    ```

4.  Run the initial setup script:
    ```bash
    ./setup.sh
    ```

## Demonstrating Read Pool Benefits

**Goal:** Show how read traffic impacts the primary instance and how a read pool mitigates this.

**(Requires 3 separate console sessions connected to `alloydb-client`, all within the `AlloyDB-Demo` directory)**

Note: run below line to init your shell(s)

```bash
~/source pgauth.env
```

1.  **Console 1 (Start Write Load):**
    * **Action:** Begin simulating continuous data ingestion (e.g., new orders) by running parallel insert workers against the primary instance.
    ```bash
    ./parallel.sh ./insert.sh
    ```
    * *Keep this running in the background.*

2.  **Console 2 (Benchmark Writes - Baseline):**
    * **Action:** Start the benchmark script to measure the current insert rate on the primary instance.
    ```bash
    ./insert_benchmark.sh
    ```
    * **Observe:** Note the initial median rows added per second. This is your baseline write performance.

3.  **Console 3 (Start Read Load - *Against Primary*):**
    * **Action:** Simulate multiple concurrent analytical clients querying the *primary* instance directly.
    ```bash
    # Ensure PGHOST is pointing to the PRIMARY instance IP (default after setup)
    ./parallel.sh ./alloyDB-query.sh
    ```
    * **Explain:** "We are now running analytical queries (like those potentially generated by BI tools or even GenAI applications) directly against the primary database node, simulating concurrent users." *(You can show the `alloyDB-query.sh` content if needed).*

4.  **Console 2 (Benchmark Writes - Impact):**
    * **Observe:** Watch the median rows added per second. You should see a significant drop in performance.
    * *(Optional: Ctrl+C and restart `./insert_benchmark.sh` to get more current numbers as performance degrades).*
    * **Highlight:** "Notice how the write performance has dropped significantly. The primary instance is now struggling to handle both the inserts and the heavy analytical queries concurrently."

5.  **Console 3 (Redirect Read Load - *To Read Pool*):**
    * **Action:** Stop the analytical query load (Ctrl+C). Then, redirect the query load to the dedicated Read Pool instance by setting the `PGHOST` environment variable.
    * **Replace `YOUR_READ_POOL_IP` with the actual IP address of your AlloyDB Read Pool.**
    ```bash
    # Stop the previous command (Ctrl+C)
    export PGHOST="YOUR_READ_POOL_IP"
    ./parallel.sh ./alloyDB-query.sh
    ```
    * **Explain:** "We've stopped hitting the primary instance with reads. Now, we're running the exact same analytical queries, but directing them to a separate AlloyDB Read Pool instance, which is designed for this purpose."

6.  **Console 2 (Benchmark Writes - Recovery):**
    * **Observe:** Watch the median rows added per second again. Performance should recover and climb back towards the initial baseline observed in Step 2.
    * *(Optional: Ctrl+C and restart `./insert_benchmark.sh` to see the recovered performance clearly).*
    * **Highlight:** "As you can see, the write performance on the primary instance has recovered. By offloading the read-heavy analytical workload to the Read Pool, we've freed up the primary instance to focus on its critical task – ingesting new data efficiently."

## Demonstrating Columnar Engine Benefits

**Goal:** Show how the Columnar Engine improves analytical query performance against the main data table.

**(Continue using Console 3, which should still have `PGHOST` set to your Read Pool IP)**

1.  **Console 3 (Run Query - Baseline on Read Pool):**
    * **Action:** If the parallel query script is still running from the previous step, stop it (Ctrl+C). Now, run the *single* analytical query script against the main table (e.g., `lineorder`) to measure its baseline performance on the read pool.
    ```bash
    # Ensure PGHOST is still set to YOUR_READ_POOL_IP
    ./alloyDB-query.sh
    ```
    * **Observe:** Note the "Median Response Time" reported by the script.
    * **Explain:** "Okay, we've isolated our reads to the Read Pool, which protects the primary, but look at this query response time against our main table. For an interactive dashboard or application, this could lead to a poor user experience. How can we make this faster?"

2.  **Console 3 (Identify Columnar Engine Candidates):**
    * **Action:** Use AlloyDB's built-in advisor to recommend which columns in the queried table (`lineorder`) would benefit from being added to the columnar store.
    ```bash
    # Option 1: Using the script flag (if implemented in alloyDB-query.sh)
    ./alloyDB-query.sh --ce_recommend

    # Option 2: Running the SQL command directly (e.g. in psql/AlloyDB Studio)
    # psql -c "SELECT google_columnar_engine_recommend('lineorder');"
    ```
    * **Explain:** "AlloyDB includes tools to help us optimize. This function analyzes query patterns and recommends columns that are good candidates for the Columnar Engine for the specified table."

3.  **Console 3 (Apply Recommendations / Verify Setup):**
    * **Explain:** "Based on these recommendations, we would typically add the suggested columns to the Columnar Engine using `ALTER TABLE lineorder ADD COLUMN column_name WITH (columnar = true);`. In this demo environment, the `./setup.sh` script likely already added the relevant columns from the `lineorder` table to the columnar store based on the expected query patterns. So, the necessary columns should already be managed by the Columnar Engine."
    * *(Note: If setup didn't add them, you would need an explicit step here or another script `enable_ce.sh` to run the `ALTER TABLE` commands based on the recommendations).*

4.  **Console 3 (Run Query - With Columnar Engine):**
    * **Action:** Re-run the same single analytical query script as in Step 1.
    ```bash
    # Ensure PGHOST is still set to YOUR_READ_POOL_IP
    ./alloyDB-query.sh
    ```
    * **Observe:** Note the "Median Response Time" again. It should be significantly lower (faster) than the baseline measured in Step 1.
    * **Highlight:** "Look at the difference! By leveraging the Columnar Engine for the analytical query (which AlloyDB does automatically when beneficial for columns added to the store), the response time is drastically reduced. This demonstrates how the Columnar Engine accelerates analytics and improves user experience, without requiring changes to the SQL query itself."

