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
${RESULTS_FILE}    comparison_results.json
${LOG_FILE}        execution_log.txt

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${student}    Load JSON From File    ${STUDENT_FILE}
    ${teacher}    Load JSON From File    ${TEACHER_FILE}
    @{results}    Create List
    ${current_time}    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Create File    ${LOG_FILE}    Test execution started at ${current_time}\n
    RETURN    ${student}    ${teacher}    ${results}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True

Log Debug Info
    [Arguments]    ${message}
    ${timestamp}    Get Current Date    result_format=%Y-%m-%d %H:%M:%S.%f
    Append To File    ${LOG_FILE}    ${timestamp}: ${message}\n

Get Final Output
    [Arguments]    ${output}
    Log Debug Info    Processing raw output: ${output}
    ${lines}    Split To Lines    ${output}
    
    # Initialize variables
    ${final_output}    Set Variable    ${EMPTY}
    
    # Start from the last line and find the first non-empty line
    ${length}    Get Length    ${lines}
    FOR    ${index}    IN RANGE    ${length-1}    -1    -1
        ${line}    Get From List    ${lines}    ${index}
        ${stripped}    Strip String    ${line}
        # Skip empty lines
        Continue For Loop If    '${stripped}' == ''
        
        # Remove common input prompts and their content
        ${cleaned}    Replace String Using Regexp    ${stripped}    (?i)Enter [A-Za-z]+:\\s*    ${EMPTY}
        ${cleaned}    Replace String Using Regexp    ${cleaned}    (?i)Input [A-Za-z]+:\\s*    ${EMPTY}
        ${cleaned}    Replace String Using Regexp    ${cleaned}    (?i)Please enter [A-Za-z]+:\\s*    ${EMPTY}
        ${cleaned}    Strip String    ${cleaned}
        
        # Skip if line is empty after cleaning
        Continue For Loop If    '${cleaned}' == ''
        
        # Found valid output
        ${final_output}    Set Variable    ${cleaned}
        Exit For Loop
    END
    
    Log Debug Info    Final raw output: ${final_output}
    RETURN    ${final_output}
    
Normalize Output
    [Arguments]    ${output}
    ${normalized}    Set Variable    ${output}
    
    # Handle empty output
    IF    '${normalized}' == ''
        RETURN    ${normalized}
    END
    
    # Try to convert to number if possible
    TRY
        ${as_number}    Convert To Number    ${normalized}
        ${normalized}    Convert To String    ${as_number}
    EXCEPT
        # Keep as string if not numeric
        Log Debug Info    Output is not numeric, keeping as string: ${normalized}
    END
    
    # Remove any trailing/leading whitespace
    ${normalized}    Strip String    ${normalized}
    Log Debug Info    Normalized output: ${normalized}
    RETURN    ${normalized}

Prepare Input File
    [Arguments]    ${input}
    ${input_exists}    Run Keyword And Return Status    Should Not Be Equal    ${input}    None
    IF    ${input_exists}
        # Ensure input ends with newline and handle Windows-style line endings
        ${normalized_input}    Replace String    ${input}    \r\n    \n
        ${has_newline}    Run Keyword And Return Status    Should End With    ${normalized_input}    \n
        IF    not ${has_newline}
            ${normalized_input}    Set Variable    ${normalized_input}\n
        END
        Create File    ${TEMP_DIR}/input.txt    ${normalized_input}    encoding=UTF-8
        Log Debug Info    Created input file with content: ${normalized_input}
        RETURN    ${True}    ${TEMP_DIR}/input.txt
    END
    RETURN    ${False}    ${EMPTY}

Execute Python Code
    [Arguments]    ${filename}    ${has_input}    ${input_file}
    IF    ${has_input}
        ${result}    Run Process    ${PYTHON_CMD}    ${filename}    
        ...    stdin=${input_file}    shell=True    stderr=STDOUT    stdout=STDOUT
        Log Debug Info    Python execution with input - RC: ${result.rc}, Output:\n${result.stdout}
    ELSE
        ${result}    Run Process    ${PYTHON_CMD}    ${filename}    
        ...    shell=True    stderr=STDOUT    stdout=STDOUT
        Log Debug Info    Python execution without input - RC: ${result.rc}, Output:\n${result.stdout}
    END
    RETURN    ${result}

Execute CPP Code
    [Arguments]    ${filename}    ${has_input}    ${input_file}
    # Compile
    ${compile_result}    Run Process    ${CPP_COMPILER}    ${filename}    -o    
    ...    ${TEMP_DIR}/program    shell=True    stderr=STDOUT
    Log Debug Info    C++ compilation result: ${compile_result.stdout}
    
    IF    ${compile_result.rc} == 0
        IF    ${has_input}
            ${result}    Run Process    ${TEMP_DIR}/program    
            ...    stdin=${input_file}    shell=True    stderr=STDOUT    stdout=STDOUT
        ELSE
            ${result}    Run Process    ${TEMP_DIR}/program    
            ...    shell=True    stderr=STDOUT    stdout=STDOUT
        END
        Log Debug Info    C++ execution output:\n${result.stdout}
        RETURN    success    ${result}
    ELSE
        RETURN    compilation_error    ${compile_result}
    END

Execute Rust Code
    [Arguments]    ${filename}    ${has_input}    ${input_file}
    # Compile
    ${compile_result}    Run Process    ${RUST_COMPILER}    ${filename}    -o    
    ...    ${TEMP_DIR}/program    shell=True    stderr=STDOUT
    Log Debug Info    Rust compilation result: ${compile_result.stdout}
    
    IF    ${compile_result.rc} == 0
        IF    ${has_input}
            ${result}    Run Process    ${TEMP_DIR}/program    
            ...    stdin=${input_file}    shell=True    stderr=STDOUT    stdout=STDOUT
        ELSE
            ${result}    Run Process    ${TEMP_DIR}/program    
            ...    shell=True    stderr=STDOUT    stdout=STDOUT
        END
        Log Debug Info    Rust execution output:\n${result.stdout}
        RETURN    success    ${result}
    ELSE
        RETURN    compilation_error    ${compile_result}
    END

Execute JavaScript Code
    [Arguments]    ${filename}    ${has_input}    ${input_file}
    IF    ${has_input}
        ${result}    Run Process    ${JAVASCRIPT_CMD}    ${filename}    
        ...    stdin=${input_file}    shell=True    stderr=STDOUT    stdout=STDOUT
    ELSE
        ${result}    Run Process    ${JAVASCRIPT_CMD}    ${filename}    
        ...    shell=True    stderr=STDOUT    stdout=STDOUT
    END
    Log Debug Info    JavaScript execution output:\n${result.stdout}
    RETURN    ${result}

Execute Code With Input
    [Arguments]    ${code}    ${language}    ${input}
    ${filename}    Set Variable    test
    ${ext}    Set Variable If    
    ...    '${language}' == 'python'    .py
    ...    '${language}' == 'cpp'       .cpp
    ...    '${language}' == 'rust'      .rs
    ...    '${language}' == 'javascript'    .js
    
    # Log code and input for debugging
    Log Debug Info    Executing code in ${language}:\n${code}
    Log Debug Info    Input values: ${input}
    
    # Create the code file
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    
    # Prepare input file if needed
    ${has_input}    ${input_file}    Prepare Input File    ${input}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'python'
            ${result}    Execute Python Code    ${TEMP_DIR}/${filename}${ext}    ${has_input}    ${input_file}
            IF    ${result.rc} != 0
                ${status}    Set Variable    runtime_error
                ${output}    Set Variable    ${result.stdout}
                Log Debug Info    Python runtime error: ${result.stdout}
            ELSE
                ${raw_output}    Get Final Output    ${result.stdout}
                ${output}    Normalize Output    ${raw_output}
                Log Debug Info    Python final output: ${output}
            END
            
        ELSE IF    '${language}' == 'cpp'
            ${exec_status}    ${result}    Execute CPP Code    ${TEMP_DIR}/${filename}${ext}    
            ...    ${has_input}    ${input_file}
            IF    '${exec_status}' == 'success'
                ${raw_output}    Get Final Output    ${result.stdout}
                ${output}    Normalize Output    ${raw_output}
                Log Debug Info    C++ final output: ${output}
            ELSE
                ${status}    Set Variable    ${exec_status}
                ${output}    Set Variable    ${result.stdout}
            END
            
        ELSE IF    '${language}' == 'rust'
            ${exec_status}    ${result}    Execute Rust Code    ${TEMP_DIR}/${filename}${ext}    
            ...    ${has_input}    ${input_file}
            IF    '${exec_status}' == 'success'
                ${raw_output}    Get Final Output    ${result.stdout}
                ${output}    Normalize Output    ${raw_output}
                Log Debug Info    Rust final output: ${output}
            ELSE
                ${status}    Set Variable    ${exec_status}
                ${output}    Set Variable    ${result.stdout}
            END
            
        ELSE IF    '${language}' == 'javascript'
            ${result}    Execute JavaScript Code    ${TEMP_DIR}/${filename}${ext}    
            ...    ${has_input}    ${input_file}
            IF    ${result.rc} != 0
                ${status}    Set Variable    runtime_error
                ${output}    Set Variable    ${result.stdout}
                Log Debug Info    JavaScript runtime error: ${result.stdout}
            ELSE
                ${raw_output}    Get Final Output    ${result.stdout}
                ${output}    Normalize Output    ${raw_output}
                Log Debug Info    JavaScript final output: ${output}
            END
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
        Log Debug Info    Exception occurred: ${error}
    END
    
    Log Debug Info    Final execution status: ${status}
    Log Debug Info    Final processed output: ${output}
    RETURN    ${status}    ${output}

Compare Outputs
    [Arguments]    ${student_output}    ${expected_output}
    ${normalized_student}    Normalize Output    ${student_output}
    ${normalized_expected}    Normalize Output    ${expected_output}
    ${is_equal}    Run Keyword And Return Status
    ...    Should Be Equal As Strings    ${normalized_student}    ${normalized_expected}
    Log Debug Info    Comparing outputs - Student: "${normalized_student}", Expected: "${normalized_expected}", Match: ${is_equal}
    RETURN    ${is_equal}

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${student_output}    ${teacher_output}    ${language}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=Student output: "${student_output}"\nTeacher output: "${teacher_output}"
    ...    language=${language}
    Append To List    ${results}    ${result}
    Log Debug Info    Added comparison result - Status: ${status}, Student: ${student_output}, Teacher: ${teacher_output}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}
    Log Debug Info    Saved results to ${RESULTS_FILE}

Handle Invalid Code
    [Arguments]    ${results}    ${expected_output}    ${language}
    Log Debug Info    Handling invalid code for language: ${language}
    Add Comparison Result    
    ...    ${results}    
    ...    FAIL    
    ...    No valid code provided    
    ...    ${expected_output}    
    ...    ${language}

*** Test Cases ***
Compare Student Code With Test Cases
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    ${student}    ${teacher}    ${results}    Setup Test Environment
    Log Debug Info    Starting test execution
    
    # Get test cases and expected results
    ${test_input}    Set Variable    ${teacher}[testcase]
    ${expected_output}    Set Variable    ${teacher}[testresult]
    ${code}    Set Variable    ${student}[defaultCode]
    
    Log Debug Info    Test input: ${test_input}
    Log Debug Info    Expected output: ${expected_output}
    Log Debug Info    Student code: ${code}
    
    # Execute and compare
    ${use_code}    Run Keyword And Return Status    Should Not Be Equal    ${code}    None
    IF    not ${use_code}
        Handle Invalid Code    ${results}    ${expected_output}    ${student}[language]
    ELSE
        # Execute student code
        ${student_status}    ${student_output}    Execute Code With Input    
        ...    ${code}    
        ...    ${student}[language]    
        ...    ${test_input}
        
        # Compare outputs
        ${outputs_match}    Compare Outputs    ${student_output}    ${expected_output}
        ${test_status}    Set Variable If    
        ...    '${student_status}' != 'success'    FAIL
        ...    not ${outputs_match}    FAIL
        ...    PASS
        
        # Add results
        Add Comparison Result    
        ...    ${results}    
        ...    ${test_status}    
        ...    ${student_output}    
        ...    ${expected_output}    
        ...    ${student}[language]
    END
    
    # Save final results
    Save Results    ${results}
    Log Debug Info    Test execution completed