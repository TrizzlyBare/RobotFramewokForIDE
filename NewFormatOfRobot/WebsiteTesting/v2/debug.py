import json
import os
import sys


def test_json_file(file_path):
    """Test reading the JSON file directly"""
    print(f"Testing file: {file_path}")

    if not os.path.exists(file_path):
        print(f"ERROR: File does not exist: {file_path}")
        return False

    print(f"File exists, size: {os.path.getsize(file_path)} bytes")

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        print(f"Successfully read file contents, length: {len(content)} characters")
        print(f"First 100 characters: {content[:100]}")

        try:
            data = json.loads(content)
            print("Successfully parsed JSON")

            if "defaultcode" in data:
                print("Found 'defaultcode' key")

                if "html" in data["defaultcode"]:
                    html_len = len(data["defaultcode"]["html"])
                    print(f"Found HTML content, length: {html_len}")
                else:
                    print("ERROR: No 'html' key in defaultcode")

                if "css" in data["defaultcode"]:
                    css_len = len(data["defaultcode"]["css"])
                    print(f"Found CSS content, length: {css_len}")
                else:
                    print("ERROR: No 'css' key in defaultcode")

                if "js" in data["defaultcode"]:
                    js_len = len(data["defaultcode"]["js"])
                    print(f"Found JS content, length: {js_len}")
                else:
                    print("ERROR: No 'js' key in defaultcode")

                return True
            else:
                print("ERROR: No 'defaultcode' key in JSON")
                return False

        except json.JSONDecodeError as e:
            print(f"ERROR: Failed to parse JSON: {str(e)}")
            return False

    except Exception as e:
        print(f"ERROR: Failed to read file: {str(e)}")
        return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python debug.py <json_file_path>")
        sys.exit(1)

    file_path = sys.argv[1]
    result = test_json_file(file_path)

    if result:
        print("\nJSON file test PASSED ✅")
    else:
        print("\nJSON file test FAILED ❌")
        sys.exit(1)
