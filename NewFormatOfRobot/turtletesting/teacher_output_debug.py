
import turtle
import os
import time

# Function to capture turtle state
def save_turtle_state(t, filepath):
    with open(filepath, "w") as f:
        f.write(f"Position: {t.xcor()}, {t.ycor()}\n")
        f.write(f"Heading: {t.heading()}\n")
        f.write(f"Pen down: {t.isdown()}\n")
        f.write(f"Pen color: {t.pencolor()}\n")
        f.write(f"Fill color: {t.fillcolor()}\n")
        f.write(f"Pen size: {t.pensize()}\n")

# Set up screen
screen = turtle.Screen()
screen.setup(width=500, height=500)
screen.bgcolor("white")
screen.tracer(0)  # Turn off animation

# Create turtle
t = turtle.Turtle()
t.speed(0)

# Execute the provided turtle code
import turtle

.penup()
t.goto(-100, 100)
t.pendown()
t.goto(0, 200)
t.goto(100, 100)

# Update screen and save state
screen.update()
time.sleep(0.5)  # Give time for drawing to complete

# Save turtle state
save_turtle_state(t, "teacher_output.log")

# Save image
canvas = screen.getcanvas()
canvas.postscript(file="teacher_output.eps", colormode="color")

# Close the screen
screen.bye()
