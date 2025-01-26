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
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    input=${input}    shell=False    stdout=${TEMP_DIR}/stdout.txt    stderr=${TEMP_DIR}/stderr.txt
            ${output}    Get File    ${TEMP_DIR}/stdout.txt
            ${output}    Set Variable    ${output.strip()}
            
            
        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            Run Keyword If    ${compile_result.rc} != 0    Fail    Compilation Error: ${compile_result.stderr}
            
            ${result}    Run Process    ${TEMP_DIR}/${filename}    input=${input}    shell=True
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True
            Run Keyword If    ${compile_result.rc} != 0    Fail    Compilation Error: ${compile_result.stderr}
            
            ${result}    Run Process    ${TEMP_DIR}/${filename}    input=${input}    shell=True
            ${output}    Set Variable    ${result.stdout.strip()}
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}

Get Teacher With Matching Language
    [Arguments]    ${teachers}    ${language}
    FOR    ${teacher}    IN    @{teachers}
        FOR    ${topic}    IN    @{teacher}[topics]
            ${example_code}    Set Variable    ${topic}[example_code]
            ${keys}    Get Dictionary Keys    ${example_code}
            FOR    ${problem}    IN    @{keys}
                ${example_language}    Set Variable    ${example_code}[${problem}][language]
                Run Keyword If    '${example_language}' == '${language}'    
                ...    Return From Keyword    ${teacher}
            END
        END
    END
    Fail    msg=No teacher found for language ${language}

Find Teacher With Matching Language
    [Arguments]    ${teachers}    ${language}
    FOR    ${teacher}    IN    @{teachers}
        FOR    ${topic}    IN    @{teacher}[topics]
            ${example_code}    Set Variable    ${topic}[example_code]
            ${keys}    Get Dictionary Keys    ${example_code}
            FOR    ${problem}    IN    @{keys}
                ${example_language}    Set Variable    ${example_code}[${problem}][language]
                Run Keyword If    '${example_language}' == '${language}'    
                ...    Return From Keyword    ${teacher}
            END
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

Find Matching Topic
    [Arguments]    ${teacher_topics}    ${student_topic_name}
    FOR    ${teacher_topic}    IN    @{teacher_topics}
        ${topic_name}    Get From Dictionary    ${teacher_topic}    name
        Run Keyword If    '${topic_name}' == '${student_topic_name}'    
        ...    Return From Keyword    ${teacher_topic}
    END
    Return From Keyword    ${NONE}

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
            ${teacher_topic}    Find Matching Topic    ${teacher_match}[topics]    ${topic_name}
            
            # Dynamically get problem names
            @{problem_names}    Get Dictionary Keys    ${topic}[submitted_code]
            
            FOR    ${problem_name}    IN    @{problem_names}
                ${student_submission}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                
                # Skip if problem not in teacher's example code
                ${example_code_keys}    Get Dictionary Keys    ${teacher_topic}[example_code]
                Continue For Loop If    '${problem_name}' not in ${example_code_keys}
                
                ${teacher_example}    Get From Dictionary    ${teacher_topic}[example_code]    ${problem_name}
                
                # Use teacher's input and output
                ${input}    Set Variable    ${teacher_example}[input]
                ${expected_output}    Set Variable    ${teacher_example}[output]
                
                # Execute student code
                ${student_status}    ${student_output}    Run Keyword If    '${input}' != '${EMPTY}'
                ...    Execute Code With Input    ${student_submission}[code]    ${student_submission}[language]    ${input}
                ...    ELSE    Execute Code    ${student_submission}[code]    ${student_submission}[language]
                
                # Execute teacher code 
                ${teacher_status}    ${teacher_output}    Run Keyword If    '${input}' != '${EMPTY}'
                ...    Execute Code With Input    ${teacher_example}[code]    ${teacher_example}[language]    ${input}
                ...    ELSE    Execute Code    ${teacher_example}[code]    ${teacher_example}[language]
                
                # Detailed comparison with extended conditions
                ${details}    Set Variable    Actual output: "${student_output}" | Expected output: "${teacher_output}"
                
                IF    '${student_status}' != 'success'
                    Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                    ...    FAIL    Student code error: ${student_output}    ${student_submission}[language]
                ELSE IF    '${teacher_status}' != 'success'
                    Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                    ...    FAIL    Teacher code error: ${teacher_output}    ${student_submission}[language]
                ELSE IF    '${student_output}' == '${teacher_output}'
                    Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                    ...    PASS    ${details}    ${student_submission}[language]
                ELSE
                    Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                    ...    FAIL    ${details}    ${student_submission}[language]
                END
            END
        END
    END
    
    Save Results    ${results}