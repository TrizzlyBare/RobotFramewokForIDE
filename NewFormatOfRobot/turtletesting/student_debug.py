#!/usr/bin/env python
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

# Create universal turtle environment
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
        
# Initialize t as a turtle
try:
    t = turtle.Turtle()
except Exception:
    t = Turtle()



# Variable to store the output instead of writing to log file
student_output = io.StringIO()

# Run the user code inside a try block
try:
    import turtle
    
    t = turtle.Turtle()
    t.pensize(2)
    for _ in range(3):
        t.forward(100)
        t.left(90)
    
    # done() removed

    # After the user code finishes, save the output
    time.sleep(0.2)  # Small pause to ensure drawing is done
    
    # Store turtle states in memory
    student_output.write("TURTLE_STATE_BEGIN\n")
    
    # Get all turtles in the screen
    turtles = screen.turtles() if screen else []
    
    # If no turtles found in screen, use our explicitly created ones
    if not turtles and 't' in locals():
        turtles = [t]
        
    
    # Special case for turtle module functions
    if not turtles and 'turtle' in sys.modules:
        try:
            turtles = [sys.modules['turtle']._getpen()]
        except:
            pass
    
    # Log turtle count
    student_output.write(f"Number of turtles: {len(turtles)}\n")
    
    # Log details for each turtle
    for i, turt in enumerate(turtles):
        student_output.write(f"\nTurtle {i+1}:\n")
        
        # Get position
        try:
            pos = turt.position()
            student_output.write(f"Position: {pos[0]}, {pos[1]}\n")
        except Exception as e:
            student_output.write(f"Position: Error {e}\n")
        
        # Get heading
        try:
            student_output.write(f"Heading: {turt.heading()}\n")
        except Exception as e:
            student_output.write(f"Heading: Error {e}\n")
        
        # Get pen state
        try:
            student_output.write(f"Pen down: {turt.isdown()}\n")
        except Exception as e:
            student_output.write(f"Pen down: Error {e}\n")
        
        # Get pen color
        try:
            student_output.write(f"Pen color: {turt.pencolor()}\n")
        except Exception as e:
            student_output.write(f"Pen color: Error {e}\n")
        
        # Get fill color
        try:
            student_output.write(f"Fill color: {turt.fillcolor()}\n")
        except Exception as e:
            student_output.write(f"Fill color: Error {e}\n")
        
        # Get pen size
        try:
            student_output.write(f"Pen size: {turt.pensize()}\n")
        except Exception as e:
            student_output.write(f"Pen size: Error {e}\n")
        
        # Get visibility
        try:
            student_output.write(f"Visible: {turt.isvisible()}\n")
        except Exception as e:
            student_output.write(f"Visible: Error {e}\n")
    
    student_output.write("TURTLE_STATE_END\n")
    
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
    output_str = student_output.getvalue()
    print("OUTPUT_DELIMITER_START")
    print(output_str)
    print("OUTPUT_DELIMITER_END")
    
    sys.exit(0)
    
except Exception as e:
    # Log the error
    error_msg = str(e)
    print(f"Error running code: {error_msg}")
    
    # Store error info in memory without creating a log file
    student_output.write(f"ERROR: {error_msg}\n\n")
    student_output.write("Traceback:\n")
    
    import traceback
    traceback_io = io.StringIO()
    traceback.print_exc(file=traceback_io)
    student_output.write(traceback_io.getvalue())
    
    # Print the error output
    error_output = student_output.getvalue()
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
