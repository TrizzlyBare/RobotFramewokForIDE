*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String

*** Variables ***
${STUDENT_FILE}    ${EXECDIR}/students.json
${TEACHER_FILE}    ${EXECDIR}/teacher.json
${RESULTS_FILE}    ${EXECDIR}/comparison_results.json
${TEMP_DIR}        ${EXECDIR}/temp
${PYTHON_CMD}      python
${JAVASCRIPT_CMD}  node
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${students}    Evaluate    json.load(open('${STUDENT_FILE}'))    json
    ${teachers}    Evaluate    json.load(open('${TEACHER_FILE}'))    json
    RETURN    ${students}    ${teachers}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True
 

Get Language Extension
    [Arguments]    ${language}
    ${ext}    Set Variable If    
    ...    '${language}' == 'Python'    .py
    ...    '${language}' == 'C++'       .cpp
    ...    '${language}' == 'Rust'      .rs
    ...    '${language}' == 'JavaScript'    .js
    RETURN    ${ext}

Execute Student Code From Teacher Input
    [Arguments]    ${student_code}    ${teacher_input}    ${language}
    ${filename}    Set Variable    student
    ${ext}         Get Language Extension    ${language}
    Create Directory    ${TEMP_DIR}
    Create File    ${TEMP_DIR}/${filename}${ext}    ${student_code}
    Create File    ${TEMP_DIR}/input.txt    ${teacher_input}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'Python'
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True    stderr=STDOUT
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF   '${language}' == 'JavaScript'
            ${result}    Run Process    ${JAVASCRIPT_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True    stderr=STDOUT
            ${output}    Set Variable    ${result.stdout.strip()}

        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        ELSE
            ${status}    Set Variable    language_error
            ${output}    Set Variable    Language not supported
        END
    EXCEPT    Exception    err
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    err
    END
Save Comparison Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compile Student Code with Teacher Input then compare with Teacher Output
    [Documentation]    Compile student code with teacher input and compare with teacher output
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment

    # Load student and teacher files
    ${students}    Load JSON From File    ${STUDENT_FILE}

    
    

