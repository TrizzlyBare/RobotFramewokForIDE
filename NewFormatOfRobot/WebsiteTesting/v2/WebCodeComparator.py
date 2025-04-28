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

        # NEW: Check the order of elements
        self._check_element_order(student_soup, teacher_soup, differences)

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

    def _check_element_order(self, student_soup, teacher_soup, differences):
        """
        Check if elements appear in the same order in both documents
        Focus on color boxes, headings, and interactive elements
        """
        # Check order of color boxes
        teacher_color_boxes = teacher_soup.find_all(class_="color-box")
        student_color_boxes = student_soup.find_all(class_="color-box")

        if len(teacher_color_boxes) > 1 and len(student_color_boxes) > 1:
            # Extract background colors for comparison
            teacher_colors = []
            student_colors = []

            for box in teacher_color_boxes:
                style = box.get("style", "")
                color_match = re.search(r"background-color:\s*([^;]+)", style)
                if color_match:
                    teacher_colors.append(color_match.group(1).strip())

            for box in student_color_boxes:
                style = box.get("style", "")
                color_match = re.search(r"background-color:\s*([^;]+)", style)
                if color_match:
                    student_colors.append(color_match.group(1).strip())

            # Compare order only if we have the same colors
            if (
                sorted(teacher_colors) == sorted(student_colors)
                and teacher_colors != student_colors
            ):
                differences.append(
                    f"Color boxes are in wrong order. Expected: {', '.join(teacher_colors)}"
                )

        # Check order of heading elements
        container = teacher_soup.find(class_="container")
        student_container = student_soup.find(class_="container")

        if container and student_container:
            teacher_headings = container.find_all(["h1", "h2", "h3", "h4", "h5", "h6"])
            student_headings = student_container.find_all(
                ["h1", "h2", "h3", "h4", "h5", "h6"]
            )

            if len(teacher_headings) > 1 and len(student_headings) > 1:
                teacher_heading_texts = [h.get_text().strip() for h in teacher_headings]
                student_heading_texts = [h.get_text().strip() for h in student_headings]

                if (
                    sorted(teacher_heading_texts) == sorted(student_heading_texts)
                    and teacher_heading_texts != student_heading_texts
                ):
                    differences.append(
                        f"Heading order is incorrect. Expected: {', '.join(teacher_heading_texts)}"
                    )

        # Check order of interactive elements (buttons, inputs)
        teacher_interactive = teacher_soup.find_all(
            ["button", "input", "select", "textarea"]
        )
        student_interactive = student_soup.find_all(
            ["button", "input", "select", "textarea"]
        )

        if len(teacher_interactive) > 1 and len(student_interactive) > 1:
            teacher_interactive_types = [
                elem.name
                + (f"[type={elem.get('type', '')}]" if elem.get("type") else "")
                for elem in teacher_interactive
            ]
            student_interactive_types = [
                elem.name
                + (f"[type={elem.get('type', '')}]" if elem.get("type") else "")
                for elem in student_interactive
            ]

            if teacher_interactive_types != student_interactive_types:
                differences.append(
                    f"Interactive elements order is incorrect. Expected: {', '.join(teacher_interactive_types)}"
                )

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

        # NEW: Check the order of CSS rules
        self._check_css_rule_order(student_css, teacher_css, differences)

        # If no specific differences found, show general message
        if not differences:
            differences.append(
                "CSS files differ but no specific rule differences were detected. Check for whitespace, comments, or formatting differences."
            )

        return differences

    def _check_css_rule_order(self, student_css, teacher_css, differences):
        """
        Check if CSS rules appear in the same order in both files
        """
        # Extract selectors in order (simple version)
        teacher_selectors = re.findall(r"([^\s,{]+)\s*{", teacher_css)
        student_selectors = re.findall(r"([^\s,{]+)\s*{", student_css)

        # We'll check the key selectors that should be in order
        key_selectors = ["body", ".container", "header", "button", ".color-box"]

        # Filter to only include key selectors that exist in both files
        teacher_key_order = [s for s in teacher_selectors if s in key_selectors]
        student_key_order = [s for s in student_selectors if s in key_selectors]

        # Check if the key selectors are in the same order
        if len(teacher_key_order) > 1 and len(student_key_order) > 1:
            if teacher_key_order != student_key_order:
                differences.append(
                    f"CSS selector order is incorrect. Expected: {', '.join(teacher_key_order)}"
                )

        # Check order of properties within selectors
        for selector in key_selectors:
            teacher_selector_match = re.search(
                rf"{re.escape(selector)}\s*{{([^}}]*)}}", teacher_css
            )
            student_selector_match = re.search(
                rf"{re.escape(selector)}\s*{{([^}}]*)}}", student_css
            )

            if teacher_selector_match and student_selector_match:
                teacher_props = re.findall(
                    r"(\b\w+(?:-\w+)*)\s*:", teacher_selector_match.group(1)
                )
                student_props = re.findall(
                    r"(\b\w+(?:-\w+)*)\s*:", student_selector_match.group(1)
                )

                if len(teacher_props) > 2 and len(student_props) > 2:
                    # Check if properties are in different order but contain the same values
                    if (
                        sorted(teacher_props) == sorted(student_props)
                        and teacher_props != student_props
                    ):
                        differences.append(
                            f"Properties in {selector} are in wrong order. Expected: {', '.join(teacher_props[:3])}..."
                        )

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

        # NEW: Check the order of event listeners and function declarations
        self._check_js_order(student_js, teacher_js, differences)

        # If no specific differences found, show general message
        if not differences and student_js != teacher_js:
            differences.append(
                "JavaScript files differ but no specific functional differences were detected. Check for whitespace, comments, or formatting differences."
            )

        return differences

    def _check_js_order(self, student_js, teacher_js, differences):
        """
        Check if JavaScript event listeners and functions appear in the correct order
        """
        # Check order of event handler registrations
        teacher_listeners = re.findall(r'addEventListener\([\'"](\w+)[\'"]', teacher_js)
        student_listeners = re.findall(r'addEventListener\([\'"](\w+)[\'"]', student_js)

        if len(teacher_listeners) >= 2 and len(student_listeners) >= 2:
            # For addEventListener, check if they're in the same order
            if teacher_listeners != student_listeners:
                differences.append(
                    f"Event listener registration order is incorrect. Expected: {', '.join(teacher_listeners)}"
                )

        # Check order of variable declarations
        teacher_vars = re.findall(r"const\s+(\w+)\s*=", teacher_js)
        student_vars = re.findall(r"const\s+(\w+)\s*=", student_js)

        if len(teacher_vars) >= 2 and len(student_vars) >= 2:
            # For important vars like 'button' and 'result', check their order
            important_vars = ["result", "contactForm", "button"]
            teacher_important = [v for v in teacher_vars if v in important_vars]
            student_important = [v for v in student_vars if v in important_vars]

            if len(teacher_important) >= 2 and len(student_important) >= 2:
                if teacher_important != student_important:
                    differences.append(
                        f"Variable declaration order is incorrect. Expected: {', '.join(teacher_important)}"
                    )

        # Check the order of operations in event handlers
        # This is approximated by looking at patterns of assignments and method calls
        if "addEventListener" in teacher_js and "addEventListener" in student_js:
            # Extract the click event handler content
            teacher_handler = re.search(
                r"click\'\),\s*function\(\)\s*{([^}]*)}", teacher_js
            )
            student_handler = re.search(
                r"click\'\),\s*function\(\)\s*{([^}]*)}", student_js
            )

            if teacher_handler and student_handler:
                # Look for operation sequences like setting properties or calling methods
                teacher_ops = re.findall(
                    r"(\w+\.\w+(?:\.\w+)*)\s*=|(\w+\.\w+\()", teacher_handler.group(1)
                )
                student_ops = re.findall(
                    r"(\w+\.\w+(?:\.\w+)*)\s*=|(\w+\.\w+\()", student_handler.group(1)
                )

                # Flatten results and remove None entries
                teacher_ops_flat = [
                    op[0] or op[1] for op in teacher_ops if op[0] or op[1]
                ]
                student_ops_flat = [
                    op[0] or op[1] for op in student_ops if op[0] or op[1]
                ]

                if len(teacher_ops_flat) >= 2 and len(student_ops_flat) >= 2:
                    if teacher_ops_flat != student_ops_flat:
                        differences.append(
                            f"Operations in event handler are in wrong order. Expected: {', '.join(teacher_ops_flat[:2])}..."
                        )

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
