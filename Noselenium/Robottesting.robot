*** Settings ***
Library           OperatingSystem
Library           Process

*** Variables ***
${TEMP_FILE}      temp_script.py

*** Test Cases ***
Run Script With Multiple Inputs
    [Documentation]    Simulate multiple inputs during execution.
    Create File        ${TEMP_FILE}    print(input("Enter your first name: "))\nprint(input("Enter your last name: "))
    ${result}          Run Process    python3    ${TEMP_FILE}    stdin=John\nDoe
    Log To Console     ${result.stdout}
    Remove File        ${TEMP_FILE}
