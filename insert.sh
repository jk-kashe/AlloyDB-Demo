N=10
DB_NAME="ssb"
source ~/pgauth.env

for (( i=1; i<=N; i++ ))
do
  echo "Starting job $i..."
  psql -d "$DB_NAME" -f ./insertpg.sql &
done
