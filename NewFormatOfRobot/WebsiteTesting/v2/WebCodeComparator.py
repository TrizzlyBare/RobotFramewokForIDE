# WebCodeComparator.py
import re
import difflib
import json
from bs4 import BeautifulSoup
import logging


class WebCodeComparator:
    """
    Enhanced web code comparator that provides detailed, specific feedback
    on differences between HTML, CSS, and JavaScript code
    """

    def __init__(self, tolerance_level=1):
        """
        Initialize the comparator with configurable tolerance
        tolerance_level: 0=strict, 1=normal, 2=lenient
        """
        self.tolerance_level = tolerance_level

    def compare_html(self, student_html, teacher_html):
        """
        Compare HTML code with detailed feedback on specific differences
        Returns a list of specific difference messages
        """
        differences = []

        # Quick string equality check
        if student_html == teacher_html:
            return differences

        # Parse HTML
        try:
            student_soup = BeautifulSoup(student_html, "html.parser")
            teacher_soup = BeautifulSoup(teacher_html, "html.parser")
        except Exception as e:
            differences.append(f"HTML parsing error: {str(e)}")
            return differences

        # Check body tag for background color
        student_body = student_soup.find("body")
        teacher_body = teacher_soup.find("body")

        if teacher_body and student_body:
            # Check if body has background-color in style
            if "style" in teacher_body.attrs:
                teacher_style = teacher_body["style"]
                student_style = student_body.get("style", "")

                if (
                    "background-color" in teacher_style
                    and "background-color" not in student_style
                ):
                    # Extract the specific background color
                    bg_color_match = re.search(
                        r"background-color:\s*([^;]+)", teacher_style
                    )
                    if bg_color_match:
                        bg_color = bg_color_match.group(1).strip()
                        differences.append(f"Missing body background-color: {bg_color}")
                    else:
                        differences.append(
                            "Missing background-color property in body style"
                        )

        # Compare styles in <style> tags
        teacher_styles = teacher_soup.find_all("style")
        student_styles = student_soup.find_all("style")

        if teacher_styles and not student_styles:
            differences.append("Missing <style> tag in HTML")
        elif teacher_styles and student_styles:
            # Compare content of first style tag
            teacher_style_content = (
                teacher_styles[0].string if teacher_styles[0].string else ""
            )
            student_style_content = (
                student_styles[0].string if student_styles[0].string else ""
            )

            # Check for background-color in body selector
            if "body" in teacher_style_content:
                teacher_body_bg = re.search(
                    r"body\s*{[^}]*background-color:\s*([^;]+)", teacher_style_content
                )
                student_body_bg = re.search(
                    r"body\s*{[^}]*background-color:\s*([^;]+)", student_style_content
                )

                if teacher_body_bg and not student_body_bg:
                    bg_color = teacher_body_bg.group(1).strip()
                    differences.append(
                        f"Missing background-color: {bg_color} in body style rule"
                    )

        # Compare h1, h2, h3 text content
        for tag in ["h1", "h2", "h3"]:
            teacher_headings = teacher_soup.find_all(tag)
            student_headings = student_soup.find_all(tag)

            # Check if counts match
            if len(teacher_headings) > len(student_headings):
                differences.append(
                    f"Missing {tag} elements: expected {len(teacher_headings)}, found {len(student_headings)}"
                )
                continue

            # Check text content
            for i, teacher_heading in enumerate(teacher_headings):
                if i < len(student_headings):
                    if (
                        teacher_heading.get_text().strip()
                        != student_headings[i].get_text().strip()
                    ):
                        differences.append(
                            f"Text mismatch in {tag}: expected '{teacher_heading.get_text().strip()}', found '{student_headings[i].get_text().strip()}'"
                        )

        # Compare specific elements by class
        for class_name in ["container", "color-box"]:
            teacher_elements = teacher_soup.find_all(class_=class_name)
            student_elements = student_soup.find_all(class_=class_name)

            if len(teacher_elements) > len(student_elements):
                differences.append(
                    f"Missing elements with class '{class_name}': expected {len(teacher_elements)}, found {len(student_elements)}"
                )

        # Check for button element with click event
        teacher_buttons = teacher_soup.find_all("button")
        student_buttons = student_soup.find_all("button")

        if teacher_buttons and not student_buttons:
            differences.append("Missing <button> element")
        elif teacher_buttons and student_buttons:
            # Check for onclick attribute
            teacher_button = teacher_buttons[0]
            student_button = student_buttons[0]

            if (
                "onclick" in teacher_button.attrs
                and "onclick" not in student_button.attrs
            ):
                onclick_value = teacher_button["onclick"]
                differences.append(
                    f"Missing onclick attribute in button: {onclick_value}"
                )

        # If no differences found but HTML doesn't match, check for line-by-line differences
        if not differences and student_html != teacher_html:
            line_differences = self._compare_code_line_by_line(
                student_html, teacher_html
            )
            if line_differences:
                differences.extend(line_differences)
            else:
                # If still no specific differences found, suggest checking whitespace or comments
                differences.append(
                    "HTML files differ but no specific structural differences were detected. Check for whitespace, comments, or text content differences."
                )

        return differences

    def compare_css(self, student_css, teacher_css):
        """
        Compare CSS code with detailed feedback on specific differences
        Returns a list of specific difference messages
        """
        differences = []

        # Quick string equality check
        if student_css == teacher_css:
            return differences

        # Look for specific selectors and properties
        selectors_to_check = {
            "body": ["background-color", "font-family", "margin", "color"],
            "button": ["background-color", "color", "border", "padding", "cursor"],
            ".container": [
                "background-color",
                "border-radius",
                "padding",
                "box-shadow",
            ],
            ".color-box": ["display", "width", "height", "margin", "border-radius"],
        }

        for selector, properties in selectors_to_check.items():
            # Check if selector exists in both CSS
            teacher_selector = re.search(
                rf"{re.escape(selector)}\s*{{([^}}]*?)}}", teacher_css
            )
            student_selector = re.search(
                rf"{re.escape(selector)}\s*{{([^}}]*?)}}", student_css
            )

            if teacher_selector and not student_selector:
                differences.append(f"Missing CSS selector: {selector}")
                continue

            if teacher_selector and student_selector:
                teacher_properties = teacher_selector.group(1)
                student_properties = student_selector.group(1)

                # Check for specific properties
                for prop in properties:
                    teacher_prop = re.search(
                        rf"{re.escape(prop)}\s*:\s*([^;]+)", teacher_properties
                    )
                    student_prop = re.search(
                        rf"{re.escape(prop)}\s*:\s*([^;]+)", student_properties
                    )

                    if teacher_prop and not student_prop:
                        prop_value = teacher_prop.group(1).strip()
                        differences.append(
                            f"Missing CSS property in {selector}: {prop}: {prop_value}"
                        )
                    elif (
                        teacher_prop
                        and student_prop
                        and teacher_prop.group(1).strip()
                        != student_prop.group(1).strip()
                    ):
                        teacher_value = teacher_prop.group(1).strip()
                        student_value = student_prop.group(1).strip()
                        differences.append(
                            f"CSS property value mismatch in {selector}: {prop} should be '{teacher_value}' but found '{student_value}'"
                        )

        # If no specific differences found, show general message
        if not differences:
            differences.append(
                "CSS files differ but no specific rule differences were detected. Check for whitespace, comments, or formatting differences."
            )

        return differences

    def compare_js(self, student_js, teacher_js):
        """
        Compare JavaScript code with detailed feedback on specific differences
        Returns a list of specific difference messages
        """
        differences = []

        # Quick string equality check
        if student_js == teacher_js:
            return differences

        # Check for event listeners
        event_patterns = [
            (r'addEventListener\([\'"](\w+)[\'"]', "addEventListener method"),
            (r"\.on(\w+)\s*=", "on-event property"),
            (r'document\.getElementById\([\'"](\w+)[\'"]', "getElementById method"),
        ]

        for pattern, description in event_patterns:
            teacher_matches = re.findall(pattern, teacher_js)
            student_matches = re.findall(pattern, student_js)

            # Find missing patterns
            for match in teacher_matches:
                if match not in student_matches:
                    differences.append(f"Missing JavaScript {description}: '{match}'")

        # Check for specific function/event handlers
        js_features = [
            ("DOMContentLoaded", "DOMContentLoaded event listener"),
            ("result.textContent", "setting textContent property"),
            ("style.backgroundColor", "setting backgroundColor style property"),
            ("preventDefault", "preventDefault method call"),
            ("contactForm.reset", "form reset method call"),
        ]

        for feature, description in js_features:
            if feature in teacher_js and feature not in student_js:
                differences.append(f"Missing JavaScript feature: {description}")

        # If no specific differences found, show general message
        if not differences:
            differences.append(
                "JavaScript files differ but no specific functional differences were detected. Check for whitespace, comments, or formatting differences."
            )

        return differences

    def _compare_code_line_by_line(self, student_code, teacher_code, max_diffs=3):
        """Compare code line by line to find specific differences"""
        differences = []

        # Split code into lines
        student_lines = student_code.split("\n")
        teacher_lines = teacher_code.split("\n")

        # Use difflib to find differences
        diff = list(difflib.ndiff(student_lines, teacher_lines))

        # Extract significant differences (not just whitespace)
        significant_diffs = []
        for line in diff:
            if line.startswith("- ") or line.startswith("+ "):
                content = line[2:].strip()
                if content and not self._is_trivial_difference(content):
                    significant_diffs.append(line)

        # Limit to a reasonable number of differences
        if significant_diffs:
            shown_diffs = significant_diffs[:max_diffs]
            for line in shown_diffs:
                prefix = "Missing" if line.startswith("+ ") else "Extra/Different"
                differences.append(f"{prefix} line: {line[2:]}")

        return differences

    def _is_trivial_difference(self, content):
        """Check if a difference is trivial (whitespace, comments, etc.)"""
        # Ignore empty lines or comment-only lines
        if (
            not content
            or content.strip().startswith("//")
            or content.strip().startswith("/*")
        ):
            return True
        # Ignore lines that only differ in whitespace
        if content.isspace():
            return True
        return False
