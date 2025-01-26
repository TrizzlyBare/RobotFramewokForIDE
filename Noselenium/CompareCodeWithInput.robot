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
${JAVASCRIPT_CMD}  node
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc
${RESULTS_FILE}    ${EXECDIR}/comparison_results.json

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    ${students}    Evaluate    json.load(open('${STUDENT_FILE}'))    json
    ${teachers}    Evaluate    json.load(open('${TEACHER_FILE}'))    json
    RETURN    ${students}    ${teachers}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True

Execute Code With Input
    [Arguments]    ${code}    ${language}    ${input}
    ${filename}    Set Variable    test
    ${ext}    Set Variable If    
    ...    '${language}' == 'Python'    .py
    ...    '${language}' == 'C++'       .cpp
    ...    '${language}' == 'Rust'      .rs
    ...    '${language}' == 'JavaScript'    .js
    
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    Create File    ${TEMP_DIR}/input.txt    ${input}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'Python'
            # Use python -c to handle input prompts with escaped quotes
            ${result}    Run Process    ${PYTHON_CMD}    -c    
            ...    with open('${TEMP_DIR}/${filename}${ext}', 'r') as f: exec(f.read())    
            ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    
                ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
            
        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    stderr=STDOUT
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    
                ...    stdin=${TEMP_DIR}/input.txt    shell=True    stderr=STDOUT
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        
        ELSE IF    '${language}' == 'JavaScript'
            ${result}    Run Process    ${JAVASCRIPT_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True
            ${output}    Set Variable    ${result.stdout.strip()}
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    END
    RETURN    ${status}    ${output}

Find Matching Teacher
    [Arguments]    ${teachers}    ${language}
    FOR    ${teacher}    IN    @{teachers}
        FOR    ${topic}    IN    @{teacher}[topics]
            ${example_code_dict}    Set Variable    ${topic}[example_code]
            FOR    ${problem}    IN    @{example_code_dict.keys()}
                ${example_language}    Set Variable    ${example_code_dict}[${problem}][language]
                Run Keyword If    '${example_language}' == '${language}'    
                ...    Return From Keyword    ${teacher}
            END
        END
    END
    Fail    msg=No teacher found for language ${language}

Save Comparison Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student Submissions
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    # Initialize results list
    @{results}    Create List
    
    # Load teachers and students
    ${teachers}    Load JSON From File    ${TEACHER_FILE}
    ${students}    Load JSON From File    ${STUDENT_FILE}
    
    # Iterate through each student
    FOR    ${student}    IN    @{students}
        ${student_name}    Set Variable    ${student}[name]
        
        # Find a teacher with matching language for the first problem
        ${first_topic}    Get From List    ${student}[topics]    0
        @{submission_keys}    Get Dictionary Keys    ${first_topic}[submitted_code]
        ${first_problem}    Get From List    ${submission_keys}    0
        ${first_submission}    Get From Dictionary    ${first_topic}[submitted_code]    ${first_problem}
        ${student_language}    Set Variable    ${first_submission}[language]
        ${matching_teacher}    Find Matching Teacher    ${teachers}    ${student_language}
        
        # Iterate through student's topics
        FOR    ${topic}    IN    @{student}[topics]
            ${topic_name}    Set Variable    ${topic}[name]
            
            # Find matching teacher topic
            FOR    ${teacher_topic}    IN    @{matching_teacher}[topics]
                ${teacher_topic_name}    Set Variable    ${teacher_topic}[name]
                Continue For Loop If    '${topic_name}' != '${teacher_topic_name}'
                
                # Get problem names
                @{problem_names}    Get Dictionary Keys    ${topic}[submitted_code]
                
                # Iterate through problems
                FOR    ${problem_name}    IN    @{problem_names}
                    ${student_submission}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                    
                    # Check if problem exists in teacher's example code
                    ${teacher_example_keys}    Get Dictionary Keys    ${teacher_topic}[example_code]
                    Continue For Loop If    '${problem_name}' not in ${teacher_example_keys}
                    
                    # Get teacher's test input and expected output
                    ${teacher_example}    Get From Dictionary    ${teacher_topic}[example_code]    ${problem_name}
                    ${test_input}    Set Variable    ${teacher_example}[input]
                    ${expected_output}    Set Variable    ${teacher_example}[output]
                    
                    # Execute student's code with teacher's test input
                    ${student_status}    ${student_output}    Execute Code With Input    
                    ...    ${student_submission}[code]    
                    ...    ${student_submission}[language]    
                    ...    ${test_input}
                    
                    # Determine test result
                    ${test_status}    Set Variable If    
                    ...    '${student_status}' != 'success'    FAIL
                    ...    '${student_output}' != '${expected_output}'    FAIL
                    ...    PASS
                    
                    # Create result entry
                    ${result}    Create Dictionary
                    ...    student_name=${student_name}
                    ...    topic_name=${topic_name}
                    ...    problem_name=${problem_name}
                    ...    status=${test_status}
                    ...    student_output=${student_output}
                    ...    expected_output=${expected_output}
                    ...    language=${student_submission}[language]
                    
                    # Add result to results list
                    Append To List    ${results}    ${result}
                END
            END
        END
    END
    
    # Save results
    Save Comparison Results    ${results}