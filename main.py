#!/usr/bin/env python3
"""
Dynamic Testing System - Main Entry Point

This script serves as the primary interface for the educational testing platform,
orchestrating code execution testing, web development testing, and behavioral analysis.

ARCHITECTURE NOTE: This system uses only the essential dynamic testing components:
- DynamicTestingFramework.robot: Core execution engine with sandboxing and instrumentation
- IntegratedTestRunner.robot: Main orchestrator for all testing modes
- test_definitions/*.json: JSON-based lesson configurations

The following deprecated files should be removed from NewDevelopment/:
- AssessmentEngine.robot (replaced by DynamicTestingFramework.robot)
- SimplifiedWebAssessment.robot (superseded by IntegratedTestRunner.robot)
- WebTestingFramework.robot (static analysis approach, replaced by dynamic testing)
- WebTestingOrchestrator.robot (browser-dependent, integrated into IntegratedTestRunner.robot)
- web_test_config.json (replaced by test_definitions JSON files)
- teacher_config.json (replaced by individual lesson test definitions)

Usage:
    python main.py --lesson-id recursion_factorial --submission submission.json
    python main.py --lesson-id dom_manipulation --submission web_submission.json --mode web
    python main.py --list-lessons
    python main.py --validate-definition recursion_factorial
"""

import argparse
import json
import os
import sys
import subprocess
import logging
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("testing_system.log"),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger(__name__)


class DynamicTestingSystem:
    """Main orchestrator for the dynamic testing system."""

    def __init__(self, base_path: str = None):
        """Initialize the testing system with base path configuration."""
        self.base_path = Path(base_path) if base_path else Path(__file__).parent
        self.newdev_path = self.base_path / "NewDevelopment"
        self.test_definitions_path = self.newdev_path / "test_definitions"
        self.results_path = self.base_path / "test_results"

        # Ensure required directories exist
        self.results_path.mkdir(exist_ok=True)

        # Core Robot Framework files (only essential components)
        self.dynamic_framework = self.newdev_path / "DynamicTestingFramework.robot"
        self.integrated_runner = self.newdev_path / "IntegratedTestRunner.robot"

        logger.info(f"Initialized Dynamic Testing System at {self.base_path}")
        logger.info(
            "Using streamlined core components: DynamicTestingFramework + IntegratedTestRunner"
        )

    def validate_environment(self) -> bool:
        """Validate that all required components are available."""
        # Only check essential dynamic testing components
        required_files = [
            self.dynamic_framework,
            self.integrated_runner,
            self.test_definitions_path,
        ]

        missing_files = [f for f in required_files if not f.exists()]
        if missing_files:
            logger.error(f"Missing required files: {missing_files}")
            return False

        # Verify no obsolete files exist (cleanup validation)
        obsolete_files = [
            self.newdev_path / "AssessmentEngine.robot",
            self.newdev_path / "SimplifiedWebAssessment.robot",
            self.newdev_path / "WebTestingFramework.robot",
            self.newdev_path / "WebTestingOrchestrator.robot",
            self.newdev_path / "web_test_config.json",
            self.newdev_path / "teacher_config.json",
        ]

        existing_obsolete = [f for f in obsolete_files if f.exists()]
        if existing_obsolete:
            logger.warning(
                f"Obsolete files detected (should be removed): {existing_obsolete}"
            )
            logger.warning("Run cleanup script to remove deprecated components")

        # Check Robot Framework installation
        try:
            result = subprocess.run(
                ["robot", "--version"], capture_output=True, text=True
            )
            if result.returncode != 0:
                logger.error("Robot Framework not installed or not accessible")
                return False
            logger.info(f"Robot Framework version: {result.stdout.strip()}")
        except FileNotFoundError:
            logger.error("Robot Framework not found in PATH")
            return False

        # Check Python environment
        try:
            import robot

            logger.info("Robot Framework Python library available")
        except ImportError:
            logger.error("Robot Framework Python library not available")
            return False

        logger.info(
            "Environment validation passed - using dynamic testing components only"
        )
        return True

    def list_available_lessons(self) -> Dict[str, Any]:
        """List all available lesson test definitions."""
        lessons = {}

        if not self.test_definitions_path.exists():
            logger.warning("Test definitions directory not found")
            return lessons

        for test_file in self.test_definitions_path.glob("*.json"):
            try:
                with open(test_file, "r") as f:
                    test_def = json.load(f)
                    lesson_id = test_def.get("lesson_id", test_file.stem)
                    lessons[lesson_id] = {
                        "file": str(test_file),
                        "title": test_def.get("title", "No title"),
                        "description": test_def.get("description", "No description"),
                        "language": test_def.get("execution_environment", {}).get(
                            "language", "unknown"
                        ),
                        "runtime": test_def.get("execution_environment", {}).get(
                            "runtime", "code"
                        ),
                    }
            except (json.JSONDecodeError, KeyError) as e:
                logger.warning(f"Invalid test definition in {test_file}: {e}")

        return lessons

    def validate_test_definition(self, lesson_id: str) -> bool:
        """Validate a test definition file structure."""
        test_file = self.test_definitions_path / f"{lesson_id}.json"

        if not test_file.exists():
            logger.error(f"Test definition file not found: {test_file}")
            return False

        try:
            with open(test_file, "r") as f:
                test_def = json.load(f)

            # Required fields validation
            required_fields = [
                "lesson_id",
                "test_cases",
                "behavioral_requirements",
                "execution_environment",
            ]
            missing_fields = [
                field for field in required_fields if field not in test_def
            ]

            if missing_fields:
                logger.error(
                    f"Missing required fields in {lesson_id}: {missing_fields}"
                )
                return False

            # Validate test cases structure
            test_cases = test_def["test_cases"]
            if not isinstance(test_cases, list) or len(test_cases) == 0:
                logger.error(f"Invalid test_cases structure in {lesson_id}")
                return False

            # Validate behavioral requirements
            behavioral_req = test_def["behavioral_requirements"]
            if not isinstance(behavioral_req, list):
                logger.error(
                    f"Invalid behavioral_requirements structure in {lesson_id}"
                )
                return False

            # Validate execution environment
            exec_env = test_def["execution_environment"]
            if "language" not in exec_env:
                logger.error(
                    f"Missing language in execution_environment for {lesson_id}"
                )
                return False

            logger.info(f"Test definition {lesson_id} is valid")
            return True

        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in test definition {lesson_id}: {e}")
            return False
        except Exception as e:
            logger.error(f"Error validating test definition {lesson_id}: {e}")
            return False

    def load_submission(self, submission_path: str) -> Dict[str, Any]:
        """Load and validate student submission."""
        submission_file = Path(submission_path)

        if not submission_file.exists():
            raise FileNotFoundError(f"Submission file not found: {submission_path}")

        try:
            with open(submission_file, "r") as f:
                submission = json.load(f)

            logger.info(f"Loaded submission from {submission_path}")
            return submission

        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in submission file: {e}")
        except Exception as e:
            raise Exception(f"Error loading submission: {e}")

    def determine_testing_mode(self, lesson_id: str) -> str:
        """Determine testing mode based on lesson configuration."""
        test_file = self.test_definitions_path / f"{lesson_id}.json"

        try:
            with open(test_file, "r") as f:
                test_def = json.load(f)

            runtime = test_def.get("execution_environment", {}).get("runtime", "code")
            return "web" if runtime == "browser" else "code"

        except Exception as e:
            logger.warning(f"Could not determine testing mode for {lesson_id}: {e}")
            return "code"  # Default to code testing

    def execute_test_suite(
        self, lesson_id: str, submission: Dict[str, Any], mode: str = None
    ) -> Dict[str, Any]:
        """Execute the appropriate test suite for the given lesson and submission."""

        # Determine testing mode if not specified
        if mode is None:
            mode = self.determine_testing_mode(lesson_id)

        logger.info(f"Executing {mode} testing for lesson {lesson_id}")

        # Prepare submission file for Robot Framework
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        submission_file = self.results_path / f"submission_{lesson_id}_{timestamp}.json"

        with open(submission_file, "w") as f:
            json.dump(submission, f, indent=2)

        # Prepare Robot Framework execution (using only IntegratedTestRunner)
        robot_args = [
            "robot",
            "--outputdir",
            str(self.results_path),
            "--output",
            f"output_{lesson_id}_{timestamp}.xml",
            "--log",
            f"log_{lesson_id}_{timestamp}.html",
            "--report",
            f"report_{lesson_id}_{timestamp}.html",
            "--variable",
            f"LESSON_ID:{lesson_id}",
            "--variable",
            f"SUBMISSION_FILE:{submission_file}",
            "--variable",
            f"TESTING_MODE:{mode}",
            "--test",
            "Dynamic Test Execution From Variables",  # Use the main test case
            str(self.integrated_runner),
        ]

        try:
            # Execute Robot Framework test
            logger.info(f"Running command: {' '.join(robot_args)}")
            result = subprocess.run(
                robot_args, capture_output=True, text=True, timeout=300
            )

            # Load results
            results_file = (
                self.results_path
                / f"integrated_results/results_{lesson_id}_{timestamp}.json"
            )

            if results_file.exists():
                with open(results_file, "r") as f:
                    test_results = json.load(f)
            else:
                # Fallback: create basic results from Robot Framework output
                test_results = {
                    "lesson_id": lesson_id,
                    "testing_mode": mode,
                    "robot_exit_code": result.returncode,
                    "robot_stdout": result.stdout,
                    "robot_stderr": result.stderr,
                    "timestamp": timestamp,
                    "overall_score": 0 if result.returncode != 0 else 50,
                    "status": "FAILED" if result.returncode != 0 else "PARTIAL",
                }

            # Add execution metadata
            test_results.update(
                {
                    "execution_time": timestamp,
                    "submission_file": str(submission_file),
                    "robot_exit_code": result.returncode,
                    "robot_logs": {
                        "output": f"output_{lesson_id}_{timestamp}.xml",
                        "log": f"log_{lesson_id}_{timestamp}.html",
                        "report": f"report_{lesson_id}_{timestamp}.html",
                    },
                }
            )

            logger.info(f"Test execution completed with exit code: {result.returncode}")
            return test_results

        except subprocess.TimeoutExpired:
            logger.error("Test execution timed out")
            return {
                "lesson_id": lesson_id,
                "testing_mode": mode,
                "error": "Test execution timed out",
                "overall_score": 0,
                "status": "TIMEOUT",
            }
        except Exception as e:
            logger.error(f"Error executing test suite: {e}")
            return {
                "lesson_id": lesson_id,
                "testing_mode": mode,
                "error": str(e),
                "overall_score": 0,
                "status": "ERROR",
            }

    def generate_summary_report(self, results: Dict[str, Any]) -> str:
        """Generate a human-readable summary report."""
        report = []
        report.append("=" * 50)
        report.append("DYNAMIC TESTING SYSTEM - RESULTS SUMMARY")
        report.append("=" * 50)
        report.append(f"Lesson ID: {results.get('lesson_id', 'Unknown')}")
        report.append(f"Testing Mode: {results.get('testing_mode', 'Unknown')}")
        report.append(f"Execution Time: {results.get('execution_time', 'Unknown')}")
        report.append(f"Overall Score: {results.get('overall_score', 0)}%")
        report.append(f"Status: {results.get('status', 'Unknown')}")
        report.append("")

        # Behavioral analysis summary
        if "behavioral_analysis" in results:
            report.append("BEHAVIORAL ANALYSIS:")
            report.append("-" * 20)
            for requirement, analysis in results["behavioral_analysis"].items():
                satisfied = analysis.get("satisfied", False)
                status = "✅ PASSED" if satisfied else "❌ FAILED"
                report.append(f"{requirement}: {status}")
                if "details" in analysis:
                    details = analysis["details"]
                    if isinstance(details, list):
                        for detail in details[:3]:  # Show first 3 details
                            report.append(f"  - {detail}")
                    else:
                        report.append(f"  - {details}")
            report.append("")

        # Score breakdown
        if any(key.endswith("_score") for key in results.keys()):
            report.append("SCORE BREAKDOWN:")
            report.append("-" * 15)
            for key, value in results.items():
                if key.endswith("_score"):
                    score_name = key.replace("_score", "").replace("_", " ").title()
                    report.append(f"{score_name}: {value}%")
            report.append("")

        # Feedback
        if "feedback" in results:
            feedback = results["feedback"]
            if "performance_message" in feedback:
                report.append("FEEDBACK:")
                report.append("-" * 9)
                report.append(feedback["performance_message"])
                report.append("")

        # Error information
        if "error" in results:
            report.append("ERROR INFORMATION:")
            report.append("-" * 18)
            report.append(results["error"])
            report.append("")

        report.append("=" * 50)
        return "\n".join(report)


def main():
    """Main entry point for the dynamic testing system."""
    parser = argparse.ArgumentParser(
        description="Dynamic Testing System for Educational Code Assessment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py --lesson-id recursion_factorial --submission student_code.json
  python main.py --lesson-id dom_manipulation --submission web_submission.json --mode web
  python main.py --list-lessons
  python main.py --validate-definition recursion_factorial
        """,
    )

    parser.add_argument("--lesson-id", "-l", type=str, help="Lesson ID to test against")
    parser.add_argument(
        "--submission", "-s", type=str, help="Path to student submission JSON file"
    )
    parser.add_argument(
        "--mode",
        "-m",
        choices=["code", "web"],
        help="Testing mode (auto-detected if not specified)",
    )
    parser.add_argument(
        "--list-lessons", action="store_true", help="List all available lessons"
    )
    parser.add_argument(
        "--validate-definition", "-v", type=str, help="Validate a test definition file"
    )
    parser.add_argument(
        "--output", "-o", type=str, help="Output file for results (default: stdout)"
    )
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    parser.add_argument(
        "--base-path", type=str, help="Base path for the testing system"
    )

    args = parser.parse_args()

    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize testing system
    try:
        system = DynamicTestingSystem(args.base_path)

        if not system.validate_environment():
            logger.error("Environment validation failed")
            sys.exit(1)

    except Exception as e:
        logger.error(f"Failed to initialize testing system: {e}")
        sys.exit(1)

    # Handle different operations
    try:
        if args.list_lessons:
            lessons = system.list_available_lessons()
            print("\nAvailable Lessons:")
            print("=" * 50)
            for lesson_id, info in lessons.items():
                print(f"ID: {lesson_id}")
                print(f"Title: {info['title']}")
                print(f"Language: {info['language']}")
                print(f"Runtime: {info['runtime']}")
                print(f"Description: {info['description']}")
                print("-" * 30)

        elif args.validate_definition:
            is_valid = system.validate_test_definition(args.validate_definition)
            status = "VALID" if is_valid else "INVALID"
            print(f"Test definition '{args.validate_definition}': {status}")
            sys.exit(0 if is_valid else 1)

        elif args.lesson_id and args.submission:
            # Validate inputs
            if not system.validate_test_definition(args.lesson_id):
                logger.error(f"Invalid test definition for lesson: {args.lesson_id}")
                sys.exit(1)

            # Load submission
            submission = system.load_submission(args.submission)

            # Execute test suite
            results = system.execute_test_suite(args.lesson_id, submission, args.mode)

            # Generate and output results
            summary = system.generate_summary_report(results)

            if args.output:
                with open(args.output, "w") as f:
                    json.dump(results, f, indent=2)
                print(f"Detailed results saved to: {args.output}")
                print("\nSummary:")
                print(summary)
            else:
                print(summary)
                print(f"\nDetailed results: {json.dumps(results, indent=2)}")

            # Exit with appropriate code
            overall_score = results.get("overall_score", 0)
            sys.exit(0 if overall_score >= 70 else 1)

        else:
            parser.print_help()
            print(
                "\nError: Either specify --lesson-id and --submission, or use --list-lessons or --validate-definition"
            )
            sys.exit(1)

    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
