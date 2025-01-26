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
    @{results}    Create List
    RETURN    ${students}    ${teachers}    ${results}

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

*** Keywords ***
Execute Code
    [Arguments]    ${code}    ${language}
    ${filename}    Set Variable    test
    ${ext}         Get Language Extension    ${language}
    Create Directory    ${TEMP_DIR}
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'Python'
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF   '${language}' == 'JavaScript'
            ${result}    Run Process    ${JAVASCRIPT_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True
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
Compare Results
    [Arguments]    ${student_result}    ${teacher_result}
    # ${cleaned_student}    Evaluate    '${student_result}'.replace('[', '').replace(']', '').replace('\\n', ' ').strip()
    # ${cleaned_teacher}    Evaluate    '${teacher_result}'.replace('[', '').replace(']', '').replace('\\n', ' ').strip()
    
    # ${match}    Evaluate    '${cleaned_student}' == '${cleaned_teacher}'
    ${match}    Evaluate    '${student_result}' == '${teacher_result}'
    RETURN    ${match}


Add Comparison Result
    [Arguments]    ${status}    ${details}
    @{results}    Create List
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=${details}
    Append To List    ${results}    ${result}
    RETURN    ${results}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student and Teacher Results
    [Documentation]    Compare Compiled student code outputs with teacher's compiled teacher code outputs
    [Setup]    Setup Test Environment
    [Teardown]    Cleanup Test Environment

    # Load student and teacher files
    ${students}    Load JSON From File    ${STUDENT_FILE}
    ${teachers}    Load JSON From File    ${TEACHER_FILE}

    ${student_Language}    Get Language Extension   ${students}[language]
    ${teacher_Language}    Get Language Extension   ${teachers}[language]
    ${student_code}    Set Variable    ${students}[defaultCode]
    ${teacher_code}    Set Variable    ${teachers}[defaultCode]

    # Compare student results with teacher results, Don't use the same variable names as in the snippet
    ${student_result}   Execute Code    ${student_code}    ${student_Language}
    ${teacher_result}   Execute Code    ${teacher_code}    ${teacher_Language}

    ${match}    Compare Results    ${student_result}    ${teacher_result}
    ${status}    Set Variable If    ${match}    PASS    FAIL
    
    # Add comparison result
    ${details}    Set Variable    ${STUDENT_FILE}[name] vs ${TEACHER_FILE}[name]
    ${results}    Add Comparison Result    ${status}    ${details}

    # Save results
    Save Results    ${results}

    
    
    


