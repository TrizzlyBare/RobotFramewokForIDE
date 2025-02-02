# fastapi_robot.py
from fastapi import FastAPI
import subprocess
import json
import sys

app = FastAPI()

API = "http://intelligentbuilding.io:8080/api/"


@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/teacher_questions/{question_id}")

