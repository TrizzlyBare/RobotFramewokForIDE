*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String
Library           DateTime

*** Variables ***
${STUDENT_FILE}    students.json
${TEACHER_FILE}    teacher.json
${TEMP_DIR}        ./temp
${PYTHON_CMD}      python
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc
${JAVASCRIPT_CMD}  node
${PROLOG_CMD}    swipl
${RESULTS_FILE}    comparison_results.json

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${student}    Evaluate    json.load(open('${STUDENT_FILE}'))    json
    ${teacher}    Evaluate    json.load(open('${TEACHER_FILE}'))    json
    @{results}    Create List
    RETURN    ${student}    ${teacher}    ${results}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True

Validate Code Output
    [Arguments]    ${output}    ${status}
    ${is_valid}    Set Variable    ${True}
    ${message}    Set Variable    ${EMPTY}
    
    ${output_stripped}    Strip String    ${output}
    
    IF    $status == "success" and $output_stripped == ""
        ${is_valid}    Set Variable    ${False}
        ${message}    Set Variable    No output generated from code execution
    END
    
    RETURN    ${is_valid}    ${message}

Normalize Output
    [Arguments]    ${output}
    ${normalized}    Strip String    ${output}
    ${normalized}    Replace String    ${normalized}    \r\n    \n
    ${normalized}    Replace String    ${normalized}    \r    \n
    RETURN    ${normalized}

Get Current Time Ms
    ${time}    Evaluate    int(time.time() * 1000)    time
    RETURN    ${time}

Execute Code
    [Arguments]    ${code}    ${language}
    ${filename}    Set Variable    test
    ${ext}    Set Variable If    
    ...    '${language}' == 'python'    .py
    ...    '${language}' == 'cpp'       .cpp
    ...    '${language}' == 'rust'      .rs
    ...    '${language}' == 'javascript'    .js
    ...    '${language}' == 'prolog'    .pl
    
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    ${error_msg}    Set Variable    ${EMPTY}
    ${runtime}    Set Variable    0
    
    TRY
        IF    $language == "python"
            ${start_time}    Get Current Time Ms
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True
            ${end_time}    Get Current Time Ms
            ${runtime}    Evaluate    ${end_time} - ${start_time}
            ${output}    Set Variable    ${result.stdout}
            ${error_msg}    Set Variable    ${result.stderr}
            
        ELSE IF    $language == "javascript"
            ${start_time}    Get Current Time Ms
            ${result}    Run Process    ${JAVASCRIPT_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True
            ${end_time}    Get Current Time Ms
            ${runtime}    Evaluate    ${end_time} - ${start_time}
            ${output}    Set Variable    ${result.stdout}
            ${error_msg}    Set Variable    ${result.stderr}

        ELSE IF    $language == "cpp"
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            IF    ${compile_result.rc} == 0
                ${start_time}    Get Current Time Ms
                ${result}    Run Process    ${TEMP_DIR}/${filename}    shell=True
                ${end_time}    Get Current Time Ms
                ${runtime}    Evaluate    ${end_time} - ${start_time}
                ${output}    Set Variable    ${result.stdout}
                ${error_msg}    Set Variable    ${result.stderr}
            ELSE
                ${status}    Set Variable    compilation_error
                ${error_msg}    Set Variable    ${compile_result.stderr}
            END
            
        ELSE IF    $language == "rust"
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            IF    ${compile_result.rc} == 0
                ${start_time}    Get Current Time Ms
                ${result}    Run Process    ${TEMP_DIR}/${filename}    shell=True
                ${end_time}    Get Current Time Ms
                ${runtime}    Evaluate    ${end_time} - ${start_time}
                ${output}    Set Variable    ${result.stdout}
                ${error_msg}    Set Variable    ${result.stderr}
            ELSE
                ${status}    Set Variable    compilation_error
                ${error_msg}    Set Variable    ${compile_result.stderr}
            END
        ELSE IF    $language == "prolog"
            ${start_time}    Get Current Time Ms
            ${result}    Run Process    ${PROLOG_CMD}    -s    ${TEMP_DIR}/${filename}${ext}    -g    main,halt    -t    halt
            ${end_time}    Get Current Time Ms
            ${runtime}    Evaluate    ${end_time} - ${start_time}
            ${output}    Set Variable    ${result.stdout}
            ${error_msg}    Set Variable    ${result.stderr}
        ELSE
            ${status}    Set Variable    unsupported_language
            ${error_msg}    Set Variable    Unsupported language: ${language}
        END

        # Normalize and validate output
        ${output}    Normalize Output    ${output}
        ${is_valid}    ${validation_message}    Validate Code Output    ${output}    ${status}
        IF    not ${is_valid}
            ${status}    Set Variable    invalid_output
            ${error_msg}    Set Variable    ${validation_message}
        END

    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${error_msg}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}    ${error_msg}    ${runtime}

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${details}    ${language}    ${student_runtime}=${0}    ${teacher_runtime}=${0}    ${error_msg}=${EMPTY}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=${details}
    ...    language=${language}
    ...    student_runtime_ms=${student_runtime}
    ...    teacher_runtime_ms=${teacher_runtime}
    ...    error=${error_msg}
    Append To List    ${results}    ${result}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student And Teacher Code
    [Documentation]    Compare student code output with teacher's expected results
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    ${student}    ${teacher}    ${results}    Setup Test Environment
    
    # Execute student code
    ${student_status}    ${student_output}    ${student_error}    ${student_runtime}    Execute Code    
    ...    ${student}[defaultCode]    
    ...    ${teacher}[language]
    
    # Execute teacher code
    ${teacher_status}    ${teacher_output}    ${teacher_error}    ${teacher_runtime}    Execute Code    
    ...    ${teacher}[defaultCode]    
    ...    ${teacher}[language]
    
    # Compare normalized results
    ${student_output}    Normalize Output    ${student_output}
    ${teacher_output}    Normalize Output    ${teacher_output}
    ${details}    Set Variable    Student output: "${student_output}"\nTeacher output: "${teacher_output}"
    
    IF    $student_status != "success"
        Add Comparison Result    ${results}    FAIL    Student code error: ${student_output}    
        ...    ${student}[language]    ${student_runtime}    ${teacher_runtime}    ${student_error}
    ELSE IF    $teacher_status != "success"
        Add Comparison Result    ${results}    FAIL    Teacher code error: ${teacher_output}    
        ...    ${student}[language]    ${student_runtime}    ${teacher_runtime}    ${teacher_error}
    ELSE IF    $student_output == $teacher_output
        Add Comparison Result    ${results}    PASS    ${details}    ${student}[language]    ${student_runtime}    ${teacher_runtime}
    ELSE
        Add Comparison Result    ${results}    FAIL    ${details}    ${student}[language]    ${student_runtime}    ${teacher_runtime}
    END
    
    Save Results    ${results}