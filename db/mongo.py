import sys
import pandas as pd
from pymongo import MongoClient
from datetime import datetime
from bson import ObjectId
from tabulate import tabulate
import pytz
from pytz import timezone, UTC


# MongoDB setup
def get_mongo_collection():
    client = MongoClient("mongodb://jenkins:jenkins@localhost:29756/")
    db = client["jenkins_db"]
    return db["kpi_data"]


# Get current time in PDT
def get_pdt_now():
    tz = pytz.timezone("America/Los_Angeles")
    return datetime.now(tz)


# Upload CSV to MongoDB
def upload_csv_to_mongodb(csv_file, branch_name, run_type, commit_id):
    collection = get_mongo_collection()

    # Read CSV
    try:
        df = pd.read_csv(csv_file)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    # Add metadata
    now = get_pdt_now()
    df["branch"] = branch_name
    df["run_type"] = run_type
    df["timestamp"] = now
    df["commit_id"] = commit_id

    # Insert
    data = df.to_dict(orient="records")
    result = collection.insert_many(data)
    print(f"Inserted {len(result.inserted_ids)} documents into MongoDB.")


# Dump all data from MongoDB as a table
# Dump all data from MongoDB as a table
def dump_database():

    collection = get_mongo_collection()
    docs = list(collection.find())

    if not docs:
        print("No documents found in the database.")
        return

    pdt = timezone("America/Los_Angeles")
    rows = []
    for doc in docs:
        row = {}
        for k, v in doc.items():
            if isinstance(v, ObjectId):
                row[k] = str(v)
            elif isinstance(v, datetime):
                # Step 1: localize to UTC (if naive)
                if v.tzinfo is None:
                    v = UTC.localize(v)
                # Step 2: convert to PDT
                v_pdt = v.astimezone(pdt)
                row["timestamp_pdt"] = v_pdt.strftime("%Y-%m-%d %H:%M:%S %Z")
            else:
                if k != "timestamp":  # skip the raw timestamp field
                    row[k] = v
        rows.append(row)

    print(tabulate(rows, headers="keys", tablefmt="fancy_grid"))


# Command line interface
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print(
            "  python db/mongo.py insert <csv_file_path> <branch_name> <run_type> <commit_id>"
        )

        print("  python db/mongo.py dump")
    elif sys.argv[1] == "insert" and len(sys.argv) == 6:
        upload_csv_to_mongodb(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif sys.argv[1] == "dump":
        dump_database()
    else:
        print("Invalid command or arguments.")
