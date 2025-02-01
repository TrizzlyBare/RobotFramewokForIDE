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
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc
${JAVASCRIPT_CMD}  node
${RESULTS_FILE}    comparison_results.json

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${student}    Load JSON From File    ${STUDENT_FILE}
    ${teacher}    Load JSON From File    ${TEACHER_FILE}
    @{results}    Create List
    RETURN    ${student}    ${teacher}    ${results}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True

Extract Unicode Value
    [Arguments]    ${output}
    ${output_lines}    Split To Lines    ${output}
    ${last_line}    Set Variable    ${output_lines}[-1]
    ${unicode_value}    Get Regexp Matches    ${last_line}    u[0-9a-fA-F]{4}
    RETURN    ${unicode_value}[0]

Execute Code With Input
    [Arguments]    ${code}    ${language}    ${input}
    ${filename}    Set Variable    test
    ${ext}    Set Variable If    
    ...    '${language}' == 'python'    .py
    ...    '${language}' == 'cpp'       .cpp
    ...    '${language}' == 'rust'      .rs
    ...    '${language}' == 'javascript'    .js
    
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    Create File    ${TEMP_DIR}/input.txt    ${input}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'python'
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}
            ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
            ${output}    Extract Unicode Value    ${result.stdout}
            
        ELSE IF    '${language}' == 'cpp'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    
                ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
                ${output}    Extract Unicode Value    ${result.stdout}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
            
        ELSE IF    '${language}' == 'rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    
                ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
                ${output}    Extract Unicode Value    ${result.stdout}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        
        ELSE IF    '${language}' == 'javascript'
            ${result}    Run Process    ${JAVASCRIPT_CMD}    ${TEMP_DIR}/${filename}${ext}    
            ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
            ${output}    Extract Unicode Value    ${result.stdout}
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${student_output}    ${teacher_output}    ${language}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=Student output: "${student_output}"\nTeacher output: "${teacher_output}"
    ...    language=${language}
    Append To List    ${results}    ${result}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student Code With Test Cases
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    ${student}    ${teacher}    ${results}    Setup Test Environment
    
    # Get test cases and expected results
    ${test_input}    Set Variable    ${teacher}[testcase]
    ${expected_output}    Set Variable    ${teacher}[testresult]
    
    # Execute student code with test input
    ${student_status}    ${student_output}    Execute Code With Input    
    ...    ${student}[defaultCode]    
    ...    ${student}[language]    
    ...    ${test_input}
    
    # Compare results
    ${test_status}    Set Variable If    
    ...    '${student_status}' != 'success'    FAIL
    ...    '${student_output}' != '${expected_output}'    FAIL
    ...    PASS
    
    # Add results
    Add Comparison Result    
    ...    ${results}    
    ...    ${test_status}    
    ...    ${student_output}    
    ...    ${expected_output}    
    ...    ${student}[language]
    
    # Save results
    Save Results    ${results}