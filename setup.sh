echo "this script is intended for use on a cluster provisioned with https://github.com/jk-kashe/gcp-database-demos/"
TARGET_DIR="../s64da-benchmark-toolkit"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Directory '$TARGET_DIR' not found. Cloning repository..."
  git clone https://github.com/swarm64/s64da-benchmark-toolkit "$TARGET_DIR"
else
  echo "Directory '$TARGET_DIR' already exists. Skipping clone."
fi
sudo apt install -y git python3-dateutil python3-natsort python3-pandas python3-psycopg2 python3-tabulate python3-sqlparse

cd ../s64da-benchmark-toolkit
source ~/pgauth.env
./prepare_benchmark  --dsn postgresql://postgres@$PGHOST/ssb --benchmark=ssb --schema=psql_native --scale-factor=10
