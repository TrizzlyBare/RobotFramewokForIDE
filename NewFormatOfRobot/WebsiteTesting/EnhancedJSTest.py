# enhanced_js_test.py
import re
import json
import os
import tempfile
from bs4 import BeautifulSoup
from robot.api.deco import keyword


class JSTestComparator:
    """JavaScript test comparator for Web Course testing framework"""

    def __init__(self, tolerance_level=1):
        """Initialize the JS test comparator

        Args:
            tolerance_level (int): 0=strict, 1=normal, 2=lenient
        """
        self.tolerance_level = tolerance_level
        self.results = {
            "success": True,
            "js_match": True,
            "js_differences": [],
            "missing_elements": [],
        }

    def compare_js(self, user_js, reference_js, html_context=None):
        """Compare JavaScript code for functionality and patterns

        Args:
            user_js (str): User JavaScript code
            reference_js (str): Reference JavaScript code
            html_context (str): HTML context for the JavaScript (optional)

        Returns:
            dict: Comparison results
        """
        # Reset results
        self.results = {
            "success": True,
            "js_match": True,
            "js_differences": [],
            "missing_elements": [],
        }

        # Extract patterns from both code samples
        try:
            user_patterns = self._extract_js_patterns(user_js)
            ref_patterns = self._extract_js_patterns(reference_js)

            # Compare patterns
            self._compare_patterns(user_patterns, ref_patterns)

            # Compare event listeners
            self._compare_event_listeners(user_js, reference_js, html_context)

            # Check for syntax errors and best practices
            self._check_syntax_and_practices(user_js)

        except Exception as e:
            self.results["js_differences"].append(f"Error analyzing JS code: {str(e)}")
            self.results["js_match"] = False
            self.results["success"] = False

        return self.results

    def _extract_js_patterns(self, js_code):
        """Extract important patterns from JavaScript code

        Args:
            js_code (str): JavaScript code

        Returns:
            dict: Extracted patterns
        """
        patterns = {
            "event_handlers": [],
            "dom_selectors": [],
            "dom_manipulations": [],
            "conditionals": [],
            "loops": [],
            "functions": [],
        }

        if not js_code:
            return patterns

        # Extract event handler patterns
        event_patterns = [
            (r'addEventListener\([\'"](\w+)[\'"]', 1),  # addEventListener('event', ...)
            (r"\.on(\w+)\s*=\s*function", 1),  # element.onclick = function...
            (r'on(\w+)\s*=\s*[\'"]', 1),  # <button onclick="...">
        ]

        for pattern, group in event_patterns:
            matches = re.findall(pattern, js_code)
            patterns["event_handlers"].extend([m.lower() for m in matches if m])

        # Extract DOM selector patterns
        selector_patterns = [
            r'document\.getElementById\([\'"](\w+)[\'"]',
            r'document\.querySelector\([\'"]([^\'")]+)[\'"]',
            r'document\.querySelectorAll\([\'"]([^\'")]+)[\'"]',
            r'document\.getElementsByClassName\([\'"](\w+)[\'"]',
            r'document\.getElementsByTagName\([\'"](\w+)[\'"]',
        ]

        for pattern in selector_patterns:
            matches = re.findall(pattern, js_code)
            patterns["dom_selectors"].extend(matches)

        # Extract DOM manipulation patterns
        manipulation_patterns = [
            r"\.innerHTML\s*=",
            r"\.textContent\s*=",
            r"\.innerText\s*=",
            r"\.appendChild\(",
            r"\.removeChild\(",
            r"\.setAttribute\(",
            r"\.style\.(\w+)\s*=",
            r"\.classList\.add\(",
            r"\.classList\.remove\(",
            r"\.classList\.toggle\(",
        ]

        for pattern in manipulation_patterns:
            count = len(re.findall(pattern, js_code))
            if count > 0:
                # Extract the basics of what's being manipulated
                simplified = pattern.replace(r"\(", "").replace(r"\)", "")
                if "." in simplified:
                    simplified = simplified.split(".")[-1]
                if "\\" in simplified:
                    simplified = simplified.split("\\")[0]
                if simplified not in patterns["dom_manipulations"]:
                    patterns["dom_manipulations"].append(simplified)

        # Extract conditionals
        conditional_patterns = [
            r"if\s*\(",
            r"else\s*{",
            r"else\s+if\s*\(",
            r"switch\s*\(",
        ]
        for pattern in conditional_patterns:
            if re.search(pattern, js_code):
                simplified = pattern.replace(r"\(", "").replace(r"\)", "").strip()
                if simplified not in patterns["conditionals"]:
                    patterns["conditionals"].append(simplified)

        # Extract loops
        loop_patterns = [r"for\s*\(", r"while\s*\(", r"do\s*{", r"forEach\("]
        for pattern in loop_patterns:
            if re.search(pattern, js_code):
                simplified = pattern.replace(r"\(", "").replace(r"\)", "").strip()
                if simplified not in patterns["loops"]:
                    patterns["loops"].append(simplified)

        # Extract function definitions
        function_patterns = [
            r"function\s+(\w+)\s*\(",
            r"const\s+(\w+)\s*=\s*function",
            r"let\s+(\w+)\s*=\s*function",
            r"var\s+(\w+)\s*=\s*function",
            r"const\s+(\w+)\s*=\s*\([^)]*\)\s*=>",
            r"let\s+(\w+)\s*=\s*\([^)]*\)\s*=>",
            r"var\s+(\w+)\s*=\s*\([^)]*\)\s*=>",
        ]

        for pattern in function_patterns:
            matches = re.findall(pattern, js_code)
            patterns["functions"].extend(matches)

        return patterns

    def _compare_patterns(self, user_patterns, ref_patterns):
        """Compare JS patterns between user and reference code

        Args:
            user_patterns (dict): User pattern data
            ref_patterns (dict): Reference pattern data
        """
        # Define equivalent patterns for feature detection
        equivalents = {
            "event_handlers": {
                "click": ["click", "onclick"],
                "submit": ["submit", "onsubmit"],
                "change": ["change", "onchange"],
                "input": ["input", "oninput"],
                "keyup": ["keyup", "onkeyup"],
                "keydown": ["keydown", "onkeydown"],
            },
            "dom_manipulations": {
                "innerHTML": ["innerHTML", "textContent", "innerText"],
                "appendChild": ["appendChild", "insertBefore", "insertAdjacentHTML"],
                "setAttribute": ["setAttribute", "classList.add"],
            },
            "dom_selectors": {
                "getElementById": ["getElementById", "querySelector"],
                "querySelector": ["querySelector", "getElementById"],
                "querySelectorAll": [
                    "querySelectorAll",
                    "getElementsByClassName",
                    "getElementsByTagName",
                ],
            },
        }

        # Compare event handlers with equivalence checking
        for event in set(ref_patterns["event_handlers"]):
            found = False

            # Direct match
            if event in user_patterns["event_handlers"]:
                found = True
            else:
                # Check equivalents
                for eq_group in equivalents["event_handlers"].values():
                    if event in eq_group:
                        if any(
                            eq in user_patterns["event_handlers"] for eq in eq_group
                        ):
                            found = True
                            break

            if not found and (self.tolerance_level < 2):  # Strict or normal mode
                self.results["missing_elements"].append(
                    f"Missing event handler: {event}"
                )
                self.results["js_differences"].append(
                    f"Event handler not implemented: {event}"
                )
                self.results["js_match"] = False
                self.results["success"] = False

        # Compare DOM manipulations with equivalence checking
        for manip in set(ref_patterns["dom_manipulations"]):
            found = False

            # Direct match
            if manip in user_patterns["dom_manipulations"]:
                found = True
            else:
                # Check equivalents
                for eq_group in equivalents["dom_manipulations"].values():
                    if manip in eq_group:
                        if any(
                            eq in user_patterns["dom_manipulations"] for eq in eq_group
                        ):
                            found = True
                            break

            if not found and (
                self.tolerance_level == 0
            ):  # Only strict mode checks all manipulations
                self.results["missing_elements"].append(
                    f"Missing DOM manipulation: {manip}"
                )
                self.results["js_differences"].append(
                    f"DOM manipulation not implemented: {manip}"
                )
                self.results["js_match"] = False
                self.results["success"] = False

        # Check for required DOM selectors
        for selector_type in set(ref_patterns["dom_selectors"]):
            # Extract the basic selector method (e.g., getElementById)
            selector_method = next(
                (s for s in equivalents["dom_selectors"].keys() if s in selector_type),
                None,
            )

            if selector_method:
                found = False
                # Check if user code has any of the equivalent selectors
                for eq in equivalents["dom_selectors"].get(selector_method, []):
                    if any(eq in s for s in user_patterns["dom_selectors"]):
                        found = True
                        break

                if not found and (self.tolerance_level < 2):  # Strict or normal mode
                    self.results["missing_elements"].append(
                        f"Missing DOM selector method: {selector_method}"
                    )
                    self.results["js_differences"].append(
                        f"DOM selector not used: {selector_method}"
                    )
                    self.results["js_match"] = False
                    self.results["success"] = False

        # Check for presence of conditionals if reference has them
        if (
            ref_patterns["conditionals"]
            and not user_patterns["conditionals"]
            and (self.tolerance_level < 2)
        ):
            self.results["missing_elements"].append("Missing conditional statements")
            self.results["js_differences"].append(
                "No conditional logic (if/else) implemented"
            )
            self.results["js_match"] = False
            self.results["success"] = False

        # Check for presence of loops if reference has them (strict mode only)
        if (
            ref_patterns["loops"]
            and not user_patterns["loops"]
            and (self.tolerance_level == 0)
        ):
            self.results["missing_elements"].append("Missing loop structures")
            self.results["js_differences"].append("No loop structures implemented")
            self.results["js_match"] = False
            self.results["success"] = False

    def _compare_event_listeners(self, user_js, reference_js, html_context=None):
        """Compare event listeners in the context of HTML

        Args:
            user_js (str): User JavaScript code
            reference_js (str): Reference JavaScript code
            html_context (str): HTML context
        """
        if not html_context:
            return

        # Use BeautifulSoup to extract elements with IDs from HTML
        soup = BeautifulSoup(html_context, "html.parser")
        elements_with_id = soup.select("[id]")
        element_ids = [el.get("id") for el in elements_with_id]

        # Check for event listeners on these elements
        for element_id in element_ids:
            # Check reference JS for event listeners on this element
            ref_pattern = rf'{element_id}\.addEventListener\([\'"](\w+)[\'"]'
            ref_matches = re.findall(ref_pattern, reference_js)

            # If reference has event listeners for this element, check user JS
            if ref_matches:
                user_pattern = rf'{element_id}\.addEventListener\([\'"](\w+)[\'"]'
                user_matches = re.findall(user_pattern, user_js)

                # Check for missing event listeners
                for event_type in ref_matches:
                    if event_type not in user_matches:
                        # Also check for alternate forms like onclick
                        alternate_pattern = rf"{element_id}\.on{event_type}\s*="
                        if not re.search(alternate_pattern, user_js):
                            self.results["missing_elements"].append(
                                f"Missing event listener: {event_type} on #{element_id}"
                            )
                            self.results["js_differences"].append(
                                f"Event listener not implemented: {event_type} on #{element_id}"
                            )
                            self.results["js_match"] = False
                            self.results["success"] = False

    def _check_syntax_and_practices(self, js_code):
        """Check for syntax errors and best practices

        Args:
            js_code (str): JavaScript code
        """
        # Check for unbalanced delimiters
        delimiters = {"(": ")", "{": "}", "[": "]"}

        # Count each delimiter
        counts = {c: 0 for c in list(delimiters.keys()) + list(delimiters.values())}
        for char in js_code:
            if char in counts:
                counts[char] += 1

        # Check if delimiters are balanced
        for opener, closer in delimiters.items():
            if counts[opener] != counts[closer]:
                self.results["js_differences"].append(
                    f"Syntax error: Unbalanced delimiters ({opener}{closer})"
                )
                self.results["js_match"] = False
                self.results["success"] = False

        # Check for potential reference errors
        variable_decl_pattern = r"(const|let|var)\s+(\w+)\s*="
        variable_decls = [m[1] for m in re.findall(variable_decl_pattern, js_code)]

        # Look for usages of variables that weren't declared
        # This is a basic check and may have false positives
        js_keywords = {
            "if",
            "for",
            "while",
            "function",
            "return",
            "new",
            "this",
            "document",
            "window",
            "console",
        }

        # Extract words that look like variable references
        word_pattern = r'(?<![\'"`])(\b[a-zA-Z_]\w*\b)(?![\'"`])'
        words = [w for w in re.findall(word_pattern, js_code) if w not in js_keywords]

        # Filter to words that are likely variables and weren't declared
        undefined_vars = [w for w in words if w not in variable_decls and w.isalnum()]

        # Take unique values and limit to a few to avoid noise
        unique_undefined = list(set(undefined_vars))[:3]

        if unique_undefined and self.tolerance_level == 0:  # Only report in strict mode
            self.results["js_differences"].append(
                f"Potential reference errors: variables referenced but not declared: {', '.join(unique_undefined)}"
            )


# EnhancedJSTest.py
from robot.api.deco import keyword
import re
import json
import os
import time


class EnhancedJSTest:
    """Enhanced JavaScript testing for Robot Framework"""

    ROBOT_LIBRARY_SCOPE = "GLOBAL"

    def __init__(self):
        self.last_result = {"js_match": True, "js_differences": []}
        self.output_file = "defaultcode_comparison_result.json"

    @keyword
    def set_output_file(self, output_file):
        """Set the output file for JavaScript test results

        Args:
            output_file (str): Path to the output file
        """
        self.output_file = output_file

    @keyword
    def compare_js_code(
        self, student_js, teacher_js, html_context=None, tolerance_level=1
    ):
        """Compare JavaScript code with enhanced testing

        Args:
            student_js (str): Student JavaScript code
            teacher_js (str): Teacher JavaScript code
            html_context (str): HTML context for the JavaScript
            tolerance_level (int): 0=strict, 1=normal, 2=lenient

        Returns:
            bool: True if JS matches, False otherwise
        """
        # Set default result
        self.last_result = {"js_match": True, "js_differences": []}

        # Check for exact match first
        if student_js.strip() == teacher_js.strip():
            return True

        # Extract patterns from both code samples
        student_patterns = self._extract_js_patterns(student_js)
        teacher_patterns = self._extract_js_patterns(teacher_js)

        # Compare patterns
        result = self._compare_patterns(
            student_patterns, teacher_patterns, int(tolerance_level)
        )
        self.last_result = result

        return result["js_match"]

    @keyword
    def get_js_differences(self):
        """Get JavaScript differences from the last test

        Returns:
            list: List of differences
        """
        return self.last_result.get("js_differences", [])

    @keyword
    def get_js_test_result(self):
        """Get detailed test result

        Returns:
            dict: Test result
        """
        return self.last_result

    @keyword
    def save_js_test_results(self, html_match=True, css_match=True, output_dir=None):
        """Save JavaScript test results to the standard output file format

        Args:
            html_match (bool): True if HTML matches, False otherwise
            css_match (bool): True if CSS matches, False otherwise
            output_dir (str): Output directory (optional)

        Returns:
            str: Path to the output file
        """
        # Create timestamp
        timestamp = time.time()

        # Create output in the standard format
        output = {
            "timestamp": timestamp,
            "html_match": html_match,
            "css_match": css_match,
            "js_match": self.last_result["js_match"],
            "html_differences": [],
            "css_differences": [],
            "js_differences": (
                None
                if self.last_result["js_match"]
                else self.last_result["js_differences"]
            ),
        }

        # Determine output path
        if output_dir:
            output_path = os.path.join(output_dir, self.output_file)
        else:
            output_path = self.output_file

        # Ensure output directory exists
        os.makedirs(
            os.path.dirname(output_path) if os.path.dirname(output_path) else ".",
            exist_ok=True,
        )

        # Write output to file
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2)

        return output_path

    @keyword
    def update_comparison_result(
        self,
        html_match,
        css_match,
        html_differences=None,
        css_differences=None,
        output_dir=None,
    ):
        """Update the comparison result file with HTML, CSS, and JS results

        Args:
            html_match (bool): True if HTML matches, False otherwise
            css_match (bool): True if CSS matches, False otherwise
            html_differences (list): List of HTML differences
            css_differences (list): List of CSS differences
            output_dir (str): Output directory (optional)

        Returns:
            str: Path to the output file
        """
        # Create timestamp
        timestamp = time.time()

        # Determine output path
        if output_dir:
            output_path = os.path.join(output_dir, self.output_file)
        else:
            output_path = self.output_file

        # Create output object
        output = {
            "timestamp": timestamp,
            "html_match": html_match,
            "css_match": css_match,
            "js_match": self.last_result["js_match"],
            "html_differences": html_differences or [],
            "css_differences": css_differences or [],
            "js_differences": (
                None
                if self.last_result["js_match"]
                else self.last_result["js_differences"]
            ),
        }

        # Ensure output directory exists
        os.makedirs(
            os.path.dirname(output_path) if os.path.dirname(output_path) else ".",
            exist_ok=True,
        )

        # Write output to file
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2)

        return output_path

    def _extract_js_patterns(self, js_code):
        """Extract JavaScript patterns from code

        Args:
            js_code (str): JavaScript code

        Returns:
            dict: Extracted patterns
        """
        patterns = {"event_handlers": [], "dom_selectors": [], "dom_manipulations": []}

        if not js_code:
            return patterns

        # Extract event handlers
        event_patterns = [
            r'addEventListener\([\'"](\w+)[\'"]',
            r"\.on(\w+)\s*=",
            r"on(\w+)\s*=",
        ]

        for pattern in event_patterns:
            matches = re.findall(pattern, js_code)
            for match in matches:
                if isinstance(match, tuple):
                    for m in match:
                        if m and m not in patterns["event_handlers"]:
                            patterns["event_handlers"].append(m)
                elif match and match not in patterns["event_handlers"]:
                    patterns["event_handlers"].append(match)

        # Extract DOM selectors
        selector_patterns = [
            r'getElementById\([\'"](\w+)[\'"]',
            r'querySelector\([\'"]([^\'")]+)[\'"]',
            r'querySelectorAll\([\'"]([^\'")]+)[\'"]',
        ]

        for pattern in selector_patterns:
            matches = re.findall(pattern, js_code)
            for match in matches:
                if match and match not in patterns["dom_selectors"]:
                    patterns["dom_selectors"].append(match)

        # Extract DOM manipulations
        manipulation_patterns = [
            r"\.innerHTML\s*=",
            r"\.textContent\s*=",
            r"\.innerText\s*=",
            r"\.style\.(\w+)\s*=",
        ]

        for pattern in manipulation_patterns:
            matches = re.findall(pattern, js_code)
            if matches:
                # If the pattern has a capture group, add each captured value
                if "(" in pattern:
                    for match in matches:
                        if match and match not in patterns["dom_manipulations"]:
                            patterns["dom_manipulations"].append(match)
                # Otherwise just add the pattern itself
                else:
                    pattern_name = pattern.replace(r"\.", "").replace(r"\s*=", "")
                    if pattern_name not in patterns["dom_manipulations"]:
                        patterns["dom_manipulations"].append(pattern_name)

        return patterns

    def _compare_patterns(self, student_patterns, teacher_patterns, tolerance_level):
        """Compare JavaScript patterns

        Args:
            student_patterns (dict): Student patterns
            teacher_patterns (dict): Teacher patterns
            tolerance_level (int): Tolerance level

        Returns:
            dict: Comparison result
        """
        result = {"js_match": True, "js_differences": []}

        # Define equivalence groups
        equivalents = {
            "event_handlers": {
                "click": ["click", "onclick"],
                "submit": ["submit", "onsubmit"],
                "change": ["change", "onchange"],
            }
        }

        # Compare event handlers
        for event in teacher_patterns["event_handlers"]:
            found = False

            # Direct match
            if event in student_patterns["event_handlers"]:
                found = True
            else:
                # Check equivalents
                for eq_group in equivalents["event_handlers"].values():
                    if event in eq_group:
                        # If any equivalent is found in student code
                        if any(
                            eq in student_patterns["event_handlers"] for eq in eq_group
                        ):
                            found = True
                            break

            if not found:
                result["js_match"] = False
                result["js_differences"].append(f"Missing event handler: {event}")

        # Compare DOM selectors if in strict mode
        if tolerance_level == 0:
            for selector in teacher_patterns["dom_selectors"]:
                if selector not in student_patterns["dom_selectors"]:
                    result["js_match"] = False
                    result["js_differences"].append(f"Missing DOM selector: {selector}")

        # Compare DOM manipulations
        for manip in teacher_patterns["dom_manipulations"]:
            if manip not in student_patterns["dom_manipulations"]:
                if tolerance_level < 2:  # Only fail in strict or normal mode
                    result["js_match"] = False
                    result["js_differences"].append(
                        f"Missing DOM manipulation: {manip}"
                    )

        return result
