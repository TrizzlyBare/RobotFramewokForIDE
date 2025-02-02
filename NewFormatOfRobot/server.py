from fastapi import FastAPI
import requests
from requests.auth import HTTPBasicAuth
import subprocess
import json
import os

app = FastAPI()

API = "http://intelligentbuilding.io:8080/api/"

username = "admin"
password = "ictadmin"


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/teacher_questions/{question_id}")
def get_teacher_question(question_id: int):
    url = f"{API}coding/question/{question_id}/"
    response = requests.get(url, auth=HTTPBasicAuth(username, password))
    data = response.json()

    with open("teacher.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    return data


@app.get("/students_response/{question_id}")
def get_student_response(question_id: int):
    url = f"{API}coding/resultlog/{question_id}/"
    response = requests.get(url, auth=HTTPBasicAuth(username, password))
    data = response.json()

    with open("students.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    return data


@app.get("/solutions/{question_id}")
def run_test(question_id: int):
    get_teacher_question(question_id)

    with open("teacher.json", "r", encoding="utf-8") as f:
        teacher_data = json.load(f)

    solution_type = teacher_data.get("solutionType")

    if solution_type == "default_code":
        result = subprocess.run(
            ["robot", "Case1.robot"], capture_output=True, text=True
        )
    elif solution_type == "testcase":
        result = subprocess.run(
            ["robot", "Case2.robot"], capture_output=True, text=True
        )
    elif solution_type == "test_result":
        result = subprocess.run(
            ["robot", "Case3.robot"], capture_output=True, text=True
        )
    else:
        return {"status": "error", "message": f"Unknown solutionType: {solution_type}"}

    return {
        "status": "ok",
        "solutionType": solution_type,
        "robot_stdout": result.stdout,
        "robot_stderr": result.stderr,
    }


@app.post("/post_student_status/{question_id}")
def post_student_status(question_id: int):
    get_student_response(question_id)

    with open("comparison_results.json", "r", encoding="utf-8") as f:
        comparison_results = json.load(f)

    post_data = {"test_results": comparison_results["status"]}

    url = f"{API}coding/resultlog/{question_id}/"
    response = requests.post(
        url, json=post_data, auth=HTTPBasicAuth(username, password)
    )

    os.remove("comparison_results.json")

    return response.json()
