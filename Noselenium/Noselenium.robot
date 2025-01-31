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
    ${students}    Load JSON From File    ${STUDENT_FILE}
    ${teachers}    Load JSON From File    ${TEACHER_FILE}
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

*** Test Cases ***
Compare Student And Teacher Results
    [Documentation]    Compare student code outputs with teacher's expected results
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    ${students}    ${teachers}    ${results}    Setup Test Environment
    
    FOR    ${student}    IN    @{students}
        ${student_name}    Set Variable    ${student}[name]
        Log    Comparing results for student: ${student_name}
        
        # Get student's programming language
        ${first_topic}    Get From List    ${student}[enrolled_topics]    0
        ${first_submission}    Get From Dictionary    ${first_topic}[submitted_code]    hello_world
        ${student_language}    Set Variable    ${first_submission}[language]
        
        # Get matching teacher
        ${teacher}    Get Teacher For Language    ${teachers}    ${student_language}
        
        FOR    ${topic}    IN    @{student}[enrolled_topics]
            ${topic_name}    Set Variable    ${topic}[name]
            
            # Find matching teacher topic
            ${teacher_topic}    Set Variable    ${NONE}
            FOR    ${t_topic}    IN    @{teacher}[topics]
                IF    '${t_topic}[name]' == '${topic_name}'
                    ${teacher_topic}    Set Variable    ${t_topic}
                    BREAK
                END
            END
            
            FOR    ${problem_name}    IN    hello_world    sum_two_numbers    factorial
                ${student_submission}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                ${teacher_example}    Get From Dictionary    ${teacher_topic}[example_code]    ${problem_name}
                
                # Execute student code
                ${student_status}    ${student_output}    Execute Code    
                ...    ${student_submission}[code]    
                ...    ${student_submission}[language]
                
                # Execute teacher code
                ${teacher_status}    ${teacher_output}    Execute Code    
                ...    ${teacher_example}[code]    
                ...    ${teacher_example}[language]
                
                # Compare results
                ${details}    Set Variable    Student output: "${student_output}"\nTeacher output: "${teacher_output}"
                
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