import requests
from requests.auth import HTTPBasicAuth
import json

# URL to make the request to
url = "http://intelligentbuilding.io:8080/api/coding/resultlog/4/"

# Replace these with your actual username and password
username = "admin"
password = "ictadmin"

try:
    # Sending a GET request with Basic Authentication
    response = requests.get(url, auth=HTTPBasicAuth(username, password))

    # Check if the request was successful (status code 200)
    if response.status_code == 200:
        # Print the response data (JSON format)
        data = response.json()  # Assuming the response is in JSON format
        print("Received data:", data)

        with open("response_data.json", "w") as json_file:
            json.dump(data, json_file, indent=4)
        print("Data saved to response_data.json")
    else:
        print(f"Error: Received status code {response.status_code}")
except requests.exceptions.RequestException as e:
    print(f"An error occurred: {e}")
