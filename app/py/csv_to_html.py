import csv
import os
import sys
import re

def is_numeric(value):
    """Check if a value can be converted to a float."""
    # Check if the value is 'n/a' or any variation of it
    if isinstance(value, str) and value.lower().strip() in ['n/a', 'na', 'n/a', 'not available', '']:
        return False
    
    try:
        float(value)
        return True
    except (ValueError, TypeError):
        return False

def extract_percentage(value):
    """Extract percentage value from string and convert to float."""
    if isinstance(value, str):
        # Remove any non-numeric characters except dots
        match = re.search(r'(\d+(?:\.\d+)?)', value)
        if match:
            return float(match.group(1))
    return None

def is_percentage_column(header):
    """Determine if a column should be treated as a percentage."""
    percentage_keywords = ['percent', 'percentage', 'coverage', '%']
    return any(keyword.lower() in header.lower() for keyword in percentage_keywords)

def calculate_summary_row(rows, headers):
    """Calculate sums or averages for columns."""
    summary = []
    
    for col_idx, header in enumerate(headers):
        # Extract all values from this column
        column_values = [row[col_idx] for row in rows]
        
        # If it's the first column (usually labels/names)
        if col_idx == 0:
            summary.append("<strong>Summary</strong>")
            continue
            
        # If it's a percentage column, calculate average
        if is_percentage_column(header):
            # Extract percentages from values that have them
            numeric_values = []
            for val in column_values:
                if isinstance(val, str) and val.lower() in ['n/a', 'na', 'not available', '']:
                    continue
                percentage = extract_percentage(val) if isinstance(val, str) else val
                if percentage is not None and is_numeric(str(percentage)):
                    numeric_values.append(float(percentage))
            
            if numeric_values:
                avg = sum(numeric_values) / len(numeric_values)
                if header.lower() == 'total coverage':
                    summary.append(f"{avg:.2f}%")
                else:
                    summary.append(f"{avg:.2f}")
            else:
                summary.append("")
        else:
            # For non-percentage columns, calculate sum
            numeric_values = [float(val) for val in column_values if is_numeric(val)]
            
            if numeric_values:
                total = sum(numeric_values)
                # Format to integer if it's a whole number, otherwise 2 decimal places
                if total.is_integer():
                    summary.append(f"{int(total)}")
                else:
                    summary.append(f"{total:.2f}")
            else:
                summary.append("")
            
    return summary

def csv_to_html(csv_file_path):
    # Check if the file exists
    if not os.path.isfile(csv_file_path):
        print(f"Error: The file {csv_file_path} does not exist.")
        return

    # Try reading the CSV file using the csv module
    try:
        with open(csv_file_path, mode='r', newline='', encoding='utf-8') as csv_file:
            reader = csv.reader(csv_file)
            headers = next(reader)  # Read the header row
            rows = list(reader)     # Read all the remaining rows
    except Exception as e:
        print(f"Error reading the CSV file: {e}")
        return

    # Calculate summary row (sums or averages depending on column type)
    summary_row = calculate_summary_row(rows, headers)

    # Generate the HTML table with elegant styling
    html_table = '<div class="table-container">\n'
    html_table += '<table class="elegant-table">\n'
    
    # Adding table headers
    html_table += "<thead><tr>"
    for header in headers:
        html_table += f'<th>{header}</th>'
    html_table += "</tr></thead>\n"
    
    # Adding table body
    html_table += "<tbody>\n"
    for row in rows:
        html_table += "<tr>"
        for cell in row:
            html_table += f"<td>{cell}</td>"
        html_table += "</tr>\n"
    
    # Add the summary row with special styling
    html_table += '<tr class="summary-row">'
    for idx, value in enumerate(summary_row):
        html_table += f'<td>{value}</td>'
    html_table += "</tr>\n"
    
    html_table += "</tbody>\n"
    html_table += "</table>\n"
    html_table += "</div>"

    # Create CSS with summary row styling
    css_style = """
    <style>
        .table-container {
            margin: 1.5rem auto;
            max-width: 95%;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
            border-radius: 8px;
            overflow: hidden;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .elegant-table {
            border-collapse: collapse;
            width: 100%;
            background: white;
            overflow: hidden;
        }
        
        .elegant-table thead {
            background-color: #e0e0e0;
            color: #333;
        }
        
        .elegant-table th {
            padding: 0.6rem 1rem;
            text-align: left;
            font-weight: 600;
            border-bottom: 1px solid rgba(0, 0, 0, 0.1);
        }
        
        .elegant-table td {
            padding: 0.5rem 1rem;
            vertical-align: middle;
            border-bottom: 1px solid rgba(0, 0, 0, 0.05);
        }
        
        .elegant-table tbody tr {
            transition: background-color 0.3s ease;
        }
        
        .elegant-table tbody tr:nth-child(even) {
            background-color: #f9fafb;
        }
        
        .elegant-table tbody tr:hover {
            background-color: rgba(0, 0, 0, 0.03);
        }
        
        .summary-row {
            background-color: #f0f5ff !important;
            border-top: 2px solid #d0d0d0;
            font-weight: 500;
        }
        
        .summary-row:hover {
            background-color: #e6eeff !important;
        }
        
        @media (max-width: 768px) {
            .elegant-table th, .elegant-table td {
                padding: 0.4rem 0.5rem;
            }
        }
        
        body {
            background-color: #f5f7fa;
            padding: 15px;
            margin: 0;
        }
        
        h1 {
            margin-top: 1rem;
            margin-bottom: 1rem;
            font-size: 1.5rem;
        }
    </style>
    """

    # Create the final HTML content
    html_content = f"""<!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Data Table</title>
        {css_style}
    </head>
    <body>
        <h1 style="text-align: center; color: #333; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
            {os.path.basename(csv_file_path).split('.')[0].replace('_', ' ').title()}
        </h1>
        {html_table}
    </body>
    </html>"""

    # Determine the output file path
    output_file_path = os.path.splitext(csv_file_path)[0] + "_table.html"
    
    try:
        # Save the HTML content to the same directory as the original CSV
        with open(output_file_path, 'w', encoding='utf-8') as html_file:
            html_file.write(html_content)
        print(f"HTML table with summary row saved successfully: {output_file_path}")
    except Exception as e:
        print(f"Error saving the HTML file: {e}")

def main():
    # Check if the user provided a file path
    if len(sys.argv) != 2:
        print("Usage: python csv_to_html.py <path_to_csv_file>")
        sys.exit(1)

    csv_file_path = sys.argv[1]
    csv_to_html(csv_file_path)

if __name__ == "__main__":
    main()