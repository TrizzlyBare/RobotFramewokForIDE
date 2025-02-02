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
${LOG_FILE}        execution.log

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${student}    Load JSON From File    ${STUDENT_FILE}
    ${teacher}    Load JSON From File    ${TEACHER_FILE}
    @{results}    Create List
    ${current_time}    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
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
    ${final_lines}    Create List
    
    # Define patterns to remove
    @{patterns_to_remove}    Create List
    ...    (?i)Enter [A-Za-z\\s]+:
    ...    (?i)Input [A-Za-z\\s]+:
    ...    (?i)Please enter [A-Za-z\\s]+:
    ...    (?i)The Unicode is:
    
    # Process each line
    FOR    ${line}    IN    @{lines}
        ${stripped}    Strip String    ${line}
        # Skip empty lines
        Continue For Loop If    '${stripped}' == ''
        
        # Remove all defined patterns
        ${cleaned}    Set Variable    ${stripped}
        FOR    ${pattern}    IN    @{patterns_to_remove}
            ${cleaned}    Replace String Using Regexp    ${cleaned}    ${pattern}    ${EMPTY}
        END
        ${cleaned}    Strip String    ${cleaned}
        
        # Skip if line is empty after cleaning
        Continue For Loop If    '${cleaned}' == ''
        
        # Add non-empty line to results
        Append To List    ${final_lines}    ${cleaned}
    END
    
    # Join all valid lines with newlines
    ${final_output}    Evaluate    "\\n".join($final_lines)
    Log Debug Info    Final processed output: ${final_output}
    RETURN    ${final_output}

Normalize Output
    [Arguments]    ${output}
    ${normalized}    Set Variable    ${output}
    
    # Handle empty output
    ${is_empty}    Run Keyword And Return Status    Should Be Empty    ${normalized}
    IF    ${is_empty}
        RETURN    ${normalized}
    END
    
    # Handle multi-line output
    ${lines}    Split To Lines    ${normalized}
    ${stripped_lines}    Create List
    FOR    ${line}    IN    @{lines}
        ${stripped}    Strip String    ${line}
        Continue For Loop If    '${stripped}' == ''
        
        # Try to convert each line to number if possible
        TRY
            ${as_number}    Convert To Number    ${stripped}
            ${normalized_line}    Convert To String    ${as_number}
        EXCEPT
            ${normalized_line}    Set Variable    ${stripped}
        END
        
        Append To List    ${stripped_lines}    ${normalized_line}
    END
    
    # Join non-empty lines with proper line endings
    ${normalized}    Evaluate    "\\n".join($stripped_lines)
    
    # Remove any trailing/leading whitespace from final result
    ${normalized}    Strip String    ${normalized}
    Log Debug Info    Normalized output: ${normalized}
    RETURN    ${normalized}

Prepare Input File
    [Arguments]    ${input}
    ${input_exists}    Run Keyword And Return Status    Variable Should Exist    ${input}
    ${input_not_none}    Run Keyword And Return Status    Should Not Be Equal    ${input}    None
    ${should_create_input}    Evaluate    ${input_exists} and ${input_not_none}
    
    IF    ${should_create_input}
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
        ...    stdin=${input_file}    shell=True    stderr=STDOUT    
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
            ...    stdin=${input_file}    shell=True    stderr=STDOUT   
        ELSE
            ${result}    Run Process    ${TEMP_DIR}/program    
            ...    shell=True    stderr=STDOUT    
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
    
    # Handle multi-line comparison
    ${student_lines}    Split To Lines    ${normalized_student}
    ${expected_lines}    Split To Lines    ${normalized_expected}
    
    # Compare line by line
    ${student_length}    Get Length    ${student_lines}
    ${expected_length}    Get Length    ${expected_lines}
    
    IF    ${student_length} != ${expected_length}
        Log Debug Info    Different number of lines - Student: ${student_length}, Expected: ${expected_length}
        RETURN    ${FALSE}
    END
    
    FOR    ${index}    IN RANGE    ${student_length}
        ${student_line}    Get From List    ${student_lines}    ${index}
        ${expected_line}    Get From List    ${expected_lines}    ${index}
        
        # Normalize line endings and whitespace
        ${student_line}    Replace String    ${student_line}    \r    ${EMPTY}
        ${expected_line}    Replace String    ${expected_line}    \r    ${EMPTY}
        ${student_line}    Strip String    ${student_line}
        ${expected_line}    Strip String    ${expected_line}
        
        ${line_matches}    Run Keyword And Return Status
        ...    Should Be Equal As Strings    ${student_line}    ${expected_line}
        
        IF    not ${line_matches}
            Log Debug Info    Mismatch at line ${index} - Student: "${student_line}", Expected: "${expected_line}"
            RETURN    ${FALSE}
        END
    END
    
    Log Debug Info    Outputs match completely
    RETURN    ${TRUE}

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${student_output}    ${expected_output}    ${language}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=Student output: "${student_output}"\nTeacher output: "${expected_output}"
    ...    language=${language}
    Append To List    ${results}    ${result}
    Log Debug Info    Added comparison result - Status: ${status}, Student: ${student_output}, Teacher: ${expected_output}

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