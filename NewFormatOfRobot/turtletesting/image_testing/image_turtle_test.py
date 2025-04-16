import os
import sys
import subprocess
import tempfile
import textwrap
import traceback
import cv2
import numpy as np
from skimage.metrics import structural_similarity as ssim
import math
from PIL import Image, ImageDraw, ImageColor
import colorsys
import re
import json

# Configuration
COMPARISON_THRESHOLD = 0.99


def clean_code(code):
    cleaned = textwrap.dedent(code).strip()
    return cleaned


def simulate_turtle(code, output_filename, width=500, height=500):
    try:
        # Create a blank image
        img = Image.new("RGB", (width, height), "white")
        draw = ImageDraw.Draw(img)

        # Create a turtle simulator class
        class TurtleSimulator:
            def __init__(self):
                self.x = width / 2
                self.y = height / 2
                self._heading = 90  # Facing up (in degrees)
                self.pen_down = True
                self.pen_width = 3
                self.pen_color = (0, 0, 0)  # Black
                self.fill_color = (0, 0, 0)  # Black
                self.filling = False
                self.fill_points = []
                self._visible = True
                self._speed = 6

                # For storing state
                self.state_stack = []

            def forward(self, distance):
                # Calculate new position
                angle_rad = math.radians(self._heading)
                new_x = self.x + distance * math.cos(angle_rad)
                new_y = self.y - distance * math.sin(
                    angle_rad
                )  # Y is inverted in image coords

                # Draw line if pen is down
                if self.pen_down:
                    draw.line(
                        [(self.x, self.y), (new_x, new_y)],
                        fill=self.pen_color,
                        width=self.pen_width,
                    )

                # If filling, store the points
                if self.filling:
                    self.fill_points.append((new_x, new_y))

                # Update position
                self.x, self.y = new_x, new_y

            def backward(self, distance):
                self.forward(-distance)

            def right(self, angle):
                self._heading -= angle
                self._heading %= 360

            def left(self, angle):
                self._heading += angle
                self._heading %= 360

            def setheading(self, angle):
                self._heading = angle % 360

            def seth(self, angle):
                self.setheading(angle)

            def pendown(self):
                self.pen_down = True

            def penup(self):
                self.pen_down = False

            def pensize(self, width):
                self.pen_width = width

            def width(self, width):
                self.pensize(width)

            def _parse_color(self, color):
                """Parse color from various formats."""
                try:
                    # Handle string color names
                    if isinstance(color, str):
                        # Check if it's a hex color
                        if color.startswith("#"):
                            return ImageColor.getrgb(color)

                        # Check if it's a CSS-style rgb
                        rgb_match = re.match(
                            r"rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", color
                        )
                        if rgb_match:
                            return tuple(map(int, rgb_match.groups()))

                        # Try to get from PIL's color map
                        try:
                            return ImageColor.getrgb(color)
                        except ValueError:
                            # Fallback to a large color dictionary
                            color_map = {
                                "black": (0, 0, 0),
                                "white": (255, 255, 255),
                                "red": (255, 0, 0),
                                "green": (0, 255, 0),
                                "blue": (0, 0, 255),
                                "yellow": (255, 255, 0),
                                "purple": (128, 0, 128),
                                "orange": (255, 165, 0),
                                "pink": (255, 192, 203),
                                "brown": (165, 42, 42),
                                "gray": (128, 128, 128),
                                "grey": (128, 128, 128),
                                "cyan": (0, 255, 255),
                                "magenta": (255, 0, 255),
                                "lime": (0, 255, 0),
                                "navy": (0, 0, 128),
                                "aqua": (0, 255, 255),
                                "teal": (0, 128, 128),
                                "violet": (238, 130, 238),
                                "maroon": (128, 0, 0),
                                "gold": (255, 215, 0),
                                "silver": (192, 192, 192),
                            }
                            return color_map.get(color.lower(), (0, 0, 0))

                    # Handle RGB tuple
                    elif isinstance(color, tuple):
                        if len(color) == 3:
                            return color

                    # Handle RGB as separate arguments
                    elif isinstance(color, (int, float)) and 0 <= color <= 1:
                        # Convert from turtle's 0-1 RGB scale to 0-255
                        r = int(color * 255)
                        g = int(color * 255)
                        b = int(color * 255)
                        return (r, g, b)

                except Exception as e:
                    print(f"Color parsing error: {e}, using default black")

                return (0, 0, 0)  # Default to black on failure

            def pencolor(self, *args):
                """Set the pen color. Can accept different formats:
                - pencolor("red")
                - pencolor(0.5, 0.5, 1.0)  # RGB values between 0 and 1
                - pencolor((0.5, 0.5, 1.0))  # RGB tuple
                - pencolor("#FF0000")  # Hex color
                """
                if len(args) == 1:
                    # Single argument - either a color name or RGB tuple
                    color = args[0]
                    self.pen_color = self._parse_color(color)
                elif len(args) == 3:
                    # Three arguments - individual RGB values (0-1)
                    r, g, b = args
                    # Convert to 0-255 range
                    self.pen_color = (int(r * 255), int(g * 255), int(b * 255))

            def fillcolor(self, *args):
                """Set the fill color. Same formats as pencolor."""
                if len(args) == 1:
                    color = args[0]
                    self.fill_color = self._parse_color(color)
                elif len(args) == 3:
                    r, g, b = args
                    self.fill_color = (int(r * 255), int(g * 255), int(b * 255))

            def color(self, *args):
                """Set both pen and fill colors."""
                if len(args) == 1:
                    # Single argument sets both to the same color
                    self.pencolor(args[0])
                    self.fillcolor(args[0])
                elif len(args) == 2:
                    # Two arguments: first for pen, second for fill
                    self.pencolor(args[0])
                    self.fillcolor(args[1])
                elif len(args) == 3:
                    # Three arguments: RGB values for both pen and fill
                    self.pencolor(args[0], args[1], args[2])
                    self.fillcolor(args[0], args[1], args[2])

            def begin_fill(self):
                self.filling = True
                self.fill_points = [(self.x, self.y)]  # Start with current position

            def end_fill(self):
                if self.filling and len(self.fill_points) >= 3:
                    draw.polygon(self.fill_points, fill=self.fill_color, outline=None)
                self.filling = False
                self.fill_points = []

            def goto(self, x, y=None):
                # Handle both goto(x,y) and goto((x,y))
                if y is None and isinstance(x, tuple):
                    x, y = x

                # Adjust coordinates to center
                x_canvas = width / 2 + x
                y_canvas = height / 2 - y  # Y is inverted

                # Draw line if pen is down
                if self.pen_down:
                    draw.line(
                        [(self.x, self.y), (x_canvas, y_canvas)],
                        fill=self.pen_color,
                        width=self.pen_width,
                    )

                # If filling, store the points
                if self.filling:
                    self.fill_points.append((x_canvas, y_canvas))

                # Update position
                self.x, self.y = x_canvas, y_canvas

            def setpos(self, x, y=None):
                self.goto(x, y)

            def setposition(self, x, y=None):
                self.goto(x, y)

            def circle(self, radius, extent=None, steps=None):
                if extent is None:
                    extent = 360

                if steps is None:
                    steps = max(int(abs(radius) / 2), 36)

                # Calculate angle for each step
                step_angle = extent / steps

                # Save starting position
                start_x, start_y = self.x, self.y
                start_heading = self._heading

                # Move to radius position for drawing
                self.right(90)
                old_pen = self.pen_down
                self.pen_down = False
                self.forward(radius)
                self.pen_down = old_pen
                self.left(90)

                # For filled circles, add the first point
                if self.filling:
                    self.fill_points.append((self.x, self.y))

                # Draw the circle
                for _ in range(steps):
                    self.forward(2 * math.pi * abs(radius) / steps)
                    if radius > 0:
                        self.left(step_angle)
                    else:
                        self.right(step_angle)

                # If we're filling and it's a complete circle, close the shape
                if self.filling and abs(extent) >= 359:
                    self.fill_points.append((self.x, self.y))

                # Return to original heading
                self._heading = start_heading

            def dot(self, size=None, color=None):
                """Draw a dot at the current position."""
                if size is None:
                    size = max(self.pen_width + 4, self.pen_width * 2)

                dot_color = self.pen_color
                if color is not None:
                    dot_color = self._parse_color(color)

                half_size = size / 2
                draw.ellipse(
                    [
                        (self.x - half_size, self.y - half_size),
                        (self.x + half_size, self.y + half_size),
                    ],
                    fill=dot_color,
                    outline=None,
                )

            def home(self):
                """Move turtle to the origin - center of the screen."""
                old_pen = self.pen_down
                if not old_pen:
                    self.pendown()
                self.goto(0, 0)
                self.setheading(90)
                if not old_pen:
                    self.penup()

            def speed(self, speed=None):
                """Set or return the turtle's speed."""
                if speed is None:
                    return self._speed
                self._speed = speed

            def hideturtle(self):
                self._visible = False

            def showturtle(self):
                self._visible = True

            def isvisible(self):
                return self._visible

            def fd(self, distance):
                self.forward(distance)

            def bk(self, distance):
                self.backward(distance)

            def back(self, distance):
                self.backward(distance)

            def rt(self, angle):
                self.right(angle)

            def lt(self, angle):
                self.left(angle)

            def pu(self):
                self.penup()

            def pd(self):
                self.pendown()

            def up(self):
                self.penup()

            def down(self):
                self.pendown()

            # State querying methods
            def isdown(self):
                return self.pen_down

            def xcor(self):
                return self.x - width / 2

            def ycor(self):
                return height / 2 - self.y

            def pos(self):
                return (self.xcor(), self.ycor())

            def position(self):
                return self.pos()

            def heading(self):
                return self._heading

            def towards(self, x, y=None):
                """Return the angle to the point (x, y)"""
                if y is None and isinstance(x, tuple):
                    x, y = x

                dx = x - self.xcor()
                dy = y - self.ycor()

                # Calculate angle, handling edge cases
                if dx == 0:
                    return 90 if dy > 0 else 270
                else:
                    angle = math.degrees(math.atan2(dy, dx))
                    return angle % 360

            # Screen clearing
            def clear(self):
                """Clear all turtle drawings"""
                nonlocal img, draw
                img = Image.new("RGB", (width, height), "white")
                draw = ImageDraw.Draw(img)

            def reset(self):
                """Clear drawings and reset turtle to initial state"""
                self.clear()
                self.__init__()

            # Stack operations for saving and restoring state
            def push(self):
                """Save the current state"""
                state = {
                    "position": (self.x, self.y),
                    "heading": self._heading,
                    "pen_down": self.pen_down,
                    "pen_width": self.pen_width,
                    "pen_color": self.pen_color,
                    "fill_color": self.fill_color,
                    "filling": self.filling,
                    "fill_points": self.fill_points.copy() if self.filling else [],
                    "visible": self._visible,
                }
                self.state_stack.append(state)

            def pop(self):
                """Restore the last saved state"""
                if not self.state_stack:
                    return

                state = self.state_stack.pop()
                self.x, self.y = state["position"]
                self._heading = state["heading"]
                self.pen_down = state["pen_down"]
                self.pen_width = state["pen_width"]
                self.pen_color = state["pen_color"]
                self.fill_color = state["fill_color"]
                self.filling = state["filling"]
                self.fill_points = state["fill_points"]
                self._visible = state["visible"]

        # Create the turtle
        t = TurtleSimulator()
        turtle = t  # Alias for compatibility

        # Execute the turtle code
        cleaned_code = clean_code(code)

        # Create a restricted globals dictionary with safe builtins
        safe_builtins = {}

        # Add allowed built-in functions
        safe_builtins = {
            "__import__": __import__,  # Allow imports
            "abs": abs,
            "all": all,
            "any": any,
            "bool": bool,
            "dict": dict,
            "dir": dir,
            "enumerate": enumerate,
            "float": float,
            "format": format,
            "int": int,
            "len": len,
            "list": list,
            "map": map,
            "max": max,
            "min": min,
            "pow": pow,
            "range": range,
            "round": round,
            "sorted": sorted,
            "str": str,
            "sum": sum,
            "tuple": tuple,
            "zip": zip,
            "math": math,
        }

        safe_builtins["True"] = True
        safe_builtins["False"] = False
        safe_builtins["None"] = None

        safe_globals = {
            "t": t,
            "turtle": turtle,
            "__builtins__": safe_builtins,
        }

        try:
            exec(cleaned_code, safe_globals)
        except Exception as e:
            print(f"Error executing turtle code: {e}")
            traceback.print_exc()
            return False

        # Draw a grid on the image for reference
        grid_img = img.copy()
        grid_draw = ImageDraw.Draw(grid_img)

        # Draw grid lines
        for i in range(0, width, 50):
            grid_draw.line([(i, 0), (i, height)], fill=(200, 200, 200), width=1)
        for i in range(0, height, 50):
            grid_draw.line([(0, i), (width, i)], fill=(200, 200, 200), width=1)

        # Draw center lines more prominently
        grid_draw.line(
            [(width // 2, 0), (width // 2, height)], fill=(150, 150, 150), width=2
        )
        grid_draw.line(
            [(0, height // 2), (width, height // 2)], fill=(150, 150, 150), width=2
        )

        # Save both versions
        img.save(f"{output_filename}.png")
        grid_img.save(f"{output_filename}_grid.png")

        print(f"Turtle drawing saved to {output_filename}.png")
        return True

    except Exception as e:
        print(f"Error simulating turtle: {e}")
        traceback.print_exc()
        return False


def compare_images(teacher_image, student_image):
    """Compares two images using structural similarity."""
    try:
        # Read images
        teacher_img = cv2.imread(teacher_image)
        student_img = cv2.imread(student_image)

        # Check if images were loaded successfully
        if teacher_img is None:
            print(f"Error: Could not read teacher image {teacher_image}")
            return 0

        if student_img is None:
            print(f"Error: Could not read student image {student_image}")
            return 0

        # Convert to grayscale
        teacher_gray = cv2.cvtColor(teacher_img, cv2.COLOR_BGR2GRAY)
        student_gray = cv2.cvtColor(student_img, cv2.COLOR_BGR2GRAY)

        # Print image dimensions
        print(f"Teacher image dimensions: {teacher_gray.shape}")
        print(f"Student image dimensions: {student_gray.shape}")

        # Check for blank images
        teacher_std = np.std(teacher_gray)
        student_std = np.std(student_gray)

        print(f"Teacher image variance: {teacher_std:.2f}")
        print(f"Student image variance: {student_std:.2f}")

        if teacher_std < 1.0:
            print("Warning: Teacher image appears to be blank")

        if student_std < 1.0:
            print("Warning: Student image appears to be blank")

        # Check pixel counts (better for detecting differences in line drawings)
        teacher_pixels = np.sum(teacher_gray < 128)  # Count dark pixels
        student_pixels = np.sum(student_gray < 128)  # Count dark pixels

        print(f"Teacher dark pixels: {teacher_pixels}")
        print(f"Student dark pixels: {student_pixels}")

        # Calculate pixel count ratio (should be close to 1.0 if similar)
        pixel_ratio = (
            min(teacher_pixels, student_pixels) / max(teacher_pixels, student_pixels)
            if max(teacher_pixels, student_pixels) > 0
            else 0
        )
        print(f"Pixel count ratio: {pixel_ratio:.4f}")

        # Resize if needed
        if teacher_gray.shape != student_gray.shape:
            student_gray = cv2.resize(
                student_gray, (teacher_gray.shape[1], teacher_gray.shape[0])
            )

        # Calculate SSIM similarity
        score, diff = ssim(teacher_gray, student_gray, full=True)

        # Use a weighted combination of SSIM and pixel ratio for better detection
        combined_score = (score * 0.7) + (pixel_ratio * 0.3)
        print(f"SSIM score: {score:.4f}")
        print(f"Combined score: {combined_score:.4f}")

        # Create visualization
        diff = (diff * 255).astype("uint8")
        diff_colored = cv2.applyColorMap(255 - diff, cv2.COLORMAP_JET)

        # Save difference image
        cv2.imwrite("difference.png", diff_colored)

        # Create side-by-side comparison
        h, w = teacher_gray.shape
        comparison = np.zeros((h, w * 3), dtype=np.uint8)
        comparison[:, 0:w] = teacher_gray
        comparison[:, w : w * 2] = student_gray
        comparison[:, w * 2 : w * 3] = 255 - diff  # Invert for better visibility

        # Add labels
        font = cv2.FONT_HERSHEY_SIMPLEX
        cv2.putText(comparison, "Teacher", (10, 30), font, 0.8, 255, 2)
        cv2.putText(comparison, "Student", (w + 10, 30), font, 0.8, 255, 2)
        cv2.putText(comparison, "Difference", (w * 2 + 10, 30), font, 0.8, 255, 2)

        cv2.imwrite("comparison.png", comparison)

        return combined_score

    except Exception as e:
        print(f"Error comparing images: {e}")
        import traceback

        traceback.print_exc()
        return 0


def test_turtle_code(teacher_code, student_code):
    """Tests student code against teacher code."""
    print("Simulating teacher's code...")
    teacher_result = simulate_turtle(teacher_code, "teacher_output")

    print("Simulating student's code...")
    student_result = simulate_turtle(student_code, "student_output")

    if not teacher_result or not student_result:
        print("Failed to simulate one or both turtle programs.")
        return False

    print("\nComparing output images...")
    similarity = compare_images("teacher_output.png", "student_output.png")

    print(f"\nFinal similarity score: {similarity:.4f}")

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


# def load_code_from_file(filepath):
#     """Loads turtle code from a file."""
#     try:
#         with open(filepath, "r") as f:
#             return f.read()
#     except Exception as e:
#         print(f"Error reading file {filepath}: {e}")
#         return None


def load_default_code(filepath):
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
            default_code = data.get("defaultcode", "")
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
    import argparse

    parser = argparse.ArgumentParser(description="Automatically test turtle drawings")
    parser.add_argument("--teacher", help="Path to teacher's solution file")
    parser.add_argument("--student", help="Path to student's solution file")
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.99,  # Higher default threshold
        help="Similarity threshold (0-1, default: 0.99)",
    )
    parser.add_argument(
        "--keep-images", action="store_true", help="Keep generated images after testing"
    )
    parser.add_argument(
        "--width", type=int, default=500, help="Width of the canvas (default: 500)"
    )
    parser.add_argument(
        "--height", type=int, default=500, help="Height of the canvas (default: 500)"
    )
    parser.add_argument(
        "--test-only", action="store_true", help="Just run the code without comparison"
    )

    args = parser.parse_args()

    global COMPARISON_THRESHOLD
    if args.threshold:
        COMPARISON_THRESHOLD = args.threshold

    # Load default code from JSON files
    teacher_code = load_default_code("teachers.json")
    student_code = load_default_code("students.json")

    # Load code from files if provided
    if args.teacher:
        loaded_code = load_default_code(args.teacher)
        if loaded_code:
            teacher_code = loaded_code

    if args.student:
        loaded_code = load_default_code(args.student)
        if loaded_code:
            student_code = loaded_code

    # If test only, just run the code without comparison
    if args.test_only:
        print("Running turtle code without comparison...")
        result = simulate_turtle(
            student_code if args.student else teacher_code,
            "output",
            width=args.width,
            height=args.height,
        )
        if result:
            print("\nCode executed successfully.")
            print("Output saved to output.png and output_grid.png")
        else:
            print("\nCode execution failed.")
        return

    print("Starting automated turtle code testing...")
    result = test_turtle_code(teacher_code, student_code)

    if result:
        print("\nTest result: PASS - Student solution matches teacher's solution")
    else:
        print("\nTest result: FAIL - Student solution differs from teacher's solution")

    # Clean up temporary files unless --keep-images is specified
    if not args.keep_images:
        print("\nCleaning up temporary images...")
        image_files = [
            "teacher_output.png",
            "teacher_output_grid.png",
            "student_output.png",
            "student_output_grid.png",
            "difference.png",
            "comparison.png",
        ]

        for file in image_files:
            if os.path.exists(file):
                try:
                    os.remove(file)
                    print(f"Deleted: {file}")
                except Exception as e:
                    print(f"Could not delete {file}: {e}")
    else:
        print("\nOutput files retained:")
        print("- teacher_output.png: Teacher's drawing")
        print("- student_output.png: Student's drawing")
        print("- difference.png: Visualization of differences")
        print("- comparison.png: Side-by-side comparison")


if __name__ == "__main__":
    main()
