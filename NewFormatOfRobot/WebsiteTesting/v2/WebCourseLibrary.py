# WebCourseLibrary.py
from robot.api.deco import keyword
from WebCodeComparator import WebCodeComparator
import os
import json
import tempfile


class WebCourseLibrary:
    """
    Enhanced library for web course testing with specific feedback
    """

    ROBOT_LIBRARY_SCOPE = "GLOBAL"

    def __init__(self):
        self.validator = WebCodeComparator()
        self.last_result = None

    @keyword
    def validate_html_content(self, student_html, teacher_html):
        """
        Validate HTML content and return specific differences
        """
        differences = self.validator.compare_html(student_html, teacher_html)
        self.last_result = {"pass": len(differences) == 0, "differences": differences}
        return self.last_result["pass"]

    @keyword
    def validate_css_content(self, student_css, teacher_css):
        """
        Validate CSS content and return specific differences
        """
        differences = self.validator.compare_css(student_css, teacher_css)
        self.last_result = {"pass": len(differences) == 0, "differences": differences}
        return self.last_result["pass"]

    @keyword
    def validate_js_content(self, student_js, teacher_js):
        """
        Validate JavaScript content and return specific differences
        """
        differences = self.validator.compare_js(student_js, teacher_js)
        self.last_result = {"pass": len(differences) == 0, "differences": differences}
        return self.last_result["pass"]

    @keyword
    def get_validation_differences(self):
        """
        Get specific differences from the last validation
        """
        if not self.last_result:
            return ["No validation has been performed yet"]
        return self.last_result["differences"]

    @keyword
    def save_validation_report(self, file_path):
        """
        Save validation results to a JSON file
        """
        if not self.last_result:
            return False

        try:
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(self.last_result, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving report: {str(e)}")
            return False

    @keyword
    def validate_complete_submission(
        self,
        student_html,
        student_css,
        student_js,
        teacher_html,
        teacher_css,
        teacher_js,
    ):
        """
        Validate complete submission and provide specific feedback for each part
        """
        # Compare HTML
        html_differences = self.validator.compare_html(student_html, teacher_html)
        html_match = len(html_differences) == 0

        # Compare CSS
        css_differences = self.validator.compare_css(student_css, teacher_css)
        css_match = len(css_differences) == 0

        # Compare JS
        js_differences = self.validator.compare_js(student_js, teacher_js)
        js_match = len(js_differences) == 0

        # Create detailed result
        result = {
            "html_match": html_match,
            "css_match": css_match,
            "js_match": js_match,
            "html_differences": html_differences,
            "css_differences": css_differences,
            "js_differences": js_differences,
            "pass": html_match and css_match and js_match,
        }

        self.last_result = result
        return result["pass"]

    @keyword
    def compare_html_structure(self, student_html, teacher_html):
        """
        Compare HTML structure and return specific differences
        """
        differences = self.validator.compare_html(student_html, teacher_html)
        return differences

    @keyword
    def compare_css_rules(self, student_css, teacher_css):
        """
        Compare CSS rules and return specific differences
        """
        differences = self.validator.compare_css(student_css, teacher_css)
        return differences

    @keyword
    def compare_js_functionality(self, student_js, teacher_js):
        """
        Compare JavaScript functionality and return specific differences
        """
        differences = self.validator.compare_js(student_js, teacher_js)
        return differences

    @keyword
    def create_temp_file_with_content(self, content):
        """
        Create a temporary file with the given content
        """
        fd, path = tempfile.mkstemp()
        try:
            with os.fdopen(fd, "w") as f:
                f.write(content)
            return path
        except Exception as e:
            os.close(fd)
            os.unlink(path)
            raise e

    @keyword
    def log_validation_differences(self, differences, log_level="INFO"):
        """
        Log detailed validation differences
        """
        if not differences:
            print("No differences found.")
            return

        for diff in differences:
            print(f"- {diff}")
