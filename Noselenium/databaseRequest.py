import requests
import json

# API endpoints for fetching data
LANGUAGE_API_URL = "https://example.com/api/languages"

STUDENTS_API_URL = "https://example.com/api/students/"
STUDENTS_RESULTS_API_URL = "https://example.com/api/students/results"

TEACHERS_API_URL = "https://example.com/api/teachers"
TEACHERS_CODES_API_URL = "https://example.com/api/teachers/codes"

SCORING_API_URL = "https://example.com/api/scores"


# Fetch data from the API
def fetch_data(api_url):
    try:
        response = requests.get(api_url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching data from {api_url}: {e}")
        return []


# Write data to JSON files
def write_to_json_file(filename, data):
    with open(filename, "w") as file:
        json.dump(data, file, indent=4)


# Post scores to the API
def post_scores(scores):
    for student, score in scores.items():
        total = score["total"]
        passed = score["passed"]
        percentage = (passed / total) * 100
        data = {
            "student_name": student,
            "total_tests": total,
            "passed_tests": passed,
            "score_percentage": percentage,
        }
        try:
            response = requests.post(SCORING_API_URL, json=data)
            response.raise_for_status()
            print(f"Successfully posted score for {student}")
        except requests.exceptions.RequestException as e:
            print(f"Error posting score for {student}: {e}")


# Main function
def main():
    students = fetch_data(STUDENTS_API_URL)
    teachers = fetch_data(TEACHERS_API_URL)

    structured_students = [
        {
            "name": student["name"],
            "enrolled_topics": [
                {
                    "name": topic["name"],
                    "submitted_code": {
                        problem["name"]: {
                            "language": problem["language"],
                            "code": problem["code"],
                            "result": problem["result"],
                        }
                        for problem in topic["problems"]
                    },
                }
                for topic in student["topics"]
            ],
        }
        for student in students
    ]

    structured_teachers = [
        {
            "id": teacher["id"],
            "name": teacher["name"],
            "topics": [
                {
                    "id": topic["id"],
                    "name": topic["name"],
                    "example_code": {
                        problem["name"]: {
                            "language": problem["language"],
                            "code": problem["code"],
                        }
                        for problem in topic["problems"]
                    },
                }
                for topic in teacher["topics"]
            ],
        }
        for teacher in teachers
    ]

    write_to_json_file("students.json", structured_students)
    write_to_json_file("teacher.json", structured_teachers)

    print("Data has been successfully written to students.json and teachers.json")


if __name__ == "__main__":
    main()
