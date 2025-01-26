*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String
Library           BuiltIn

*** Variables ***
${STUDENT_FILE}  ${EXECDIR}/students.json
${TEACHER_FILE}  ${EXECDIR}/teacher.json
${RESULTS_FILE}  ${EXECDIR}/comparison_results.json
${TEMP_DIR}      ${EXECDIR}/temp
${PYTHON_CMD}    python3
${JAVASCRIPT_CMD}     node
${CPP_COMPILER}   g++
${RUST_COMPILER}  rustc

*** Keywords ***
Get Language Extension
    [Arguments]  ${language}
    ${ext}  Set Variable If 
        ...  '${language}' == 'Python'       .py
        ...  '${language}' == 'C++'          .cpp
        ...  '${language}' == 'Rust'         .rs
        ...  '${language}' == 'JavaScript'   .js
        ...  ${EMPTY}
    RETURN  ${ext}

Execute Code
    [Arguments]  ${code}  ${language} 
    ${filename}  Set Variable  test
    ${ext}       Get Language Extension  ${language}
    Create Directory  ${TEMP_DIR}  
    ${filepath}  Set Variable  ${TEMP_DIR}/${filename}${ext} 
    Create File  ${filepath}  ${code} 

    ${status}  Set Variable  success
    ${output}  Set Variable  ${EMPTY}

    TRY
        IF  '${language}' == 'Python'
            ${result}  Run Process  ${PYTHON_CMD}  ${filepath}  stdout=STDOUT  stderr=STDERR
            ${output}  Set Variable  ${result.stdout.strip()}
            ${status}  Set Variable If  ${result.rc} == 0  success  runtime_error
        ELSE IF  '${language}' == 'JavaScript'
            ${result}  Run Process  ${JAVASCRIPT_CMD}  ${filepath}  stdout=STDOUT  stderr=STDERR
            ${output}  Set Variable  ${result.stdout.strip()}
            ${status}  Set Variable If  ${result.rc} == 0  success  runtime_error
        ELSE IF  '${language}' == 'C++'
            ${compile_result}  Run Process  ${CPP_COMPILER}  ${filepath}  -o  ${TEMP_DIR}/${filename}  shell=True
            IF  ${compile_result.rc} == 0
                ${result}  Run Process  ${TEMP_DIR}/${filename}  stdout=STDOUT  stderr=STDERR
                ${output}  Set Variable  ${result.stdout.strip()}
                ${status}  Set Variable  success
            ELSE
                ${status}  Set Variable  compilation_error
                ${output}  Set Variable  ${compile_result.stderr}
            END
        ELSE IF  '${language}' == 'Rust'
            ${compile_result}  Run Process  ${RUST_COMPILER}  ${filepath}  -o  ${TEMP_DIR}/${filename}  stdout=STDOUT  stderr=STDERR
            IF  ${compile_result.rc} == 0
                ${result}  Run Process  ${TEMP_DIR}/${filename}  stdout=STDOUT  stderr=STDERR
                ${output}  Set Variable  ${result.stdout.strip()}
                ${status}  Set Variable  success
            ELSE
                ${status}  Set Variable  compilation_error
                ${output}  Set Variable  ${compile_result.stderr}
            END
        END
    EXCEPT  AS  ${error}
        ${status}  Set Variable  runtime_error
        ${output}  Set Variable  ${error}
    END

    RETURN  ${status}  ${output}

*** Test Cases ***
Compare Student and Teacher Results
    [Documentation]  Compare Compiled student code outputs with teacher's compiled teacher code outputs
    # Load student and teacher files
    ${students}  Load JSON From File  ${STUDENT_FILE}
    ${teachers}  Load JSON From File  ${TEACHER_FILE}

    # Get student and teacher data
    ${student_language}  Get From Dictionary  ${students}  language
    ${teacher_language}  Get From Dictionary  ${teachers}  language
    ${student_code}     Get From Dictionary  ${students}  defaultCode
    ${teacher_code}     Get From Dictionary  ${teachers}  defaultCode

    # Execute student and teacher code
    ${student_status}  ${student_output}  Execute Code  ${student_code}  ${student_language}  
    ${teacher_status}  ${teacher_output}  Execute Code  ${teacher_code}  ${teacher_language}  
    Log To Console  ${student_output}
    Log To Console  ${teacher_output}

    # Verify execution statuses
    Should Be Equal    ${student_status}    success
    Should Be Equal    ${teacher_status}    success

    # Compare outputs
    ${results}  Create List
    ${test_status}  Set Variable If  '${student_output}' == '${teacher_output}'  PASS  FAIL
    ${reason}  Set Variable If  '${student_output}' == '${teacher_output}'  
    ...  Outputs match  Outputs do not match (Student: ${student_output}, Teacher: ${teacher_output})

    ${result}  Create Dictionary
        ...  status=${test_status}
        ...  details=${students}[title]
        ...  reason=${reason}
    Append To List  ${results}  ${result}
    
    ${json_string}  Evaluate  json.dumps($results, indent=2)  json
    Create File  ${RESULTS_FILE}  ${json_string}

    # Force test to fail if outputs do not match
    Should Be Equal  ${student_output}  ${teacher_output}