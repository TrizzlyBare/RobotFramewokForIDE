*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String

*** Variables ***
${STUDENT_FILE}    ${EXECDIR}/students.json
${TEACHER_FILE}    ${EXECDIR}/teacher.json
${TEMP_DIR}        ${EXECDIR}/temp
${PYTHON_CMD}      python
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc
${RESULTS_FILE}    ${EXECDIR}/comparison_results.json

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${students}    Evaluate    json.load(open('${STUDENT_FILE}'))    json
    ${teachers}    Evaluate    json.load(open('${TEACHER_FILE}'))    json
    @{results}    Create List
    RETURN    ${students}    ${teachers}    ${results}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True

Execute Code
    [Arguments]    ${code}    ${language}
    ${filename}    Set Variable    test
    ${ext}    Set Variable If    
    ...    '${language}' == 'Python'    .py
    ...    '${language}' == 'C++'       .cpp
    ...    '${language}' == 'Rust'      .rs
    
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'Python'
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    shell=True
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
            
        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    shell=True
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}

Get Teacher For Language
    [Arguments]    ${teachers}    ${language}
    FOR    ${teacher}    IN    @{teachers}
        ${first_topic}    Get From List    ${teacher}[topics]    0
        ${first_example}    Get From Dictionary    ${first_topic}[example_code]    hello_world
        IF    '${first_example}[language]' == '${language}'
            RETURN    ${teacher}
        END
    END
    Fail    msg=No teacher found for language ${language}

Add Comparison Result
    [Arguments]    ${results}    ${student_name}    ${topic_name}    ${problem_name}    ${status}    ${details}    ${language}
    ${result}    Create Dictionary
    ...    student_name=${student_name}
    ...    topic_name=${topic_name}
    ...    problem_name=${problem_name}
    ...    status=${status}
    ...    details=${details}
    ...    language=${language}
    Append To List    ${results}    ${result}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

Find Matching Result
    [Arguments]    ${results}    ${expected}
    FOR    ${result}    IN    @{results}
        ${is_match}    Evaluate Matching Criteria    ${result}    ${expected}
        Return From Keyword If    ${is_match}    ${result}
    END
    RETURN    ${None}

Execute Code With Input
    [Arguments]    ${code}    ${language}    ${input}
    ${filename}    Set Variable    test
    ${ext}    Set Variable If    
    ...    '${language}' == 'Python'    .py
    ...    '${language}' == 'C++'       .cpp
    ...    '${language}' == 'Rust'      .rs
    
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'Python'
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    input=${input}    shell=True
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    input=${input}    shell=True
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
            
        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    input=${input}    shell=True
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}

Evaluate Matching Criteria
    [Arguments]    ${result}    ${expected}
    ${match}    Evaluate    
    ...    '${result}[student_name]' == '${expected}[student_name]' and 
    ...    '${result}[problem_name]' == '${expected}[problem_name]'
    RETURN    ${match}

Compare Result Details
    [Arguments]    ${expected}    ${actual}
    Should Be Equal    ${actual}[status]    ${expected}[status]
    Should Be Equal    ${actual}[output]    ${expected}[output]

Find Teacher With Matching Language
    [Arguments]    ${teachers}    ${language}
    FOR    ${teacher}    IN    @{teachers}
        FOR    ${topic}    IN    @{teacher}[topics]
            FOR    ${problem}    IN    ${topic}[example_code].keys()
                ${example_language}    Set Variable    ${topic}[example_code][${problem}][language]
                Run Keyword If    '${example_language}' == '${language}'    
                ...    Return From Keyword    ${teacher}
            END
        END
    END
    Fail    msg=No teacher found for language ${language}

Get Teacher Problem Output
    [Arguments]    ${teacher}    ${topic_name}    ${problem_name}
    FOR    ${topic}    IN    @{teacher}[topics]
        IF    '${topic}[name]' == '${topic_name}'
            RETURN    ${topic}[example_code][${problem_name}][output]
        END
    END
    Fail    msg=No matching topic found for ${topic_name}

*** Test Cases ***
Checking Student Code from Input and Output
    [Documentation]    Test student code using teacher's inputs and expected outputs
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    # Initialize results list
    @{results}    Create List
    
    # Load teachers and students
    ${teachers}    Load JSON From File    ${TEACHER_FILE}
    ${students}    Load JSON From File    ${STUDENT_FILE}
    
    FOR    ${student}    IN    @{students}
        ${student_name}    Set Variable    ${student}[name]
        
        # Find teacher with matching language
        ${first_submission}    Get From Dictionary    ${student}[topics][0][submitted_code]    hello_world
        ${teacher_match}    Find Teacher With Matching Language    ${teachers}    ${first_submission}[language]
        
        FOR    ${topic}    IN    @{student}[topics]
            ${topic_name}    Set Variable    ${topic}[name]
            
            # Find corresponding teacher topic
            ${teacher_topic}    Set Variable    ${NONE}
            FOR    ${t_topic}    IN    @{teacher_match}[topics]
                IF    '${t_topic}[name]' == '${topic_name}'
                    ${teacher_topic}    Set Variable    ${t_topic}
                    BREAK
                END
            END
            
            
            # Dynamically get problem names
            @{problem_names}    Get Dictionary Keys    ${topic}[submitted_code]
            
            FOR    ${problem_name}    IN    @{problem_names}
                ${student_code}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                
                # Skip if problem not in teacher's example code
                Continue For Loop If    not ${teacher_topic}[example_code].get('${problem_name}')
                
                ${teacher_example}    Get From Dictionary    ${teacher_topic}[example_code]    ${problem_name}
                
                # Use teacher's input and output
                ${input}    Set Variable    ${teacher_example}[input]
                ${expected_output}    Set Variable    ${teacher_example}[output]
                
                # Execute code with or without input
                ${status}    ${actual_output}    Run Keyword If    '${input}' != '${EMPTY}'
                ...    Execute Code With Input    ${student_code}[code]    ${student_code}[language]    ${input}
                ...    ELSE    Execute Code    ${student_code}[code]    ${student_code}[language]
                
                # Verify result
                Run Keyword If    '${status}' != 'success'    
                ...    Fail    Execution failed for ${student_name}'s ${problem_name}: ${actual_output}
                
                Should Be Equal As Strings    ${actual_output}    ${expected_output}    
                ...    msg=Output mismatch for ${student_name}'s ${problem_name}
                
                # Add comparison result
                Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                ...    PASS    Actual output: "${actual_output}"    ${student_code}[language]
            END
        END
    END
    
    Save Results    ${results}
