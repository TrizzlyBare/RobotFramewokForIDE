*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String

*** Variables ***
${STUDENT_FILE}    students.json
${TEACHER_FILE}    teacher.json
${TEMP_DIR}        ./temp
${PYTHON_CMD}      python
${JAVASCRIPT_CMD}  node
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc
${RESULTS_FILE}    comparison_results.json

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${students}    Evaluate    json.load(open('${STUDENT_FILE}'))    json
    ${teachers}    Evaluate    json.load(open('${TEACHER_FILE}'))    json
    @{results}     Create List
    RETURN    ${students}    ${teachers}    ${results}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True

Execute Code With Input
    [Arguments]    ${code}    ${language}    ${input}
    ${filename}    Set Variable    test
    ${ext}         Set Variable If
    ...    '${language}' == 'Python'       .py
    ...    '${language}' == 'C++'          .cpp
    ...    '${language}' == 'Rust'         .rs
    ...    '${language}' == 'JavaScript'   .js

    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    Create File    ${TEMP_DIR}/input.txt            ${input}

    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}

    TRY
        IF    '${language}' == 'Python'
            ${result}    Run Process
            ...    ${PYTHON_CMD}
            ...    -c
            ...    with open('${TEMP_DIR}/${filename}${ext}', 'r') as f: exec(f.read())
            ...    stdin=${TEMP_DIR}/input.txt
            ...    shell=True
            ...    stderr=STDOUT
            ${output}    Set Variable    ${result.stdout.strip()}

        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process
            ...    ${CPP_COMPILER}
            ...    ${TEMP_DIR}/${filename}${ext}
            ...    -o
            ...    ${TEMP_DIR}/${filename}
            ...    shell=True
            ...    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process
                ...    ${TEMP_DIR}/${filename}
                ...    stdin=${TEMP_DIR}/input.txt
                ...    shell=True
                ...    stderr=STDOUT
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END

        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process
            ...    ${RUST_COMPILER}
            ...    ${TEMP_DIR}/${filename}${ext}
            ...    -o
            ...    ${TEMP_DIR}/${filename}
            ...    shell=True
            ...    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process
                ...    ${TEMP_DIR}/${filename}
                ...    stdin=${TEMP_DIR}/input.txt
                ...    shell=True
                ...    stderr=STDOUT
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END

        ELSE IF    '${language}' == 'JavaScript'
            ${result}    Run Process
            ...    ${JAVASCRIPT_CMD}
            ...    ${TEMP_DIR}/${filename}${ext}
            ...    shell=True
            ...    stderr=STDOUT
            ${output}    Set Variable    ${result.stdout.strip()}
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}

Validate Code Output
    [Arguments]    ${actual}    ${expected}
    ${is_valid}    Set Variable    True
    ${message}     Set Variable    Outputs match.

    IF    '${actual}' != '${expected}'
        ${is_valid}    Set Variable    False
        ${message}     Set Variable    Mismatch: Actual='${actual}'  Expected='${expected}'
    END

    RETURN    ${is_valid}    ${message}

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${details}    ${language}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=${details}
    ...    language=${language}
    Append To List    ${results}    ${result}

Save Comparison Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student Submission
    # Capture the three return values from Setup
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment

    ${students}    ${teachers}    ${results}    Setup Test Environment

    # Use student and teacher data
    ${language}         Set Variable    ${students}[language]
    ${test_input}       Set Variable    ${teachers}[testcase]
    ${expected_output}  Set Variable    ${teachers}[testresult]
    ${code}             Set Variable    ${students}[defaultCode]

    # Execute the student code with input
    ${status}    ${output}    Execute Code With Input    ${code}    ${language}    ${test_input}

    # Validate the results
    ${is_valid}    ${validation_message}    Validate Code Output    ${output}    ${expected_output}

    # Add to comparison results
    Add Comparison Result    ${results}    ${status}    ${validation_message}    ${language}

    Save Comparison Results  ${results}