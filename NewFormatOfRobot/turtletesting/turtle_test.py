#!/usr/bin/env python3
"""
Universal Turtle Testing Script (No Log Files Version)

This script handles virtually any turtle syntax variation to compare outputs between
teacher and student turtle graphics code. All output is kept in memory rather than
creating log files.

Features:
- All turtle instance naming conventions
- Both module-level and object-oriented approaches
- All import styles (import turtle, from turtle import *)
- Both standard and abbreviated commands
- Multiple turtle instances
- No log files created on disk
"""
import os
import sys
import subprocess
import tempfile
import difflib
import argparse
import json
import time
import re
import io

# Configuration
COMPARISON_THRESHOLD = 0.9
TIMEOUT_SECONDS = 120


def indent_code(code, spaces=4):
    """
    Indents every line of code by a certain number of spaces
    """
    return "\n".join(" " * spaces + line for line in code.splitlines())


def detect_turtle_instances(code):
    """
    Detects turtle instance names being used in the code
    Returns a list of likely turtle variable names
    """
    # Common turtle instance names
    turtle_vars = []

    # Check for explicit turtle creations (all variations)
    patterns = [
        r"(\w+)\s*=\s*turtle\.Turtle\(\)",  # t = turtle.Turtle()
        r"(\w+)\s*=\s*Turtle\(\)",  # t = Turtle()
        r"(\w+)\s*=\s*turtle\.RawTurtle\(\w+\)",  # t = turtle.RawTurtle(screen)
        r"(\w+)\s*=\s*RawTurtle\(\w+\)",  # t = RawTurtle(screen)
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, code):
            turtle_vars.append(match.group(1))

    # Check for other potential turtle objects by looking for common method calls
    potential_turtles = set()

    # Comprehensive list of turtle methods
    turtle_methods = [
        "forward",
        "fd",
        "backward",
        "bk",
        "back",
        "right",
        "rt",
        "left",
        "lt",
        "goto",
        "setpos",
        "setposition",
        "setx",
        "sety",
        "setheading",
        "seth",
        "home",
        "circle",
        "dot",
        "stamp",
        "clearstamp",
        "clearstamps",
        "undo",
        "speed",
        "position",
        "pos",
        "towards",
        "xcor",
        "ycor",
        "heading",
        "distance",
        "pendown",
        "pd",
        "down",
        "penup",
        "pu",
        "up",
        "pensize",
        "width",
        "pen",
        "isdown",
        "isvisible",
        "pencolor",
        "fillcolor",
        "color",
        "begin_fill",
        "end_fill",
        "filling",
        "reset",
        "clear",
        "hideturtle",
        "ht",
        "showturtle",
        "st",
        "write",
    ]

    for method in turtle_methods:
        for match in re.finditer(r"(\w+)\." + method + r"\s*\(", code):
            var_name = match.group(1)
            if var_name != "turtle":  # skip the module itself
                potential_turtles.add(var_name)

    # Add any found potential turtles that aren't already in our list
    for var in potential_turtles:
        if var not in turtle_vars:
            turtle_vars.append(var)

    # Special case: if 't' is used in t.xyz() but not found yet, add it
    if not turtle_vars and re.search(r"t\.\w+\s*\(", code):
        turtle_vars.append("t")

    return turtle_vars


def detect_import_style(code):
    """
    Detects how the turtle module is imported
    Returns a tuple (uses_module, uses_star_import, uses_selective)
    """
    uses_module = "import turtle" in code
    uses_star_import = "from turtle import *" in code

    # Also check for selective imports
    selective_import = re.search(r"from\s+turtle\s+import\s+(?!.*\*)", code) is not None

    return (uses_module, uses_star_import, selective_import)


def create_universal_test_environment(code, output_var_name):
    """
    Creates a test environment that works with any turtle syntax
    Output is stored in a variable rather than written to a file
    """
    # Detect the import style
    uses_module, uses_star, uses_selective = detect_import_style(code)

    # Detect turtle variable names being used
    turtle_instances = detect_turtle_instances(code)

    # Create pre-setup code to initialize any detected turtle instances
    setup_code = """# Create universal turtle environment
import turtle
from turtle import *  # Import all turtle functions for maximum compatibility

# Set up the screen globally
try:
    screen = turtle.Screen()
except Exception:
    # Fallback for environments where Screen() might not work
    try:
        screen = turtle.getscreen()
    except Exception:
        screen = None  # Last resort
        
"""

    # Create initialization for each turtle
    if turtle_instances:
        for instance in turtle_instances:
            setup_code += f"# Initialize {instance} as a turtle\n"
            setup_code += f"try:\n"
            setup_code += f"    {instance} = turtle.Turtle()\n"
            setup_code += f"except Exception:\n"
            setup_code += f"    {instance} = Turtle()\n\n"
    else:
        # If no instances found, create a default 't'
        setup_code += "# No turtle instances detected, creating default 't'\n"
        setup_code += "try:\n"
        setup_code += "    t = turtle.Turtle()\n"
        setup_code += "except Exception:\n"
        setup_code += "    t = Turtle()\n\n"

    # Special case: if they use module functions directly without creating a turtle
    if not turtle_instances and uses_module and not uses_star:
        setup_code += "# Support for direct module function calls\n"
        setup_code += "turtle.reset()\n\n"

    script = f"""#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Universal turtle testing environment

import sys
import os
import time
import io

# Support both Python 2 and 3
if sys.version_info[0] < 3:
    # Python 2
    import Tkinter as tkinter
else:
    # Python 3
    import tkinter

{setup_code}

# Variable to store the output instead of writing to log file
{output_var_name} = io.StringIO()

# Run the user code inside a try block
try:
{indent_code(code)}

    # After the user code finishes, save the output
    time.sleep(0.2)  # Small pause to ensure drawing is done
    
    # Store turtle states in memory
    {output_var_name}.write("TURTLE_STATE_BEGIN\\n")
    
    # Get all turtles in the screen
    turtles = screen.turtles() if screen else []
    
    # If no turtles found in screen, use our explicitly created ones
    if not turtles and 't' in locals():
        turtles = [t]
        {' '.join([f'if "{instance}" in locals(): turtles.append({instance})' for instance in turtle_instances if instance != 't'])}
    
    # Special case for turtle module functions
    if not turtles and 'turtle' in sys.modules:
        try:
            turtles = [sys.modules['turtle']._getpen()]
        except:
            pass
    
    # Log turtle count
    {output_var_name}.write(f"Number of turtles: {{len(turtles)}}\\n")
    
    # Log details for each turtle
    for i, turt in enumerate(turtles):
        {output_var_name}.write(f"\\nTurtle {{i+1}}:\\n")
        
        # Get position
        try:
            pos = turt.position()
            {output_var_name}.write(f"Position: {{pos[0]}}, {{pos[1]}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Position: Error {{e}}\\n")
        
        # Get heading
        try:
            {output_var_name}.write(f"Heading: {{turt.heading()}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Heading: Error {{e}}\\n")
        
        # Get pen state
        try:
            {output_var_name}.write(f"Pen down: {{turt.isdown()}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Pen down: Error {{e}}\\n")
        
        # Get pen color
        try:
            {output_var_name}.write(f"Pen color: {{turt.pencolor()}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Pen color: Error {{e}}\\n")
        
        # Get fill color
        try:
            {output_var_name}.write(f"Fill color: {{turt.fillcolor()}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Fill color: Error {{e}}\\n")
        
        # Get pen size
        try:
            {output_var_name}.write(f"Pen size: {{turt.pensize()}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Pen size: Error {{e}}\\n")
        
        # Get visibility
        try:
            {output_var_name}.write(f"Visible: {{turt.isvisible()}}\\n")
        except Exception as e:
            {output_var_name}.write(f"Visible: Error {{e}}\\n")
    
    {output_var_name}.write("TURTLE_STATE_END\\n")
    
    # Try to take a screenshot - image is not stored in output
    try:
        if screen:
            # Deliberately not saving the image to file
            pass
    except Exception:
        pass
    
    # Clean exit
    try:
        if screen:
            screen.bye()
        turtle.TurtleScreen._RUNNING = False  # Force termination
    except Exception:
        pass
    
    # Print the output so we can capture it from the subprocess
    output_str = {output_var_name}.getvalue()
    print("OUTPUT_DELIMITER_START")
    print(output_str)
    print("OUTPUT_DELIMITER_END")
    
    sys.exit(0)
    
except Exception as e:
    # Log the error
    error_msg = str(e)
    print(f"Error running code: {{error_msg}}")
    
    # Store error info in memory without creating a log file
    {output_var_name}.write(f"ERROR: {{error_msg}}\\n\\n")
    {output_var_name}.write("Traceback:\\n")
    
    import traceback
    traceback_io = io.StringIO()
    traceback.print_exc(file=traceback_io)
    {output_var_name}.write(traceback_io.getvalue())
    
    # Print the error output
    error_output = {output_var_name}.getvalue()
    print("ERROR_DELIMITER_START")
    print(error_output)
    print("ERROR_DELIMITER_END")
    
    # Try to clean up
    try:
        if 'screen' in locals() and screen:
            screen.bye()
        turtle.TurtleScreen._RUNNING = False  # Force termination
    except Exception:
        pass
    
    sys.exit(1)
"""
    return script


def sanitize_code(code):
    """
    Sanitizes code to remove problematic patterns
    """
    # Skip any mainloop() or exitonclick() calls as we handle closing
    code = re.sub(r"(turtle\.)?exitonclick\(\)", "# exitonclick removed", code)
    code = re.sub(r"(turtle\.)?mainloop\(\)", "# mainloop removed", code)
    code = re.sub(r"(\w+)\.exitonclick\(\)", "# exitonclick removed", code)
    code = re.sub(r"(\w+)\.mainloop\(\)", "# mainloop removed", code)

    # Skip any module-level done() or bye() calls
    code = re.sub(r"(turtle\.)?done\(\)", "# done() removed", code)
    code = re.sub(r"(turtle\.)?bye\(\)", "# bye() removed", code)

    return code


def extract_output_from_stdout(stdout_text, start_marker, end_marker):
    """
    Extracts the turtle output from the stdout text using markers
    """
    start_index = stdout_text.find(start_marker)
    if start_index == -1:
        return None

    start_index += len(start_marker) + 1  # +1 for the newline
    end_index = stdout_text.find(end_marker, start_index)

    if end_index == -1:
        return None

    return stdout_text[start_index:end_index].strip()


def run_turtle_code(code, name_prefix):
    """
    Runs turtle code and captures the output in memory (no log files)
    """
    # Clean up the code
    sanitized_code = sanitize_code(code)

    # Create the test script with a unique output variable name
    output_var_name = f"{name_prefix}_output"
    script = create_universal_test_environment(sanitized_code, output_var_name)

    # Save script for debugging (only debug script, not output)
    with open(f"{name_prefix}_debug.py", "w") as f:
        f.write(script)
    print(f"Debug script saved to: {name_prefix}_debug.py")

    # Create a temporary file to execute
    with tempfile.NamedTemporaryFile(suffix=".py", delete=False, mode="w") as temp_file:
        temp_file.write(script)
        script_path = temp_file.name

    try:
        print(f"Running {name_prefix} code...")
        start_time = time.time()

        # Set no-buffer option for Python 3 compatibility
        python_exe = sys.executable

        # Run the script
        result = subprocess.run(
            [python_exe, script_path],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
        )

        execution_time = time.time() - start_time

        # Store output in memory
        stdout_output = result.stdout
        stderr_output = result.stderr

        # Check for errors
        if result.returncode != 0:
            print(f"Error running {name_prefix} code (exit code {result.returncode})")
            if stderr_output:
                print(f"Error message: {stderr_output[:200]}...")

            # Try to extract error output
            error_output = extract_output_from_stdout(
                stdout_output, "ERROR_DELIMITER_START", "ERROR_DELIMITER_END"
            )

            # If we got any output, we can still continue
            if error_output:
                print(f"Extracted error details despite execution failure")
                return (False, execution_time, error_output)

            return (False, execution_time, stderr_output)

        # Extract the turtle state output from stdout
        turtle_output = extract_output_from_stdout(
            stdout_output, "OUTPUT_DELIMITER_START", "OUTPUT_DELIMITER_END"
        )

        if not turtle_output:
            print(f"Warning: Could not extract turtle state information")
            return (
                False,
                execution_time,
                "No turtle state information found in output",
            )

        # Success
        print(f"{name_prefix} code ran successfully in {execution_time:.2f} seconds")
        return (True, execution_time, turtle_output)

    except subprocess.TimeoutExpired:
        print(
            f"Timeout: {name_prefix} code took too long (over {TIMEOUT_SECONDS} seconds)"
        )
        return (False, TIMEOUT_SECONDS, "Execution timed out")

    except Exception as e:
        print(f"Error: {e}")
        return (False, -1, str(e))

    finally:
        # Clean up temp file
        try:
            os.unlink(script_path)
        except:
            pass


def compare_turtle_outputs(teacher_output, student_output):
    """
    Compares the turtle outputs and calculates similarity
    """
    if not teacher_output or not student_output:
        print("Error: Missing teacher or student output")
        return 0

    print("\nTeacher output:")
    print(teacher_output)
    print("\nStudent output:")
    print(student_output)

    # Calculate similarity
    if teacher_output == student_output:
        return 1.0

    similarity = difflib.SequenceMatcher(None, teacher_output, student_output).ratio()
    return similarity


def analyze_code(code):
    """
    Analyzes turtle code to extract key features
    """
    analysis = {
        "operations": [],
        "shapes": [],
        "style": "",
        "complexity": "simple",
        "turtle_instances": detect_turtle_instances(code),
        "import_style": "",
    }

    # Determine import style
    uses_module, uses_star, uses_selective = detect_import_style(code)
    if uses_module and not uses_star and not uses_selective:
        analysis["import_style"] = "import turtle"
    elif uses_star:
        analysis["import_style"] = "from turtle import *"
    elif uses_selective:
        analysis["import_style"] = "from turtle import specific"
    else:
        analysis["import_style"] = "unknown"

    # Check for common turtle operations (both OOP and procedural styles)
    operations_to_check = [
        # (name, [regex patterns])
        ("circle", [r"\.\s*circle\s*\(", r"\bcircle\s*\("]),
        ("goto", [r"\.\s*goto\s*\(", r"\bgoto\s*\("]),
        (
            "forward",
            [r"\.\s*forward\s*\(", r"\.\s*fd\s*\(", r"\bforward\s*\(", r"\bfd\s*\("],
        ),
        (
            "backward",
            [
                r"\.\s*backward\s*\(",
                r"\.\s*bk\s*\(",
                r"\.\s*back\s*\(",
                r"\bbackward\s*\(",
                r"\bbk\s*\(",
                r"\bback\s*\(",
            ],
        ),
        ("right", [r"\.\s*right\s*\(", r"\.\s*rt\s*\(", r"\bright\s*\(", r"\brt\s*\("]),
        ("left", [r"\.\s*left\s*\(", r"\.\s*lt\s*\(", r"\bleft\s*\(", r"\blt\s*\("]),
        (
            "penup",
            [
                r"\.\s*penup\s*\(",
                r"\.\s*pu\s*\(",
                r"\.\s*up\s*\(",
                r"\bpenup\s*\(",
                r"\bpu\s*\(",
                r"\bup\s*\(",
            ],
        ),
        (
            "pendown",
            [
                r"\.\s*pendown\s*\(",
                r"\.\s*pd\s*\(",
                r"\.\s*down\s*\(",
                r"\bpendown\s*\(",
                r"\bpd\s*\(",
                r"\bdown\s*\(",
            ],
        ),
        (
            "pensize",
            [
                r"\.\s*pensize\s*\(",
                r"\.\s*width\s*\(",
                r"\bpensize\s*\(",
                r"\bwidth\s*\(",
            ],
        ),
        ("pencolor", [r"\.\s*pencolor\s*\(", r"\bpencolor\s*\("]),
        ("fillcolor", [r"\.\s*fillcolor\s*\(", r"\bfillcolor\s*\("]),
        ("begin_fill", [r"\.\s*begin_fill\s*\(", r"\bbegin_fill\s*\("]),
        ("end_fill", [r"\.\s*end_fill\s*\(", r"\bend_fill\s*\("]),
    ]

    for op_name, patterns in operations_to_check:
        for pattern in patterns:
            if re.search(pattern, code):
                if op_name not in analysis["operations"]:
                    analysis["operations"].append(op_name)
                break

    # Determine shapes being drawn
    if "circle" in analysis["operations"]:
        analysis["shapes"].append("circle")

    if "goto" in analysis["operations"]:
        goto_count = 0
        for pattern in [r"\.\s*goto\s*\(", r"\bgoto\s*\("]:
            goto_count += len(re.findall(pattern, code))

        if goto_count >= 2:
            if goto_count == 2:
                analysis["shapes"].append("line_segment")
            elif goto_count == 3:
                analysis["shapes"].append("triangle")
            elif goto_count == 4:
                analysis["shapes"].append("quadrilateral")
            else:
                analysis["shapes"].append("polygon")

    # Look for repetition structures that may indicate complex shapes
    if "forward" in analysis["operations"] and (
        "right" in analysis["operations"] or "left" in analysis["operations"]
    ):
        if re.search(r"\bfor\b.*:", code) or re.search(r"\bwhile\b.*:", code):
            analysis["shapes"].append("repeated_pattern")

            # Look for specific patterns suggesting common shapes
            if re.search(r"(?:range|xrange)\s*\(\s*4\s*\)", code) and (
                "right" in analysis["operations"] or "left" in analysis["operations"]
            ):
                analysis["shapes"].append("square")
            elif re.search(r"(?:range|xrange)\s*\(\s*[3-9]\s*\)", code) and (
                "right" in analysis["operations"] or "left" in analysis["operations"]
            ):
                sides = re.search(r"(?:range|xrange)\s*\(\s*([3-9])\s*\)", code)
                if sides:
                    if sides.group(1) == "3":
                        analysis["shapes"].append("triangle")
                    elif sides.group(1) == "5":
                        analysis["shapes"].append("pentagon")
                    elif sides.group(1) == "6":
                        analysis["shapes"].append("hexagon")
                    elif sides.group(1) == "8":
                        analysis["shapes"].append("octagon")
                    else:
                        analysis["shapes"].append(f"{sides.group(1)}-sided_polygon")

            # See if it's likely a star or snowflake
            if (
                "for" in code
                and "forward" in analysis["operations"]
                and "right" in analysis["operations"]
            ):
                if re.search(r"right\s*\(\s*144\s*\)", code) or re.search(
                    r"left\s*\(\s*144\s*\)", code
                ):
                    analysis["shapes"].append("star")
                elif re.search(r"right\s*\(\s*60\s*\)", code) or re.search(
                    r"left\s*\(\s*60\s*\)", code
                ):
                    analysis["shapes"].append("snowflake")

    # Detect coding style
    if len(analysis["turtle_instances"]) > 1:
        analysis["style"] = "multiple_turtles"
    elif re.search(r"\w+\s*=\s*(?:turtle\.)?Turtle\(\)", code):
        analysis["style"] = "object_oriented"
    elif analysis["import_style"] == "from turtle import *" and not any(
        re.search(r"\.\w+\(", line) for line in code.splitlines()
    ):
        analysis["style"] = "procedural"
    else:
        analysis["style"] = "mixed"

    # Determine complexity
    if any(
        op in analysis["operations"] for op in ["pencolor", "fillcolor", "begin_fill"]
    ):
        analysis["complexity"] = "moderate"

    if len(analysis["operations"]) > 5 or "for " in code or "while " in code:
        analysis["complexity"] = "moderate"

    if "def " in code or "class " in code or ("for " in code and "while " in code):
        analysis["complexity"] = "complex"

    return analysis


def identify_shape(analysis):
    """
    Identifies the likely shape being drawn based on code analysis
    """
    # Join all identified shapes into a description
    shapes = analysis["shapes"]

    if not shapes:
        # No shapes explicitly identified, try to infer from operations
        if "circle" in analysis["operations"]:
            return "a circle"
        elif "forward" in analysis["operations"] and (
            "right" in analysis["operations"] or "left" in analysis["operations"]
        ):
            if analysis["complexity"] == "simple":
                return "a straight line"
            else:
                return "a geometric pattern"
        elif "goto" in analysis["operations"]:
            return "line segments"
        else:
            return "an unknown shape"

    # Named shapes
    if "square" in shapes:
        return "a square"
    elif "triangle" in shapes:
        return "a triangle"
    elif "pentagon" in shapes:
        return "a pentagon"
    elif "hexagon" in shapes:
        return "a hexagon"
    elif "octagon" in shapes:
        return "an octagon"
    elif "star" in shapes:
        return "a star"
    elif "snowflake" in shapes:
        return "a snowflake pattern"
    elif "circle" in shapes:
        return "a circle"
    elif "polygon" in shapes:
        return "a polygon"
    elif "quadrilateral" in shapes:
        return "a quadrilateral"
    elif "line_segment" in shapes:
        return "line segments"
    elif "repeated_pattern" in shapes:
        return "a geometric pattern"
    elif any(s.endswith("sided_polygon") for s in shapes):
        for s in shapes:
            if s.endswith("sided_polygon"):
                sides = s.split("-")[0]
                return f"a {sides}-sided polygon"

    # Fallback to a general description
    return "a shape"


def load_json_code(filepath):
    """
    Loads code from a JSON file
    """
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
            code = data.get("defaultcode", "")
            return code
    except Exception as e:
        print(f"Error loading code from {filepath}: {e}")
        return ""


def test_turtle_code(teacher_code, student_code):
    """
    Tests student code against teacher code without creating log files
    """
    results = {
        "test_execution": {"status": "", "message": ""},
        "teacher_code": {"execution_status": "", "execution_time": "", "output": ""},
        "student_code": {"execution_status": "", "execution_time": "", "output": ""},
        "output_comparison": {
            "similarity": 0,
            "threshold_met": False,
            "comparison_details": "",
        },
        "test_summary": {"result": "", "reason": "", "recommendation": ""},
    }

    # Check if codes are identical
    if teacher_code == student_code:
        print("Teacher and student code are identical!")
        results["test_execution"]["status"] = "success"
        results["test_execution"]["message"] = "Teacher and student code are identical"
        results["output_comparison"]["similarity"] = 1.0
        results["output_comparison"]["threshold_met"] = True
        results["test_summary"]["result"] = "PASSED"
        results["test_summary"]["reason"] = "Identical code"
        return results

    # Run both codes, capturing output in memory
    teacher_success, teacher_time, teacher_output = run_turtle_code(
        teacher_code, "teacher"
    )
    student_success, student_time, student_output = run_turtle_code(
        student_code, "student"
    )

    # Record execution status and output
    results["teacher_code"]["execution_status"] = (
        "success" if teacher_success else "failed"
    )
    results["teacher_code"]["execution_time"] = f"{teacher_time:.2f} seconds"
    results["teacher_code"][
        "output"
    ] = teacher_output  # Store output directly in results

    results["student_code"]["execution_status"] = (
        "success" if student_success else "failed"
    )
    results["student_code"]["execution_time"] = f"{student_time:.2f} seconds"
    results["student_code"][
        "output"
    ] = student_output  # Store output directly in results

    # If both failed, we can't compare
    if not teacher_success and not student_success:
        print("Both teacher and student code failed to run")
        results["test_execution"]["status"] = "failed"
        results["test_execution"]["message"] = "Both codes failed to execute"
        results["test_summary"]["result"] = "ERROR"
        results["test_summary"]["reason"] = "Execution failure"
        return results

    # If at least one succeeded, try to compare
    if teacher_output and student_output:
        similarity = compare_turtle_outputs(teacher_output, student_output)

        results["output_comparison"]["similarity"] = similarity
        results["output_comparison"]["threshold_met"] = (
            similarity >= COMPARISON_THRESHOLD
        )
        results["output_comparison"][
            "comparison_details"
        ] = "Compared in-memory turtle state outputs"

        print(f"Similarity score: {similarity:.4f}")

        if similarity >= COMPARISON_THRESHOLD:
            print(
                f"✅ PASSED: Similarity score {similarity:.4f} is above threshold {COMPARISON_THRESHOLD}"
            )
            results["test_execution"]["status"] = "success"
            results["test_summary"]["result"] = "PASSED"
            results["test_summary"]["reason"] = f"Similarity: {similarity:.4f}"

            if similarity < 1.0:
                results["test_summary"][
                    "recommendation"
                ] = "Outputs are similar but not identical"
        else:
            print(
                f"❌ FAILED: Similarity score {similarity:.4f} is below threshold {COMPARISON_THRESHOLD}"
            )
            results["test_execution"]["status"] = "failed"
            results["test_summary"]["result"] = "FAILED"
            results["test_summary"][
                "reason"
            ] = f"Similarity: {similarity:.4f} (below threshold)"
            results["test_summary"][
                "recommendation"
            ] = "The student's drawing differs significantly from the teacher's"
    else:
        print("Cannot compare outputs: Missing output from teacher or student code")
        results["test_execution"]["status"] = "error"
        results["test_summary"]["result"] = "ERROR"
        results["test_summary"]["reason"] = "Missing output from execution"

    return results


def main():
    """
    Main program entry point
    """
    parser = argparse.ArgumentParser(description="Test turtle code solutions")
    parser.add_argument(
        "--teacher", default="teachers.json", help="Path to teacher's solution file"
    )
    parser.add_argument(
        "--student", default="students.json", help="Path to student's solution file"
    )
    parser.add_argument(
        "--threshold", type=float, default=0.9, help="Similarity threshold (0.0-1.0)"
    )
    parser.add_argument(
        "--timeout", type=int, default=120, help="Execution timeout in seconds"
    )
    parser.add_argument(
        "--results", default="test_results.json", help="Path for results output file"
    )
    parser.add_argument(
        "--analysis", default="code_analysis.json", help="Path for analysis output file"
    )

    args = parser.parse_args()

    global COMPARISON_THRESHOLD, TIMEOUT_SECONDS
    COMPARISON_THRESHOLD = args.threshold
    TIMEOUT_SECONDS = args.timeout

    # Load the code
    teacher_code = load_json_code(args.teacher)
    student_code = load_json_code(args.student)

    if not teacher_code or not student_code:
        print("Error: Could not load code files")
        sys.exit(1)

    print("Testing turtle code...")
    print(f"Teacher code:\n{teacher_code}\n")
    print(f"Student code:\n{student_code}\n")

    # Run the test
    test_results = test_turtle_code(teacher_code, student_code)

    # Analyze the code
    teacher_analysis = analyze_code(teacher_code)
    student_analysis = analyze_code(student_code)

    # Create code analysis
    code_analysis = {
        "comparison_result": {
            "identical_code": teacher_code == student_code,
            "similarity_score": test_results["output_comparison"]["similarity"],
            "test_result": test_results["test_summary"]["result"],
        },
        "teacher_code_details": teacher_analysis,
        "student_code_details": student_analysis,
        "test_process": {
            "comparison_threshold": COMPARISON_THRESHOLD,
            "timeout_seconds": TIMEOUT_SECONDS,
            "method": "Memory-based turtle environment with no log files created",
        },
        "visualization_description": f"The teacher code draws {identify_shape(teacher_analysis)}, while the student code draws {identify_shape(student_analysis)}.",
    }

    # Remove turtle output from the results to keep the JSON clean
    if "output" in test_results["teacher_code"]:
        test_results["teacher_code"]["output_length"] = len(
            test_results["teacher_code"]["output"]
        )
        del test_results["teacher_code"]["output"]

    if "output" in test_results["student_code"]:
        test_results["student_code"]["output_length"] = len(
            test_results["student_code"]["output"]
        )
        del test_results["student_code"]["output"]

    # Save results and analysis
    with open(args.results, "w") as f:
        json.dump(test_results, f, indent=2)
    print(f"Test results saved to {args.results}")

    with open(args.analysis, "w") as f:
        json.dump(code_analysis, f, indent=2)
    print(f"Code analysis saved to {args.analysis}")


if __name__ == "__main__":
    main()
