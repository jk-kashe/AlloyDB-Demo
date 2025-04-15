DB_NAME="ssb"
source ~/pgauth.env
psql -d "$DB_NAME" -f ./insertpg.sql
