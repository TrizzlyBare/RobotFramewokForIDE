#!/usr/bin/env python3
"""
JSON Helper Script for Web Code Testing

This script helps extract and analyze code from JSON files for web testing.
It works specifically with the structure of students.json and teachers.json.
"""

import sys
import os
import json
import re


def extract_json_to_files(json_file_path):
    """
    Extract defaultcode from JSON file into separate files
    Returns paths to the extracted files
    """
    try:
        # Read the JSON file
        with open(json_file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # Extract the defaultcode
        if "defaultcode" not in data:
            print(f"Error: 'defaultcode' not found in {json_file_path}")
            return None

        defaultcode = data["defaultcode"]

        # Create temporary files for each code type
        temp_dir = os.path.join(os.path.dirname(json_file_path), "temp")
        os.makedirs(temp_dir, exist_ok=True)

        # Create base filename from JSON filename
        base_name = os.path.splitext(os.path.basename(json_file_path))[0]

        # Write HTML to file
        html_path = os.path.join(temp_dir, f"{base_name}_html.html")
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(defaultcode.get("html", ""))

        # Write CSS to file
        css_path = os.path.join(temp_dir, f"{base_name}_css.css")
        with open(css_path, "w", encoding="utf-8") as f:
            f.write(defaultcode.get("css", ""))

        # Write JS to file
        js_path = os.path.join(temp_dir, f"{base_name}_js.js")
        with open(js_path, "w", encoding="utf-8") as f:
            f.write(defaultcode.get("js", ""))

        # Print paths for Robot Framework to capture
        print(f"HTML_PATH:{html_path}")
        print(f"CSS_PATH:{css_path}")
        print(f"JS_PATH:{js_path}")

        return html_path, css_path, js_path

    except Exception as e:
        print(f"Error extracting JSON: {str(e)}")
        return None


def analyze_html_differences(student_html_path, teacher_html_path):
    """
    Analyze HTML files for specific differences, especially order differences
    """
    try:
        # Read HTML files
        with open(student_html_path, "r", encoding="utf-8") as f:
            student_html = f.read()

        with open(teacher_html_path, "r", encoding="utf-8") as f:
            teacher_html = f.read()

        differences = []

        # Check for missing background-color in body
        if (
            "background-color: #f5f5f5" in teacher_html
            and "background-color: #f5f5f5" not in student_html
        ):
            differences.append("Missing background-color: #f5f5f5 in body style rule")

        # Check for order of elements (simplified)
        # Extract color-box divs
        teacher_color_boxes = re.findall(
            r'<div class="color-box"[^>]*>.*?</div>', teacher_html, re.DOTALL
        )
        student_color_boxes = re.findall(
            r'<div class="color-box"[^>]*>.*?</div>', student_html, re.DOTALL
        )

        # Check if they're in different order
        if (
            len(teacher_color_boxes) == len(student_color_boxes)
            and teacher_color_boxes != student_color_boxes
        ):
            # Extract colors for better reporting
            teacher_colors = [
                re.search(r"background-color: (#[A-F0-9]+)", box).group(1)
                for box in teacher_color_boxes
                if re.search(r"background-color: (#[A-F0-9]+)", box)
            ]
            student_colors = [
                re.search(r"background-color: (#[A-F0-9]+)", box).group(1)
                for box in student_color_boxes
                if re.search(r"background-color: (#[A-F0-9]+)", box)
            ]

            if (
                sorted(teacher_colors) == sorted(student_colors)
                and teacher_colors != student_colors
            ):
                differences.append(
                    f"Color boxes are in wrong order. Expected: {', '.join(teacher_colors)}"
                )

        # Check order of headings
        teacher_headings = re.findall(
            r"<h[1-6][^>]*>.*?</h[1-6]>", teacher_html, re.DOTALL
        )
        student_headings = re.findall(
            r"<h[1-6][^>]*>.*?</h[1-6]>", student_html, re.DOTALL
        )

        if (
            len(teacher_headings) == len(student_headings)
            and teacher_headings != student_headings
        ):
            # Extract heading texts
            teacher_heading_texts = [
                re.search(r">(.*?)<", heading).group(1)
                for heading in teacher_headings
                if re.search(r">(.*?)<", heading)
            ]
            student_heading_texts = [
                re.search(r">(.*?)<", heading).group(1)
                for heading in student_headings
                if re.search(r">(.*?)<", heading)
            ]

            if (
                sorted(teacher_heading_texts) == sorted(student_heading_texts)
                and teacher_heading_texts != student_heading_texts
            ):
                differences.append(
                    f"Heading order is incorrect. Expected: {', '.join(teacher_heading_texts)}"
                )

        return differences

    except Exception as e:
        print(f"Error analyzing HTML: {str(e)}")
        return [f"Error analyzing HTML: {str(e)}"]


def analyze_css_differences(student_css_path, teacher_css_path):
    """
    Analyze CSS files for specific differences, especially order differences
    """
    try:
        # Read CSS files
        with open(student_css_path, "r", encoding="utf-8") as f:
            student_css = f.read()

        with open(teacher_css_path, "r", encoding="utf-8") as f:
            teacher_css = f.read()

        differences = []

        # Extract selectors in order
        teacher_selectors = re.findall(r"([^\s,{]+)\s*{", teacher_css)
        student_selectors = re.findall(r"([^\s,{]+)\s*{", student_css)

        # Check if selectors are in different order
        if len(teacher_selectors) > 3 and len(student_selectors) > 3:
            # Check the first few important selectors
            important_selectors = ["body", ".container", "button"]
            teacher_important_order = [
                s for s in teacher_selectors if s in important_selectors
            ]
            student_important_order = [
                s for s in student_selectors if s in important_selectors
            ]

            if teacher_important_order != student_important_order:
                differences.append(
                    f"CSS selector order is different. Expected: {', '.join(teacher_important_order)}"
                )

        return differences

    except Exception as e:
        print(f"Error analyzing CSS: {str(e)}")
        return [f"Error analyzing CSS: {str(e)}"]


def analyze_js_differences(student_js_path, teacher_js_path):
    """
    Analyze JavaScript files for specific differences, especially order differences
    """
    try:
        # Read JS files
        with open(student_js_path, "r", encoding="utf-8") as f:
            student_js = f.read()

        with open(teacher_js_path, "r", encoding="utf-8") as f:
            teacher_js = f.read()

        differences = []

        # Check event listeners order
        teacher_events = re.findall(r'addEventListener\([\'"](\w+)[\'"]', teacher_js)
        student_events = re.findall(r'addEventListener\([\'"](\w+)[\'"]', student_js)

        if len(teacher_events) >= 2 and len(student_events) >= 2:
            if teacher_events != student_events:
                differences.append(
                    f"Event listener order is different. Expected: {', '.join(teacher_events)}"
                )

        # Check function order
        teacher_functions = re.findall(r"function\s+(\w+)\s*\(", teacher_js)
        student_functions = re.findall(r"function\s+(\w+)\s*\(", student_js)

        if len(teacher_functions) >= 2 and len(student_functions) >= 2:
            if teacher_functions != student_functions:
                differences.append(
                    f"Function declaration order is different. Expected: {', '.join(teacher_functions)}"
                )

        return differences

    except Exception as e:
        print(f"Error analyzing JS: {str(e)}")
        return [f"Error analyzing JS: {str(e)}"]


def main():
    """
    Main function to handle command line arguments
    """
    if len(sys.argv) < 2:
        print(
            "Usage: python json_helper.py [extract|analyze_html|analyze_css|analyze_js] ..."
        )
        return 1

    command = sys.argv[1]

    if command == "extract":
        if len(sys.argv) < 3:
            print("Usage: python json_helper.py extract <json_file_path>")
            return 1

        json_file_path = sys.argv[2]
        result = extract_json_to_files(json_file_path)
        return 0 if result else 1

    elif command == "analyze_html":
        if len(sys.argv) < 4:
            print(
                "Usage: python json_helper.py analyze_html <student_html_path> <teacher_html_path>"
            )
            return 1

        student_html_path = sys.argv[2]
        teacher_html_path = sys.argv[3]
        differences = analyze_html_differences(student_html_path, teacher_html_path)

        for diff in differences:
            print(diff)

        return 0

    elif command == "analyze_css":
        if len(sys.argv) < 4:
            print(
                "Usage: python json_helper.py analyze_css <student_css_path> <teacher_css_path>"
            )
            return 1

        student_css_path = sys.argv[2]
        teacher_css_path = sys.argv[3]
        differences = analyze_css_differences(student_css_path, teacher_css_path)

        for diff in differences:
            print(diff)

        return 0

    elif command == "analyze_js":
        if len(sys.argv) < 4:
            print(
                "Usage: python json_helper.py analyze_js <student_js_path> <teacher_js_path>"
            )
            return 1

        student_js_path = sys.argv[2]
        teacher_js_path = sys.argv[3]
        differences = analyze_js_differences(student_js_path, teacher_js_path)

        for diff in differences:
            print(diff)

        return 0

    else:
        print(f"Unknown command: {command}")
        print("Available commands: extract, analyze_html, analyze_css, analyze_js")
        return 1


if __name__ == "__main__":
    sys.exit(main())
