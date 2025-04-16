#!/usr/bin/env python3
"""
Test Runner Script for Web Code Validation

This script provides a command-line interface for running the web code validation
with detailed error reporting. It can compare HTML, CSS, and JavaScript code
between student submissions and reference (teacher) implementations.
"""

import os
import sys
import json
import argparse
from WebCodeComparator import WebCodeComparator


def read_file(file_path):
    """Read content from a file"""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return None


def write_json(data, file_path):
    """Write JSON data to a file"""
    try:
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        print(f"Error writing to file {file_path}: {e}")
        return False


def read_json(file_path):
    """Read JSON data from a file"""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading JSON file {file_path}: {e}")
        return None


def compare_code_files(student_file, teacher_file, language, output_file=None):
    """Compare code files and generate detailed feedback"""
    # Read files
    student_code = read_file(student_file)
    teacher_code = read_file(teacher_file)

    if student_code is None or teacher_code is None:
        print("Error: Could not read input files")
        return False

    # Initialize comparator
    comparator = WebCodeComparator()

    # Compare based on language
    if language.lower() == "html":
        differences = comparator.compare_html(student_code, teacher_code)
    elif language.lower() == "css":
        differences = comparator.compare_css(student_code, teacher_code)
    elif language.lower() == "js" or language.lower() == "javascript":
        differences = comparator.compare_js(student_code, teacher_code)
    else:
        print(f"Error: Unsupported language '{language}'")
        return False

    # Prepare result
    result = {"match": len(differences) == 0, "differences": differences}

    # Print differences
    print(f"\nComparison results for {language.upper()}:")
    print(f"Match: {result['match']}")

    if differences:
        print("\nDifferences:")
        for i, diff in enumerate(differences, 1):
            print(f"{i}. {diff}")
    else:
        print("Files match! No differences found.")

    # Save to file if requested
    if output_file:
        if write_json(result, output_file):
            print(f"\nDetailed results saved to: {output_file}")
        else:
            print(f"\nError: Could not save results to {output_file}")

    return result["match"]


def compare_json_defaultcode(students_json, teachers_json, output_dir):
    """Compare defaultcode in students.json and teachers.json"""
    # Read JSON files
    students_data = read_json(students_json)
    teachers_data = read_json(teachers_json)

    if students_data is None or teachers_data is None:
        print("Error: Could not read JSON files")
        return False

    # Extract defaultcode
    try:
        student_html = students_data["defaultcode"]["html"]
        student_css = students_data["defaultcode"]["css"]
        student_js = students_data["defaultcode"]["js"]

        teacher_html = teachers_data["defaultcode"]["html"]
        teacher_css = teachers_data["defaultcode"]["css"]
        teacher_js = teachers_data["defaultcode"]["js"]
    except KeyError as e:
        print(f"Error: Missing defaultcode key in JSON: {e}")
        return False

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Initialize comparator
    comparator = WebCodeComparator()

    # Compare HTML
    html_differences = comparator.compare_html(student_html, teacher_html)
    html_match = len(html_differences) == 0

    # Compare CSS
    css_differences = comparator.compare_css(student_css, teacher_css)
    css_match = len(css_differences) == 0

    # Compare JS
    js_differences = comparator.compare_js(student_js, teacher_js)
    js_match = len(js_differences) == 0

    # Create result object
    result = {
        "html_match": html_match,
        "css_match": css_match,
        "js_match": js_match,
        "html_differences": html_differences,
        "css_differences": css_differences,
        "js_differences": js_differences,
        "overall_match": html_match and css_match and js_match,
    }

    # Save detailed report
    report_file = os.path.join(output_dir, "defaultcode_comparison_result.json")
    if write_json(result, report_file):
        print(f"Detailed results saved to: {report_file}")

    # Print summary
    print("\nComparison Results Summary:")
    print(f"HTML Match: {html_match}")
    print(f"CSS Match: {css_match}")
    print(f"JavaScript Match: {js_match}")
    print(f"Overall Match: {result['overall_match']}")

    # Print differences
    if not html_match:
        print("\nHTML Differences:")
        for i, diff in enumerate(html_differences, 1):
            print(f"{i}. {diff}")

    if not css_match:
        print("\nCSS Differences:")
        for i, diff in enumerate(css_differences, 1):
            print(f"{i}. {diff}")

    if not js_match:
        print("\nJavaScript Differences:")
        for i, diff in enumerate(js_differences, 1):
            print(f"{i}. {diff}")

    return result["overall_match"]


def main():
    """Main entry point with argument parsing"""
    parser = argparse.ArgumentParser(
        description="Web Code Validator with Detailed Feedback"
    )

    # Create subparsers for different commands
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # Parser for comparing individual files
    file_parser = subparsers.add_parser(
        "compare-files", help="Compare individual code files"
    )
    file_parser.add_argument(
        "--student", required=True, help="Path to student code file"
    )
    file_parser.add_argument(
        "--teacher", required=True, help="Path to teacher code file"
    )
    file_parser.add_argument(
        "--language",
        required=True,
        choices=["html", "css", "js", "javascript"],
        help="Code language type",
    )
    file_parser.add_argument(
        "--output", help="Output JSON file path for detailed results"
    )

    # Parser for comparing JSON defaultcode
    json_parser = subparsers.add_parser(
        "compare-json", help="Compare defaultcode in JSON files"
    )
    json_parser.add_argument(
        "--students-json", required=True, help="Path to students.json file"
    )
    json_parser.add_argument(
        "--teachers-json", required=True, help="Path to teachers.json file"
    )
    json_parser.add_argument(
        "--output-dir", required=True, help="Directory to save output files"
    )

    # Parse arguments
    args = parser.parse_args()

    if args.command == "compare-files":
        # Compare individual files
        return compare_code_files(
            args.student, args.teacher, args.language, args.output
        )
    elif args.command == "compare-json":
        # Compare defaultcode in JSON files
        return compare_json_defaultcode(
            args.students_json, args.teachers_json, args.output_dir
        )
    else:
        # No command specified, show help
        parser.print_help()
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
