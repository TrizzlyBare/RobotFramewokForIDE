#!/usr/bin/env python3
"""
Helper module for JSON processing in Robot Framework tests
"""

import json
import sys
import os


def read_json_file(file_path):
    """
    Read and parse a JSON file, returning individual fields that Robot can use directly
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # Extract the code fields specifically
        if "defaultcode" in data:
            html = data["defaultcode"].get("html", "")
            css = data["defaultcode"].get("css", "")
            js = data["defaultcode"].get("js", "")

            # Save to temp files that Robot can read directly
            temp_dir = os.path.join(os.path.dirname(file_path), "temp")
            os.makedirs(temp_dir, exist_ok=True)

            base_name = os.path.basename(file_path).split(".")[0]
            html_path = os.path.join(temp_dir, f"{base_name}_html.txt")
            css_path = os.path.join(temp_dir, f"{base_name}_css.txt")
            js_path = os.path.join(temp_dir, f"{base_name}_js.txt")

            with open(html_path, "w", encoding="utf-8") as f:
                f.write(html)
            with open(css_path, "w", encoding="utf-8") as f:
                f.write(css)
            with open(js_path, "w", encoding="utf-8") as f:
                f.write(js)

            # Return paths to the files
            return {"html_path": html_path, "css_path": css_path, "js_path": js_path}
        else:
            print(f"Error: 'defaultcode' not found in {file_path}")
            sys.exit(1)
    except Exception as e:
        print(f"Error reading JSON file {file_path}: {str(e)}")
        sys.exit(1)


def write_json_file(data, file_path):
    """
    Write JSON data to file
    """
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        print(f"Error writing JSON file {file_path}: {str(e)}")
        return False


if __name__ == "__main__":
    # This script can be run directly from command line
    # Usage: python json_helper.py extract <file_path>
    if len(sys.argv) < 3:
        print("Usage: python json_helper.py extract <file_path>")
        sys.exit(1)

    command = sys.argv[1]
    file_path = sys.argv[2]

    if command == "extract":
        result = read_json_file(file_path)
        print(f"HTML_PATH:{result['html_path']}")
        print(f"CSS_PATH:{result['css_path']}")
        print(f"JS_PATH:{result['js_path']}")
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
