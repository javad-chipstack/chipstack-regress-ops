import sys
import os
from pygments import highlight
from pygments.lexers import SystemVerilogLexer
from pygments.formatters import HtmlFormatter
from pygments.styles import get_style_by_name

def convert_systemverilog_to_html(input_file, output_file=None, style_name="default"):
    """
    Convert a SystemVerilog file to HTML with syntax highlighting.
    
    Args:
        input_file (str): Path to the SystemVerilog file
        output_file (str, optional): Path to save the HTML output. If not provided,
                                    will use input filename with .html extension
        style_name (str, optional): Pygments style name (e.g., "default", "monokai", 
                                   "vs", "colorful", etc.)
    
    Returns:
        str: Path to the created HTML file
    """
    # Set default output file if not provided
    if output_file is None:
        base_name = os.path.splitext(input_file)[0]
        output_file = f"{base_name}.html"
    
    # Read the SystemVerilog file
    try:
        with open(input_file, 'r') as f:
            code = f.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        return None
    
    # Get the style
    try:
        style = get_style_by_name(style_name)
    except Exception:
        print(f"Style '{style_name}' not found. Using default style.")
        style = get_style_by_name("default")
    
    # Create HTML formatter with the selected style
    formatter = HtmlFormatter(
        full=True,
        style=style,
        linenos=True,
        title=os.path.basename(input_file)
    )
    
    # Highlight the code
    highlighted_code = highlight(code, SystemVerilogLexer(), formatter)
    
    # Write the HTML output
    try:
        with open(output_file, 'w') as f:
            f.write(highlighted_code)
        print(f"Successfully converted {input_file} to {output_file}")
        return output_file
    except Exception as e:
        print(f"Error writing output file: {e}")
        return None

def main():
    # Check command line arguments
    if len(sys.argv) < 2:
        print("Usage: python systemverilog_to_html.py <input_file> [output_file] [style_name]")
        print("Available styles: default, monokai, emacs, friendly, colorful, vs, tango, etc.")
        return
    
    input_file = sys.argv[1]
    
    # Get optional output file and style
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    style_name = sys.argv[3] if len(sys.argv) > 3 else "default"
    
    # Convert the file
    convert_systemverilog_to_html(input_file, output_file, style_name)

if __name__ == "__main__":
    main()