## AlloyDB 
AlloyDB is a fully managed, PostgreSQL-compatible database service on Google Cloud. It's designed to handle demanding enterprise workloads that require high performance, scalability, and availability. 
Think of it as PostgreSQL, supercharged!
### Columnar Engine
AlloyDB's columnar engine dramatically speeds up analytical queries by storing data in a columnar format, unlike traditional row-based databases. 
This means all the values for a single column are stored together, making it much more efficient for analytical queries that typically scan many rows but only require a few columns.  
Furthermore, it keeps frequently used data in memory and uses machine learning to automatically select the columns that benefit most from this format, eliminating manual tuning.  
Seamlessly integrated with AlloyDB's PostgreSQL engine, it allows you to run analytical queries using standard SQL, with AlloyDB automatically utilizing the columnar engine when it provides a performance advantage.

### AlloyDB and Looker Setup Instructions
* Create an AlloyDB primary instance 4 cpu 32GB and a read pool instance.
  * Get the private IP address
* Create a client VM under “Compute Engine” in the cloud console to run scripts and setup AlloyDB Auth proxy.
  * Create a firewall rule to allow connections
    * VPC network->firewall->Create firewall rule
      * Give a name 
      * Targets -> all instances in network
      * Source IPV4 ranges - 0.0.0.0/0
      * Protocols and ports - allow all
      * Create
  Remember to allowlist the IP of the VM in AlloyDB allowed instances on the read pool.
  Try ssh to the client VM. Might take a few minutes for the above firewall rule to kick in.
* Once ssh’d into the client VM, install the modules on the client VM and the postgresql client.
* Download the github to run star schema Benchmark
  * git clone https://github.com/swarm64/s64da-benchmark-toolkit
* Now run the below command to Setup before connecting and generate the required data.
   * `cd s64da-benchmark-toolkit` 
   * ``./prepare_benchmark  --dsn postgresql://postgres@<IP of the primary alloyDB Instance>/ssb --benchmark=ssb --schema=psql_native --scale-factor=1000``
   * Follow the above command and other steps on the benchmark toolkit to generate ssb 
 	database in AlloyDB.
* To build a Looker dashboard we need to run AlloyDb Auth Proxy on the VM created. Download the Auth Proxy client
   * `wget https://storage.googleapis.com/alloydb-auth-proxy/v1.10.2/alloydb-auth-proxy.linux.amd64 -O alloydb-auth-proxy`
* Run the AlloyDB Auth Proxy client on the VM
   * `./alloydb-auth-proxy <Connection URI for the primary/read instance> --credentials-file service_account.json --address "<public IP of the instance>" -p 5433 --auto-iam-authn`

### Running the Benchmark Scripts
* Clone the repo here to start running the benchmark scripts
  `git clone https://github.com/sarunsingla11722/AlloyDB-Demo.git`
#### We have a few custom scripts here:
* **Insertpg.sql** - insert loop that adds orders into the PG database. 
* **alloy-table-looker.py** - Creates query_results table in AlloyDB and stores the real time query runtimes.
* **alloyDB-query.sh** -The script begins by dropping any existing columnar storage optimizations for the 'lineorder' table and resetting any columnar storage recommendations. It then enters a loop, executing the query 100,000 times and recording each execution time. On the first iteration, it also triggers a background process to generate recommendations for columnar storage optimization based on the query workload.The script's output includes the execution time for each query run and timestamps, which can be used to analyze performance trends and identify potential bottlenecks or areas for improvement.

##### Order of Execution
* Order of Operations for Executing Scripts
  * Execute the **insertpg.sql** script to initiate data insertion
  * Execute the alloyDB-query.sh script concurrently in a separate terminal window.
  * Concurrently with the execution of both scripts, it is recommended to initiate the Python script obtained from the aforementioned GitHub repository. This      action will facilitate the creation of a query_results table within AlloyDB, which will subsequently be utilized by Looker for the purpose of
    dashboarding the results.
    `alloyDB-demo$ for i in {1..10};do echo $i; python alloy-table-looker.py;sleep 4;done`

### Looker Dashboard
* Looker Setup
<img width="569" alt="Screenshot 2024-12-11 at 21 52 29" src="https://github.com/user-attachments/assets/4534a758-0754-47f8-a4fb-57be8d8d02b4">
