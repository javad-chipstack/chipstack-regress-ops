import sys
import pandas as pd
from pymongo import MongoClient
from datetime import datetime
from bson import ObjectId
from tabulate import tabulate
import pytz
from pytz import timezone, UTC
import json
import webbrowser
import os
import requests
from pprint import pprint
import argparse


# MongoDB setup
def get_mongo_collection():
    client = MongoClient("mongodb://jenkins:jenkins@localhost:29756/")
    db = client["jenkins_db"]
    return db["kpi_data"]


# Get current time in PDT
def get_pdt_now():
    tz = pytz.timezone("America/Los_Angeles")
    return datetime.now(tz)


# Plot metrics for Simulation run_type and main branch
def plot_simulation_metrics():
    collection = get_mongo_collection()
    query = {"run_type": "Simulation", "branch": "main"}
    projection = {
        "Design Name": 1,
        "Scenarios Generated": 1,
        "Scenarios w/ Syntax Errors After First Generation": 1,
        "Scenarios w/ Syntax Errors Remaining": 1,
        "Passed Scenarios": 1,
        "Failed Scenarios": 1,
        "Percent Scenarios Passed": 1,
        "Percent Scenarios Failed": 1,
        "Total Coverage": 1,
        "timestamp": 1,
    }
    docs = list(collection.find(query, projection))

    if not docs:
        print("No matching documents found.")
        return

    data = {}
    for doc in docs:
        design_name = doc.get("Design Name", "Unknown")
        if design_name not in data:
            data[design_name] = {}

        metrics = {
            "Scenarios Generated": doc.get("Scenarios Generated", 0),
            "Passed Scenarios": doc.get("Passed Scenarios", 0),
            "Failed Scenarios": doc.get("Failed Scenarios", 0),
            "Syntax Errors After First Gen": doc.get(
                "Scenarios w/ Syntax Errors After First Generation", 0
            ),
            "Syntax Errors Remaining": doc.get(
                "Scenarios w/ Syntax Errors Remaining", 0
            ),
            "Percent Scenarios Passed": doc.get("Percent Scenarios Passed", 0.0),
            "Percent Scenarios Failed": doc.get("Percent Scenarios Failed", 0.0),
            "Total Coverage": float(
                str(doc.get("Total Coverage", "0")).replace("%", "")
            ),
            "timestamp": doc.get("timestamp", "Unknown"),
        }

        for metric, value in metrics.items():
            if metric not in data[design_name]:
                data[design_name][metric] = []
            timestamp = doc.get("timestamp", "Unknown")
            data[design_name][metric].append((timestamp, value))

    # pprint (docs)
    pprint(data)
    sys.exit(0)

    # Print data in a tabular format
    for design_name, metrics in data.items():
        print(f"Design Name: {design_name}")
        table = []
        for metric, timestamps in metrics.items():
            for timestamp, value in timestamps.items():
                table.append([metric, timestamp, value])
        print(
            tabulate(
                table, headers=["Metric", "Timestamp", "Value"], tablefmt="fancy_grid"
            )
        )
        print("\n")

    sys.exit(0)

    # Write to HTML using Google Charts
    html_content = f"""
    <html>
      <head>
        <script type="text/javascript" src="loader.js"></script>
        <script type="text/javascript">
          google.charts.load('current', {{'packages':['corechart']}});
          google.charts.setOnLoadCallback(drawCharts);

          function drawCharts() {{
            var rawData = {json.dumps(data)};

            var data = google.visualization.arrayToDataTable(rawData);

            var options = {{
              title: 'Simulation Metrics',
              hAxis: {{ title: 'Design Name' }},
              vAxis: {{ minValue: 0 }},
              chartArea: {{width: '70%', height: '70%'}},
              legend: {{ position: 'top' }}
            }};

            var chart = new google.visualization.ColumnChart(document.getElementById('chart_div'));
            chart.draw(data, options);
          }}
        </script>
      </head>
      <body>
        <h2 style="font-family: sans-serif;">Simulation Metrics Dashboard</h2>
        <div id="chart_div" style="width: 1000px; height: 600px;"></div>
      </body>
    </html>
    """

    output_file = "simulation_metrics.html"
    with open(output_file, "w") as f:
        f.write(html_content)

    print(f"Plot saved to {output_file}")
    webbrowser.open("file://" + os.path.realpath(output_file))

    # Save Google Charts loader.js to the same directory
    loader_js_url = "https://www.gstatic.com/charts/loader.js"
    loader_js_path = os.path.join(os.path.dirname(__file__), "loader.js")

    if not os.path.exists(loader_js_path):
        try:
            response = requests.get(loader_js_url)
            response.raise_for_status()
            with open(loader_js_path, "wb") as f:
                f.write(response.content)
            print(f"Downloaded loader.js to {loader_js_path}")
        except Exception as e:
            print(f"Failed to download loader.js: {e}")
    else:
        print(f"loader.js already exists at {loader_js_path}")


# insert CSV to MongoDB
def insert_csv_to_mongodb(
    csv_file,
    branch_name,
    run_type,
    commit_id,
    commit_description,
    commit_date,
    jenkins_run_id,
):
    collection = get_mongo_collection()

    try:
        df = pd.read_csv(csv_file)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    now = get_pdt_now()
    df["branch"] = branch_name
    df["run_type"] = run_type
    df["timestamp"] = now
    df["commit_id"] = commit_id
    df["commit_description"] = commit_description
    df["commit_date"] = commit_date
    df["jenkins_run_id"] = jenkins_run_id

    data = df.to_dict(orient="records")
    result = collection.insert_many(data)
    print(f"Inserted {len(result.inserted_ids)} documents into MongoDB.")


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
                if v.tzinfo is None:
                    v = UTC.localize(v)
                v_pdt = v.astimezone(pdt)
                row["timestamp"] = v_pdt.strftime("%Y-%m-%d %H:%M:%S %Z")
            else:
                if k != "timestamp":
                    row[k] = v
        rows.append(row)

    print(tabulate(rows, headers="keys", tablefmt="fancy_grid"))


# Command line interface
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MongoDB KPI Data Management Tool")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    
    # Insert command
    insert_parser = subparsers.add_parser("insert", help="Insert CSV data into MongoDB")
    insert_parser.add_argument("--csv-file", required=True, help="Path to CSV file")
    insert_parser.add_argument("--branch-name", required=True, help="Branch name")
    insert_parser.add_argument("--run-type", required=True, help="Run type")
    insert_parser.add_argument("--commit-id", required=True, help="Commit ID")
    insert_parser.add_argument("--commit-description", required=True, help="Commit description")
    insert_parser.add_argument("--commit-date", required=True, help="Commit date")
    insert_parser.add_argument("--jenkins-run-id", required=True, help="Jenkins run ID")
    
    # Dump command
    dump_parser = subparsers.add_parser("dump", help="Dump all data from MongoDB")
    
    # Plot command
    plot_parser = subparsers.add_parser("plot", help="Plot simulation metrics")
    
    args = parser.parse_args()
    
    if args.command == "insert":
        insert_csv_to_mongodb(
            args.csv_file,
            args.branch_name,
            args.run_type,
            args.commit_id,
            args.commit_description,
            args.commit_date,
            args.jenkins_run_id,
        )
    elif args.command == "dump":
        dump_database()
    elif args.command == "plot":
        plot_simulation_metrics()
    elif args.command is None:
        parser.print_help()
    else:
        print("Invalid command.")