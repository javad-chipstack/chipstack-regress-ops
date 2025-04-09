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
            "Syntax Errors After First Gen": doc.get("Scenarios w/ Syntax Errors After First Generation", 0),
            "Syntax Errors Remaining": doc.get("Scenarios w/ Syntax Errors Remaining", 0),
            "Percent Scenarios Passed": doc.get("Percent Scenarios Passed", 0.0),
            "Percent Scenarios Failed": doc.get("Percent Scenarios Failed", 0.0),
            "Total Coverage": float(str(doc.get("Total Coverage", "0")).replace('%', '')), 
            "timestamp": doc.get("timestamp", "Unknown")
        }

        for metric, value in metrics.items():
            if metric not in data[design_name]:
                data[design_name][metric] = []
            timestamp = doc.get("timestamp", "Unknown")
            data[design_name][metric].append((timestamp, value))

    # pprint (docs)
    pprint (data)
    sys.exit (0)

    # Print data in a tabular format
    for design_name, metrics in data.items():
        print(f"Design Name: {design_name}")
        table = []
        for metric, timestamps in metrics.items():
            for timestamp, value in timestamps.items():
                table.append([metric, timestamp, value])
        print(tabulate(table, headers=["Metric", "Timestamp", "Value"], tablefmt="fancy_grid"))
        print("\n")

    sys.exit (0)

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


# Upload CSV to MongoDB
def upload_csv_to_mongodb(csv_file, branch_name, run_type, commit_id):
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
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python script.py insert <csv_file_path> <branch_name> <run_type> <commit_id>")
        print("  python script.py dump")
        print("  python script.py plot")
    elif sys.argv[1] == "insert" and len(sys.argv) == 6:
        upload_csv_to_mongodb(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif sys.argv[1] == "dump":
        dump_database()
    elif sys.argv[1] == "plot":
        plot_simulation_metrics()
    else:
        print("Invalid command or arguments.")