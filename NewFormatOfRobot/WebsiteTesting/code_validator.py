import os
import re
import json
import difflib
from bs4 import BeautifulSoup
from html.parser import HTMLParser
import tempfile


class HTMLStructureParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tags = []
        self.current_path = []
        self.structure = []

    def handle_starttag(self, tag, attrs):
        # Track tag hierarchy
        self.current_path.append(tag)
        self.tags.append(tag)

        # Convert attributes to dictionary
        attr_dict = {name: value for name, value in attrs}

        # Save structure information
        element_info = {
            "tag": tag,
            "path": "/".join(self.current_path),
            "attributes": attr_dict,
        }
        self.structure.append(element_info)

    def handle_endtag(self, tag):
        # Remove from path when reaching closing tag
        if self.current_path and self.current_path[-1] == tag:
            self.current_path.pop()


class DOMComparator:
    def __init__(self, tolerance_level=1):
        # tolerance_level: 0-strict, 1-normal, 2-lenient
        self.tolerance_level = tolerance_level
        self.results = {
            "missing_elements": [],
            "attribute_mismatches": [],
            "structure_diffs": [],
            "pass": True,
        }

        # Define optional attributes based on tolerance level
        self.optional_attributes = set()
        if tolerance_level >= 1:
            # Normal tolerance - ignore these attributes when comparing
            self.optional_attributes.update(["class", "style", "id"])
        if tolerance_level >= 2:
            # Lenient tolerance - ignore more attributes
            self.optional_attributes.update(["title", "alt", "placeholder"])

    def compare_html_structure(self, user_html, reference_html):
        # Parse HTML with BeautifulSoup for accurate comparison
        user_soup = BeautifulSoup(user_html, "html.parser")
        ref_soup = BeautifulSoup(reference_html, "html.parser")

        # Get all tags from both DOMs
        user_tags = [tag.name for tag in user_soup.find_all()]
        ref_tags = [tag.name for tag in ref_soup.find_all()]

        # Check for required tag counts with tolerance
        tag_counts = {}
        for tag in ref_tags:
            if tag not in tag_counts:
                tag_counts[tag] = 0
            tag_counts[tag] += 1

        user_tag_counts = {}
        for tag in user_tags:
            if tag not in user_tag_counts:
                user_tag_counts[tag] = 0
            user_tag_counts[tag] += 1

        # Compare tag counts with tolerance
        for tag, count in tag_counts.items():
            user_count = user_tag_counts.get(tag, 0)
            if self.tolerance_level == 0:
                # Strict: must have exact count
                if user_count != count:
                    self.results["missing_elements"].append(
                        f"Expected {count} {tag} tags, found {user_count}"
                    )
                    self.results["pass"] = False
            elif self.tolerance_level == 1:
                # Normal: must have at least 80% of required tags
                required = max(1, int(count * 0.8))
                if user_count < required:
                    self.results["missing_elements"].append(
                        f"Expected at least {required} {tag} tags, found {user_count}"
                    )
                    self.results["pass"] = False
            else:
                # Lenient: must have at least one if reference has any
                if count > 0 and user_count == 0:
                    self.results["missing_elements"].append(
                        f"Expected at least one {tag} tag, found none"
                    )
                    self.results["pass"] = False

        # Use custom parser for structural comparison
        user_parser = HTMLStructureParser()
        ref_parser = HTMLStructureParser()

        try:
            user_parser.feed(user_html)
            ref_parser.feed(reference_html)
        except Exception as e:
            # Handle parsing errors
            self.results["pass"] = False
            self.results["structure_diffs"].append(f"HTML parsing error: {str(e)}")
            return self.results

        # Compare element structures with tolerance
        if self.tolerance_level == 0:
            # Strict comparison - full path matching
            self._compare_strict(user_parser, ref_parser)
        elif self.tolerance_level == 1:
            # Normal comparison - focus on semantic structure
            self._compare_normal(user_parser, ref_parser)
        else:
            # Lenient comparison - just check for presence of elements
            self._compare_lenient(user_parser, ref_parser)

        return self.results

    def _compare_strict(self, user_parser, ref_parser):
        # Find missing elements
        user_paths = [el["path"] for el in user_parser.structure]
        ref_paths = [el["path"] for el in ref_parser.structure]

        missing_paths = set(ref_paths) - set(user_paths)
        for path in missing_paths:
            ref_el = next(
                (el for el in ref_parser.structure if el["path"] == path), None
            )
            if ref_el:
                self.results["missing_elements"].append(f"{ref_el['tag']} at {path}")
                self.results["pass"] = False

        # Compare attributes for matching paths
        self._compare_attributes(user_parser, ref_parser)

    def _compare_normal(self, user_parser, ref_parser):
        # Check for important elements (h1-h6, main, section, form, etc.)
        important_tags = {
            "html",
            "head",
            "title",
            "base",
            "link",
            "meta",
            "style",
            "script",
            "noscript",
            "body",
            "section",
            "nav",
            "article",
            "aside",
            "header",
            "footer",
            "address",
            "main",
            "div",
            "p",
            "hr",
            "pre",
            "blockquote",
            "ol",
            "ul",
            "li",
            "dl",
            "dt",
            "dd",
            "figure",
            "figcaption",
            "table",
            "caption",
            "thead",
            "tbody",
            "tfoot",
            "tr",
            "th",
            "td",
            "colgroup",
            "col",
            "form",
            "label",
            "input",
            "button",
            "select",
            "datalist",
            "optgroup",
            "option",
            "textarea",
            "output",
            "progress",
            "meter",
            "fieldset",
            "legend",
            "iframe",
            "img",
            "embed",
            "object",
            "param",
            "video",
            "audio",
            "source",
            "track",
            "canvas",
            "map",
            "area",
            "svg",
            "math",
            "abbr",
            "b",
            "bdi",
            "bdo",
            "cite",
            "code",
            "data",
            "dfn",
            "em",
            "i",
            "kbd",
            "mark",
            "q",
            "rp",
            "rt",
            "ruby",
            "s",
            "samp",
            "small",
            "strong",
            "sub",
            "sup",
            "time",
            "u",
            "var",
            "wbr",
            "a",
            "span",
            "br",
            "wbr",
            "template",
            "slot",
            "portal",
            "details",
            "summary",
            "dialog",
            "menu",
            "menuitem",
        }

        # Get user and ref tags by type
        user_tags_by_type = {}
        ref_tags_by_type = {}

        for el in user_parser.structure:
            tag = el["tag"]
            if tag not in user_tags_by_type:
                user_tags_by_type[tag] = []
            user_tags_by_type[tag].append(el)

        for el in ref_parser.structure:
            tag = el["tag"]
            if tag not in ref_tags_by_type:
                ref_tags_by_type[tag] = []
            ref_tags_by_type[tag].append(el)

        # Check for missing important tags
        for tag in important_tags:
            if tag in ref_tags_by_type and (
                tag not in user_tags_by_type
                or len(user_tags_by_type[tag]) < len(ref_tags_by_type[tag])
            ):
                self.results["missing_elements"].append(
                    f"Missing or insufficient {tag} elements"
                )
                self.results["pass"] = False

        # Compare some key attributes on important elements
        for tag in important_tags:
            if tag in ref_tags_by_type and tag in user_tags_by_type:
                for i, ref_el in enumerate(ref_tags_by_type[tag]):
                    if i < len(user_tags_by_type[tag]):
                        user_el = user_tags_by_type[tag][i]
                        # Compare href on links, src on images, type/name on inputs
                        for attr in (
                            set(ref_el["attributes"].keys()) - self.optional_attributes
                        ):
                            ref_val = ref_el["attributes"][attr]
                            user_val = user_el["attributes"].get(attr, "missing")
                            if (
                                attr
                                in ["href", "src", "type", "name", "action", "method"]
                                and user_val != ref_val
                            ):
                                self.results["attribute_mismatches"].append(
                                    {
                                        "element": f"{tag}",
                                        "attribute": attr,
                                        "expected": ref_val,
                                        "actual": user_val,
                                    }
                                )
                                self.results["pass"] = False

    def _compare_lenient(self, user_parser, ref_parser):
        # Just check for presence of tags, not structure or hierarchy
        user_tags = set(el["tag"] for el in user_parser.structure)
        ref_tags = set(el["tag"] for el in ref_parser.structure)

        missing_tags = ref_tags - user_tags
        for tag in missing_tags:
            self.results["missing_elements"].append(f"Missing {tag} element")
            self.results["pass"] = False

    def _compare_attributes(self, user_parser, ref_parser):
        # Compare attributes for matching paths
        for ref_el in ref_parser.structure:
            path = ref_el["path"]
            user_el = next(
                (el for el in user_parser.structure if el["path"] == path), None
            )

            if user_el:
                # Check required attributes
                for attr_name, attr_value in ref_el["attributes"].items():
                    # Skip optional attributes based on tolerance level
                    if attr_name in self.optional_attributes:
                        continue

                    if (
                        attr_name not in user_el["attributes"]
                        or user_el["attributes"][attr_name] != attr_value
                    ):
                        self.results["attribute_mismatches"].append(
                            {
                                "element": f"{ref_el['tag']} at {path}",
                                "attribute": attr_name,
                                "expected": attr_value,
                                "actual": user_el["attributes"].get(
                                    attr_name, "missing"
                                ),
                            }
                        )
                        self.results["pass"] = False

    def compare_js_output(self, user_html, user_js, reference_html, reference_js):
        # Create combined files
        user_combined = f"""
        <!DOCTYPE html>
        <html>
        <head>
          <title>User Code</title>
          <script>{user_js}</script>
        </head>
        <body>
          {user_html}
        </body>
        </html>
        """

        ref_combined = f"""
        <!DOCTYPE html>
        <html>
        <head>
          <title>Reference Code</title>
          <script>{reference_js}</script>
        </head>
        <body>
          {reference_html}
        </body>
        </html>
        """

        # Improved JS comparison with tolerance
        self.results["note"] = "Static JS analysis with improved pattern recognition"

        # Extract and compare JS patterns with tolerance
        user_patterns = self.extract_js_patterns(user_js)
        ref_patterns = self.extract_js_patterns(reference_js)

        # Track functionally equivalent alternatives
        equivalent_functions = {
            "addEventListener": ["onclick", "onchange", "onsubmit"],
            "getElementById": ["querySelector", "getElementsById"],
            "querySelector": ["getElementById", "querySelectorAll"],
            "textContent": ["innerText", "innerHTML"],
            "createElement": ["insertAdjacentHTML"],
        }

        # Compare event handlers with equivalence checking
        missing_handlers = []
        for handler in ref_patterns["event_handlers"]:
            if handler not in user_patterns["event_handlers"]:
                # Check for equivalent alternatives
                equivalent_found = False
                for eq_handler in equivalent_functions.get(handler, []):
                    if eq_handler in user_patterns["event_handlers"]:
                        equivalent_found = True
                        break
                if not equivalent_found:
                    missing_handlers.append(handler)

        if missing_handlers:
            self.results["missing_elements"].append(
                f"Missing event handlers: {', '.join(missing_handlers)}"
            )
            if self.tolerance_level < 2:  # Only fail in strict or normal mode
                self.results["pass"] = False

        # Compare DOM manipulations with equivalence checking
        missing_manipulations = []
        for manip in ref_patterns["dom_manipulations"]:
            if manip not in user_patterns["dom_manipulations"]:
                # Check for equivalent alternatives
                equivalent_found = False
                for eq_manip in equivalent_functions.get(manip, []):
                    if eq_manip in user_patterns["dom_manipulations"]:
                        equivalent_found = True
                        break
                if not equivalent_found:
                    missing_manipulations.append(manip)

        if missing_manipulations:
            self.results["missing_elements"].append(
                f"Missing DOM manipulations: {', '.join(missing_manipulations)}"
            )
            if self.tolerance_level < 2:  # Only fail in strict or normal mode
                self.results["pass"] = False

        return self.results

    def extract_js_patterns(self, js_code):
        """Extract common JavaScript patterns from code with improved recognition"""
        patterns = {
            "event_handlers": [],
            "dom_manipulations": [],
            "conditionals": [],
            "loops": [],
        }

        if not js_code:
            return patterns

        # Look for event listeners with improved regex
        event_regex = r'(?:addEventListener\([\'"](\w+)[\'"]|on(\w+)\s*=)'
        event_matches = re.findall(event_regex, js_code)
        for match in event_matches:
            for event in match:
                if event:
                    patterns["event_handlers"].append(event)

        # Look for DOM manipulations with improved regex
        dom_regex = r"(getElementById|querySelector|querySelectorAll|getElementsBy\w+|createElement|appendChild|insertBefore|textContent|innerHTML)"
        patterns["dom_manipulations"] = re.findall(dom_regex, js_code)

        # Look for conditionals
        conditional_regex = r"(if\s*\(|else\s*{|switch\s*\()"
        patterns["conditionals"] = re.findall(conditional_regex, js_code)

        # Look for loops
        loop_regex = r"(for\s*\(|while\s*\(|do\s*{)"
        patterns["loops"] = re.findall(loop_regex, js_code)

        return patterns

    def compare_css(self, user_css, reference_css):
        """Compare CSS rules with configurable tolerance"""
        # Parse CSS to extract rules
        user_rules = self.extract_css_rules(user_css)
        ref_rules = self.extract_css_rules(reference_css)

        if self.tolerance_level == 0:
            # Strict comparison - all selectors and properties must match
            self._compare_css_strict(user_rules, ref_rules)
        elif self.tolerance_level == 1:
            # Normal comparison - focus on important selectors and properties
            self._compare_css_normal(user_rules, ref_rules)
        else:
            # Lenient comparison - just check for basic styling presence
            self._compare_css_lenient(user_rules, ref_rules)

        return self.results

    def _compare_css_strict(self, user_rules, ref_rules):
        # Compare selectors
        missing_selectors = set(ref_rules.keys()) - set(user_rules.keys())
        if missing_selectors:
            self.results["missing_elements"].extend(
                [f"Missing CSS selector: {sel}" for sel in missing_selectors]
            )
            self.results["pass"] = False

        # Compare properties for matching selectors
        for selector in set(ref_rules.keys()) & set(user_rules.keys()):
            ref_props = ref_rules[selector]
            user_props = user_rules[selector]

            # Check for missing properties
            for prop, value in ref_props.items():
                if prop not in user_props:
                    self.results["attribute_mismatches"].append(
                        {
                            "element": f"CSS rule for '{selector}'",
                            "attribute": prop,
                            "expected": value,
                            "actual": "missing",
                        }
                    )
                    self.results["pass"] = False
                elif user_props[prop] != value:
                    self.results["attribute_mismatches"].append(
                        {
                            "element": f"CSS rule for '{selector}'",
                            "attribute": prop,
                            "expected": value,
                            "actual": user_props[prop],
                        }
                    )
                    self.results["pass"] = False

    def _compare_css_normal(self, user_rules, ref_rules):
        # Focus on important selectors (body, header, main, footer, etc.)
        important_selectors = [
            "body",
            "header",
            "main",
            "footer",
            "nav",
            "form",
            "button",
        ]
        important_properties = [
            "display",
            "position",
            "color",
            "background",
            "margin",
            "padding",
            "width",
            "height",
        ]

        # Check for important selectors
        for selector in ref_rules.keys():
            # Check if this selector or any containing an important selector is missing
            selector_found = False

            # Direct match
            if selector in user_rules:
                selector_found = True
            else:
                # Check for selectors that might be functionally equivalent
                for user_selector in user_rules.keys():
                    # If both target the same tag or class, consider them similar
                    if (
                        selector.split(" ")[-1].split(":")[0]
                        == user_selector.split(" ")[-1].split(":")[0]
                    ):
                        selector_found = True
                        break

            # Flag missing important selectors in normal mode
            if not selector_found:
                for important in important_selectors:
                    if important in selector or selector == important:
                        self.results["missing_elements"].append(
                            f"Missing important CSS selector: {selector}"
                        )
                        self.results["pass"] = False
                        break

        # For matching selectors, check important properties
        for selector in set(ref_rules.keys()) & set(user_rules.keys()):
            ref_props = ref_rules[selector]
            user_props = user_rules[selector]

            # Check important properties
            for prop in set(ref_props.keys()) & set(important_properties):
                if prop not in user_props:
                    self.results["attribute_mismatches"].append(
                        {
                            "element": f"CSS rule for '{selector}'",
                            "attribute": prop,
                            "expected": ref_props[prop],
                            "actual": "missing",
                        }
                    )
                    self.results["pass"] = False

    def _compare_css_lenient(self, user_rules, ref_rules):
        # Just check for presence of basic styling
        # Check if user has any styling at all for main elements
        essential_selectors = ["body", "header", "footer", "main"]
        essential_properties = ["color", "background", "display"]

        # Check if any essential selectors are styled
        for selector in essential_selectors:
            ref_used = any(selector in s for s in ref_rules.keys())
            user_used = any(selector in s for s in user_rules.keys())

            if ref_used and not user_used:
                self.results["missing_elements"].append(
                    f"No styling found for essential element: {selector}"
                )
                self.results["pass"] = False

        # Check if any essential properties are used
        ref_props_used = set()
        user_props_used = set()

        for rules in ref_rules.values():
            for prop in rules:
                ref_props_used.add(prop)

        for rules in user_rules.values():
            for prop in rules:
                user_props_used.add(prop)

        missing_essential_props = (
            set(essential_properties) & ref_props_used - user_props_used
        )
        if missing_essential_props:
            self.results["missing_elements"].append(
                f"Missing essential CSS properties: {', '.join(missing_essential_props)}"
            )
            self.results["pass"] = False

    def extract_css_rules(self, css_text):
        rules = {}

        if not css_text:
            return rules

        # Remove comments
        css_text = re.sub(r"/\*.*?\*/", "", css_text, flags=re.DOTALL)

        # Split CSS into rule blocks with better regex that handles nested structures
        rule_blocks = re.findall(r"([^{]+)(\s*{[^}]*})", css_text)

        for selector_group, block in rule_blocks:
            # Extract properties between curly braces
            properties_match = re.search(r"{([^}]*)}", block)
            if not properties_match:
                continue

            properties_text = properties_match.group(1)

            # Handle multiple selectors (comma-separated)
            selectors = [s.strip() for s in selector_group.split(",")]

            for selector in selectors:
                selector = selector.strip()
                if not selector:
                    continue

                if selector not in rules:
                    rules[selector] = {}

                # Extract properties
                for prop in properties_text.split(";"):
                    prop = prop.strip()
                    if not prop:
                        continue

                    if ":" in prop:
                        name, value = prop.split(":", 1)
                        rules[selector][name.strip()] = value.strip()

        return rules

    def get_feedback(self):
        if self.results["pass"]:
            return "Great job! Your implementation matches the expected result."

        feedback = []

        if self.results["missing_elements"]:
            feedback.append("Missing elements:")
            for element in self.results["missing_elements"][
                :3
            ]:  # Limit to avoid overwhelming
                feedback.append(f"- {element}")

        if self.results["attribute_mismatches"]:
            feedback.append("\nAttribute mismatches:")
            for mismatch in self.results["attribute_mismatches"][
                :3
            ]:  # Limit to avoid overwhelming
                feedback.append(
                    f"- {mismatch['element']}: {mismatch['attribute']} should be '{mismatch['expected']}' but found '{mismatch['actual']}'"
                )

        return "\n".join(feedback)


class WebCourseValidator:

    def __init__(self):
        self.comparator = DOMComparator()

    def validate_submission(
        self,
        user_html="",
        user_css="",
        user_js="",
        reference_html="",
        reference_css="",
        reference_js="",
    ):

        # Reset results
        self.comparator.results = {
            "missing_elements": [],
            "attribute_mismatches": [],
            "structure_diffs": [],
            "pass": True,
        }

        # Compare HTML structure
        if user_html and reference_html:
            self.comparator.compare_html_structure(user_html, reference_html)

        # Compare CSS rules
        if user_css and reference_css:
            self.comparator.compare_css(user_css, reference_css)

        # Compare JavaScript behavior
        if user_js and reference_js:
            self.comparator.compare_js_output(
                user_html, user_js, reference_html, reference_js
            )

        # Generate report
        report = {
            "success": self.comparator.results["pass"],
            "feedback": self.comparator.get_feedback(),
            "details": self.comparator.results,
        }

        return report

    def validate_from_files(
        self,
        user_html_file="",
        user_css_file="",
        user_js_file="",
        reference_html_file="",
        reference_css_file="",
        reference_js_file="",
    ):

        # Read files when provided
        user_html = self._read_file(user_html_file)
        user_css = self._read_file(user_css_file)
        user_js = self._read_file(user_js_file)
        reference_html = self._read_file(reference_html_file)
        reference_css = self._read_file(reference_css_file)
        reference_js = self._read_file(reference_js_file)

        # Validate using content
        return self.validate_submission(
            user_html, user_css, user_js, reference_html, reference_css, reference_js
        )

    def _read_file(self, file_path):
        if not file_path or not os.path.exists(file_path):
            return ""

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            print(f"Error reading file {file_path}: {e}")
            return ""

    def save_report_to_file(self, report, output_file):
        try:
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(report, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving report: {e}")
            return False


class WebCourseDataHandler:
    @staticmethod
    def load_json_file(file_path):
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading JSON file {file_path}: {e}")
            return None

    @staticmethod
    def get_teacher_submission(teachers_data, teacher_id=1, assignment_id=1):
        for teacher in teachers_data.get("teachers", []):
            if teacher.get("id") == teacher_id:
                for submission in teacher.get("submissions", []):
                    if submission.get("assignment_id") == assignment_id:
                        return submission
        return None

    @staticmethod
    def get_default_code(teachers_data, teacher_id=1, assignment_id=1):
        submission = WebCourseDataHandler.get_teacher_submission(
            teachers_data, teacher_id, assignment_id
        )
        if submission:
            return submission.get("defaultcode", "")
        return ""

    @staticmethod
    def get_student_submission(students_data, student_id=1, assignment_id=1):
        for student in students_data.get("students", []):
            if student.get("id") == student_id:
                for submission in student.get("submissions", []):
                    if submission.get("assignment_id") == assignment_id:
                        return submission
        return None
