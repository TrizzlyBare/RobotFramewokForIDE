import requests
from requests.auth import HTTPBasicAuth
import json
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# URL to make the request to
url = "http://intelligentbuilding.io:8080/api/coding/question/4/"

# Replace these with your actual username and password
username = "admin"
password = "ictadmin"


# Add retry strategy with maximum attempts
def create_session_with_retries(max_retries=3, backoff_factor=1):
    session = requests.Session()
    retry_strategy = Retry(
        total=max_retries,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["HEAD", "GET", "OPTIONS"],
        backoff_factor=backoff_factor,
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


# Add timeout wrapper for requests
def safe_request(url, method="GET", timeout=30, max_attempts=3, **kwargs):
    session = create_session_with_retries(max_retries=max_attempts)

    for attempt in range(max_attempts):
        try:
            if method.upper() == "GET":
                response = session.get(url, timeout=timeout, **kwargs)
            elif method.upper() == "POST":
                response = session.post(url, timeout=timeout, **kwargs)
            else:
                response = session.request(method, url, timeout=timeout, **kwargs)

            response.raise_for_status()
            return response

        except requests.exceptions.RequestException as e:
            print(f"Attempt {attempt + 1} failed: {e}")
            if attempt == max_attempts - 1:
                raise
            time.sleep(2**attempt)  # Exponential backoff

    return None


try:
    # Sending a GET request with Basic Authentication
    response = safe_request(url, auth=HTTPBasicAuth(username, password))

    # Check if the request was successful (status code 200)
    if response and response.status_code == 200:
        # Print the response data (JSON format)
        data = response.json()  # Assuming the response is in JSON format
        print("Received data:", data)

        with open("response_data.json", "w") as json_file:
            json.dump(data, json_file, indent=4)
        print("Data saved to response_data.json")
    else:
        print(
            f"Error: Received status code {response.status_code}"
            if response
            else "Error: No response received"
        )
except requests.exceptions.RequestException as e:
    print(f"An error occurred: {e}")
