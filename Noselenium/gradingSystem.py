import sys
import json
import subprocess
import requests

api_url = "https://localhost:8000/"

def run_robot_tests():
    result = subprocess.run(
        ["robot", "NOSELENIUM.ROBOT"], capture_output=True, text=True
    )
    if result.returncode != 0:
        print("Robot Framework tests failed")
        print(result.stdout)
        print(result.stderr)
        sys.exit(1)
    else:
        print("Robot Framework tests passed")
        print(result.stdout)


def load_data():
    with open("comparison_results.json") as f:
        data = json.load(f)
    return data


def calculate_scores(data):
    scores = {}
    for result in data:
        student_name = result["student_name"]
        status = result["status"]
        if student_name not in scores:
            scores[student_name] = {"total": 0, "passed": 0}
        scores[student_name]["total"] += 1
        if status == "PASS":
            scores[student_name]["passed"] += 1
    return scores


def print_scores(scores):
    for student, score in scores.items():
        total = score["total"]
        passed = score["passed"]
        percentage = (passed / total) * 100
        print(f"Student: {student}, Passed: {passed}/{total}, Score: {percentage:.2f}%")


if __name__ == "__main__":
    run_robot_tests()
    data = load_data()
    scores = calculate_scores(data)
    print_scores(scores)
