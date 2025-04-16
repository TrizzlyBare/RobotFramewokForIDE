#!/usr/bin/env python3
"""
Helper module for JSON processing in Robot Framework tests
"""

import json
import sys
import os
import re
import difflib
import traceback


def read_json_file(file_path):
    """
    Read and parse a JSON file, returning individual fields that Robot can use directly
    """
    try:
        print(f"Starting to process file: {file_path}")

        if not os.path.exists(file_path):
            print(f"Error: File does not exist: {file_path}")
            sys.exit(1)

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            print(f"Successfully loaded JSON from {file_path}")
        except json.JSONDecodeError as e:
            print(f"JSON parse error in {file_path}: {str(e)}")
            sys.exit(1)
        except Exception as e:
            print(f"Error reading file {file_path}: {str(e)}")
            traceback.print_exc()
            sys.exit(1)

        # Extract the code fields specifically
        if "defaultcode" in data:
            try:
                html = data["defaultcode"].get("html", "")
                css = data["defaultcode"].get("css", "")
                js = data["defaultcode"].get("js", "")
                print(f"Successfully extracted HTML, CSS, and JS content")
            except Exception as e:
                print(f"Error extracting code fields: {str(e)}")
                traceback.print_exc()
                sys.exit(1)

            # Save to temp files that Robot can read directly
            temp_dir = os.path.join(os.path.dirname(file_path), "temp")
            try:
                os.makedirs(temp_dir, exist_ok=True)
                print(f"Created/confirmed temp directory: {temp_dir}")
            except Exception as e:
                print(f"Error creating temp directory {temp_dir}: {str(e)}")
                traceback.print_exc()
                sys.exit(1)

            base_name = os.path.basename(file_path).split(".")[0]
            html_path = os.path.join(temp_dir, f"{base_name}_html.txt")
            css_path = os.path.join(temp_dir, f"{base_name}_css.txt")
            js_path = os.path.join(temp_dir, f"{base_name}_js.txt")

            # Write the files with detailed error handling
            try:
                with open(html_path, "w", encoding="utf-8") as f:
                    f.write(html)
                print(f"Wrote HTML content to {html_path}")

                with open(css_path, "w", encoding="utf-8") as f:
                    f.write(css)
                print(f"Wrote CSS content to {css_path}")

                with open(js_path, "w", encoding="utf-8") as f:
                    f.write(js)
                print(f"Wrote JS content to {js_path}")
            except Exception as e:
                print(f"Error writing extracted files: {str(e)}")
                traceback.print_exc()
                sys.exit(1)

            # Return paths to the files
            result = {"html_path": html_path, "css_path": css_path, "js_path": js_path}
            print(f"Returning file paths: {result}")
            return result
        else:
            print(f"Error: 'defaultcode' not found in {file_path}")
            sys.exit(1)
    except Exception as e:
        print(f"Unexpected error processing {file_path}: {str(e)}")
        traceback.print_exc()
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


def analyze_js_differences(student_js_path, teacher_js_path):
    """
    Analyze JavaScript code and provide specific differences
    """
    try:
        with open(student_js_path, "r", encoding="utf-8") as f:
            student_js = f.read()
        with open(teacher_js_path, "r", encoding="utf-8") as f:
            teacher_js = f.read()

        # List to collect specific differences
        differences = []

        # Check for missing event listeners
        teacher_events = re.findall(r'addEventListener\([\'"](\w+)[\'"]', teacher_js)
        student_events = re.findall(r'addEventListener\([\'"](\w+)[\'"]', student_js)

        for event in teacher_events:
            if event not in student_events:
                differences.append(f"Missing event listener: '{event}'")

        # Check for missing DOM elements accessed
        teacher_elements = re.findall(r'getElementById\([\'"](\w+)[\'"]', teacher_js)
        student_elements = re.findall(r'getElementById\([\'"](\w+)[\'"]', student_js)

        for element in teacher_elements:
            if element not in student_elements:
                differences.append(
                    f"Missing DOM element access: getElementById('{element}')"
                )

        # Check for specific JavaScript features/methods
        js_features = [
            ("preventDefault()", "event.preventDefault() method call"),
            ("reset()", "form reset method"),
            ("textContent", "setting textContent property"),
            ("backgroundColor", "setting backgroundColor style property"),
            ("DOMContentLoaded", "DOMContentLoaded event listener"),
            ("style.", "style property manipulation"),
        ]

        for feature, description in js_features:
            if feature in teacher_js and feature not in student_js:
                differences.append(f"Missing JavaScript feature: {description}")

        # Check for missing function declarations
        teacher_functions = re.findall(r"function\s+(\w+)\s*\(", teacher_js)
        student_functions = re.findall(r"function\s+(\w+)\s*\(", student_js)

        for func in teacher_functions:
            if func not in student_functions:
                differences.append(f"Missing function declaration: {func}")

        # Check for arrow function syntax if present in teacher code
        if "=>" in teacher_js and "=>" not in student_js:
            differences.append("Missing arrow function syntax in student code")

        # Check for variable declarations
        teacher_vars = re.findall(r"(?:const|let|var)\s+(\w+)\s*=", teacher_js)
        student_vars = re.findall(r"(?:const|let|var)\s+(\w+)\s*=", student_js)

        for var in teacher_vars:
            if var not in student_vars:
                differences.append(f"Missing variable declaration: {var}")

        # Look for template literals if used in teacher code
        if "`" in teacher_js and "`" not in student_js:
            differences.append("Missing template literals (backtick strings)")

        # Check for specific string differences in comments
        # This might help identify missing sections based on comment headers
        teacher_comments = re.findall(r"//\s*(.+)$", teacher_js, re.MULTILINE)
        student_comments = re.findall(r"//\s*(.+)$", student_js, re.MULTILINE)

        for comment in teacher_comments:
            if "form submission" in comment.lower() and not any(
                "form submission" in c.lower() for c in student_comments
            ):
                differences.append("Missing form submission handling section")
            if "validation" in comment.lower() and not any(
                "validation" in c.lower() for c in student_comments
            ):
                differences.append("Missing form validation logic")
            if (
                "event" in comment.lower()
                and "handler" in comment.lower()
                and not any(
                    ("event" in c.lower() and "handler" in c.lower())
                    for c in student_comments
                )
            ):
                differences.append("Missing event handler implementation")

        # Compare function parameter counts
        # Extract function signatures and compare number of parameters
        teacher_signatures = re.findall(r"function\s+\w+\s*\(([^)]*)\)", teacher_js)
        student_signatures = re.findall(r"function\s+\w+\s*\(([^)]*)\)", student_js)

        if len(teacher_signatures) > len(student_signatures):
            differences.append(
                f"Missing {len(teacher_signatures) - len(student_signatures)} function declarations"
            )

        # If no specific differences were found but the files are different
        if not differences and student_js != teacher_js:
            # Use difflib to highlight specific differences
            diff = list(
                difflib.unified_diff(
                    student_js.splitlines(), teacher_js.splitlines(), n=1
                )
            )

            if diff:
                # Limit to first 5 differences to avoid excessive output
                for line in diff[:8]:
                    if line.startswith("+") and not line.startswith("+++"):
                        differences.append(
                            f"Missing in student code: {line[1:].strip()}"
                        )
                    elif line.startswith("-") and not line.startswith("---"):
                        differences.append(f"Extra in student code: {line[1:].strip()}")

        return differences

    except Exception as e:
        print(f"Error analyzing JavaScript differences: {str(e)}")
        return ["Error analyzing JavaScript code: " + str(e)]


if __name__ == "__main__":
    # This script can be run directly from command line
    # Usage: python json_helper.py extract <file_path>
    # Or: python json_helper.py analyze_js <student_js_path> <teacher_js_path>
    if len(sys.argv) < 3:
        print("Usage: python json_helper.py <command> <file_path> [<file_path2>]")
        sys.exit(1)

    command = sys.argv[1]
    file_path = sys.argv[2]

    if command == "extract":
        result = read_json_file(file_path)
        print(f"HTML_PATH:{result['html_path']}")
        print(f"CSS_PATH:{result['css_path']}")
        print(f"JS_PATH:{result['js_path']}")
    elif command == "analyze_js" and len(sys.argv) > 3:
        teacher_js_path = sys.argv[3]
        differences = analyze_js_differences(file_path, teacher_js_path)
        for diff in differences:
            print(diff)
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
