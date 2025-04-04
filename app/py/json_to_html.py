import json
import html
import sys
import os
from pygments import highlight
from pygments.lexers import JsonLexer
from pygments.formatters import HtmlFormatter
from pygments.styles import get_all_styles

def json_to_html(json_string, title="JSON Viewer", color_theme="monokai"):
    """
    Convert JSON string to a standalone HTML page with colorful syntax highlighting.
    
    Args:
        json_string (str): The JSON string to convert.
        title (str): Title for the HTML page.
        color_theme (str): Color theme to use (must be a valid Pygments theme).
        
    Returns:
        str: HTML string with syntax-highlighted JSON.
    """
    try:
        # Validate if the chosen style is available
        available_styles = set(get_all_styles())
        if color_theme not in available_styles:
            color_theme = "monokai"  # Default theme if invalid
        
        # Parse and reformat JSON
        parsed_json = json.loads(json_string)
        formatted_json = json.dumps(parsed_json, indent=2, sort_keys=False)
        
        # Set up Pygments formatter with inline styles
        formatter = HtmlFormatter(style=color_theme, linenos=False, noclasses=True)
        
        # Highlight the JSON content
        highlighted_json = highlight(formatted_json, JsonLexer(), formatter)

        # Define color themes for background and headings
        dark_themes = {"monokai", "native", "dracula", "vim", "fruity", "gruvbox-dark"}
        if color_theme in dark_themes:
            page_bg = "#282828"
            container_bg = "#383838"
            heading_color = "#f8f8f2"
        else:
            page_bg = "#f5f5f5"
            container_bg = "#ffffff"
            heading_color = "#333333"

        # Generate HTML
        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html.escape(title)}</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: {page_bg};
        }}
        .container {{
            max-width: 900px;
            margin: 0 auto;
            background-color: {container_bg};
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }}
        h1 {{
            color: {heading_color};
            text-align: center;
        }}
        .json-container {{
            padding: 15px;
            border-radius: 8px;
            overflow-x: auto;
            font-family: 'Courier New', Courier, monospace;
            font-size: 14px;
            line-height: 1.5;
            white-space: pre-wrap;       /* CSS3 */
            word-wrap: break-word;       /* Internet Explorer */
        }}
        .json-container span {{
            white-space: pre-wrap !important;  /* Override any inline styles */
            word-break: break-word !important;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>{html.escape(title)}</h1>
        <div class="json-container">
            {highlighted_json}
        </div>
    </div>
</body>
</html>"""
        
        return html_content

    except json.JSONDecodeError as e:
        return f"<p>Error parsing JSON: {e}</p>"
    except Exception as e:
        return f"<p>Error: {e}</p>"


def main():
    """Process a JSON file and write an HTML file in the same directory."""
    # Check if a filename was provided
    if len(sys.argv) < 2:
        print("Usage: python script.py <json_file> [title] [color_theme]")
        print("\nAvailable color themes:")
        print(", ".join(list(get_all_styles())))
        sys.exit(1)
    
    # Get the input file path
    input_file = sys.argv[1]
    
    # Get optional arguments
    title = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(input_file)
    color_theme = sys.argv[3] if len(sys.argv) > 3 else "monokai"
    
    try:
        # Read the JSON file
        with open(input_file, 'r', encoding='utf-8') as f:
            json_content = f.read()
        
        # Convert JSON to HTML
        html_content = json_to_html(json_content, title, color_theme)
        
        # Create output filename in the same directory
        file_name = os.path.splitext(os.path.basename(input_file))[0]
        output_path = os.path.join(os.path.dirname(input_file), f"{file_name}.html")
        
        # Write the HTML to a file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"HTML file created successfully: {output_path}")
        
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()