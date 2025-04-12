import os
import sys
import subprocess
import tempfile
import difflib
import argparse
import textwrap
import json

# Configuration
COMPARISON_THRESHOLD = 0.9


def clean_code(code):
    """
    Cleans up code by removing common indentation and fixing whitespace issues.
    """
    # Use textwrap to dedent (remove common leading whitespace)
    cleaned = textwrap.dedent(code).strip()
    return cleaned


def create_wrapper_script(code, output_basename):
    """
    Creates a wrapper script that executes the given turtle code and saves the output.
    This approach allows any arbitrary turtle code to be tested.
    """
    # Clean up the code first to remove indentation issues
    cleaned_code = clean_code(code)

    script = f"""
import turtle
import os
import time

# Function to capture turtle state
def save_turtle_state(t, filepath):
    with open(filepath, "w") as f:
        f.write(f"Position: {{t.xcor()}}, {{t.ycor()}}\\n")
        f.write(f"Heading: {{t.heading()}}\\n")
        f.write(f"Pen down: {{t.isdown()}}\\n")
        f.write(f"Pen color: {{t.pencolor()}}\\n")
        f.write(f"Fill color: {{t.fillcolor()}}\\n")
        f.write(f"Pen size: {{t.pensize()}}\\n")

# Set up screen
screen = turtle.Screen()
screen.setup(width=500, height=500)
screen.bgcolor("white")
screen.tracer(0)  # Turn off animation

# Create turtle
t = turtle.Turtle()
t.speed(0)

# Execute the provided turtle code
{cleaned_code}

# Update screen and save state
screen.update()
time.sleep(0.5)  # Give time for drawing to complete

# Save turtle state
save_turtle_state(t, "{output_basename}.log")

# Save image
canvas = screen.getcanvas()
canvas.postscript(file="{output_basename}.eps", colormode="color")

# Close the screen
screen.bye()
"""
    return script


def run_turtle_code(code, output_basename):
    """
    Runs the provided turtle code and captures the output.
    """
    # Create a wrapper script
    wrapper_script = create_wrapper_script(code, output_basename)

    # Write to temporary file
    with tempfile.NamedTemporaryFile(suffix=".py", delete=False, mode="w") as temp_file:
        temp_file.write(wrapper_script)
        script_path = temp_file.name

    try:
        # Run the script
        print(f"Running turtle code for {output_basename}...")
        result = subprocess.run(
            [sys.executable, script_path],
            capture_output=True,
            text=True,
            timeout=30,  # 30 seconds timeout
        )

        if result.returncode != 0:
            print(f"Error running script: {result.stderr}")
            # Save the script for debugging
            debug_path = f"{output_basename}_debug.py"
            with open(debug_path, "w") as f:
                f.write(wrapper_script)
            print(f"Script saved for debugging at: {debug_path}")
            return False

        # Clean up temporary file
        os.unlink(script_path)
        return True

    except subprocess.TimeoutExpired:
        print(f"Timeout: Script took too long to execute")
        os.unlink(script_path)
        return False
    except Exception as e:
        print(f"Error: {e}")
        os.unlink(script_path)
        return False


def compare_outputs(teacher_log, student_log):
    """
    Compares the teacher and student outputs.
    """
    try:
        with open(teacher_log, "r") as f:
            teacher_content = f.read()
        with open(student_log, "r") as f:
            student_content = f.read()
    except Exception as e:
        print(f"Error reading logs: {e}")
        return 0

    # Print the contents for debugging
    print("\nTeacher output:")
    print(teacher_content)
    print("\nStudent output:")
    print(student_content)

    # Perfect match
    if teacher_content == student_content:
        return 1.0

    # Otherwise, compute similarity
    similarity = difflib.SequenceMatcher(None, teacher_content, student_content).ratio()
    return similarity


def test_turtle_code(teacher_code, student_code):
    """
    Tests student code against teacher code.
    """
    teacher_result = run_turtle_code(teacher_code, "teacher_output")
    student_result = run_turtle_code(student_code, "student_output")

    if not teacher_result or not student_result:
        print("Failed to run one or both scripts.")
        return False

    print("Comparing outputs...")
    similarity = compare_outputs("teacher_output.log", "student_output.log")

    print(f"Similarity score: {similarity:.4f}")

    if similarity >= COMPARISON_THRESHOLD:
        print(
            f"✅ PASSED: Similarity score {similarity:.4f} is above threshold {COMPARISON_THRESHOLD}"
        )
        return True
    else:
        print(
            f"❌ FAILED: Similarity score {similarity:.4f} is below threshold {COMPARISON_THRESHOLD}"
        )
        return False


def load_default_code(filepath):
    """
    Loads the default code from a JSON file.
    If the defaultcode is a dictionary, it extracts the "python" key.
    """
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
            default_code = data.get("defaultcode", "")
            # If defaultcode is a dictionary, extract the "python" key
            if isinstance(default_code, dict):
                return default_code.get("python", "")
            return default_code
    except Exception as e:
        print(f"Error loading defaultcode from {filepath}: {e}")
        return ""


# Load default code from JSON files
teacher_code = load_default_code("teachers.json")
student_code = load_default_code("students.json")


def main():
    parser = argparse.ArgumentParser(description="Test turtle code solutions")
    parser.add_argument("--teacher", help="Path to teacher's solution file")
    parser.add_argument("--student", help="Path to student's solution file")
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.9,
        help="Similarity threshold (0.0 to 1.0, default: 0.9)",
    )

    args = parser.parse_args()

    global COMPARISON_THRESHOLD
    COMPARISON_THRESHOLD = args.threshold

    # Load default code from JSON files
    teacher_code = load_default_code("teachers.json")
    student_code = load_default_code("students.json")

    # Override with code from files if provided
    if args.teacher:
        loaded_code = load_default_code(args.teacher)
        if loaded_code:
            teacher_code = loaded_code

    if args.student:
        loaded_code = load_default_code(args.student)
        if loaded_code:
            student_code = loaded_code

    print("Testing turtle code...")
    result = test_turtle_code(teacher_code, student_code)

    if result:
        print("Student solution matches the expected output!")
    else:
        print("Student solution does not match the expected output.")

    # Clean up temporary files
    for ext in [".eps", ".log"]:
        for prefix in ["teacher_output", "student_output"]:
            filepath = f"{prefix}{ext}"
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                except:
                    pass


if __name__ == "__main__":
    main()
