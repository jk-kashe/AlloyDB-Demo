import psycopg2
from datetime import datetime

# AlloyDB connection details (replace with your actual values)
conn = psycopg2.connect(
    host="10.34.1.2",
    database="ssb",
    user="postgres",
    password="sarunsingla"
)

cursor = conn.cursor()

# Create the table (if it doesn't exist)
cursor.execute("""
CREATE TABLE IF NOT EXISTS query_results (
    id SERIAL PRIMARY KEY,
    revenue NUMERIC,
    execution_time INTEGER,
    query_runtime INTEGER
)
""")

# Create a cursor object to interact with the database
cursor = conn.cursor()

# Function to process each block of data from the file

def process_data_block(data_block):
    lines = data_block.splitlines()
    #print(lines)
    if len(lines) >= 6:  # Ensure we have at least 3 lines
        revenue_line = lines[0].strip()  # Get the 3rd line and remove whitespace
        execution_time = lines[3].strip()
        run_time = lines[4].strip()
        if revenue_line and execution_time and run_time:  # Check if the line is not empty
            try:
                revenue_value = int(revenue_line)  # Convert to integer, assuming it's an integer value
                execution_time = int(execution_time)
                query_run_time = int(run_time) 
                # Insert the revenue value into the AlloyDB table
                
                cursor.execute("""
        INSERT INTO query_results (revenue, execution_time, query_runtime)
        VALUES (%s, %s, %s)
        """, (revenue_value, execution_time, run_time))
            except ValueError:
                print()
   #             print(f"Skipping data block with non-numeric revenue value: {data_block}")
        else:
            print()
            #print(f"Skipping data block with empty revenue line: {data_block}")
    else:
        print(f"Skipping invalid data block: {data_block}")



# Open the file containing the data
with open('sample-data.txt', 'r') as file:
    data_block = ''
    for line in file:
        if line.startswith('---'):  # Separator between data blocks
            if data_block:
                process_data_block(data_block)
                data_block = ''
        else:
            data_block += line

    # Process the last data block if any
    if data_block:
        process_data_block(data_block)

# Commit the changes to the database
conn.commit()

# Close the cursor and the database connection
cursor.close()
conn.close()

print("Data successfully inserted into AlloyDB table!")

