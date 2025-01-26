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

*** Keywords ***
Load JSON Data
    [Arguments]    ${file_path}
    ${data}    Load JSON From File    ${file_path}
    Run Keyword If    ${data} == None    Fail    Failed to load data from ${file_path}
    RETURN    ${data}

Compare Results
    [Arguments]    ${student_result}    ${teacher_result}
    ${student_result_list}    Evaluate    ast.literal_eval('''${student_result}''')    modules=ast
    ${teacher_result_list}    Evaluate    ast.literal_eval('''${teacher_result}''')    modules=ast
    ${status}    Set Variable If    ${student_result_list} == ${teacher_result_list}    PASS    FAIL
    RETURN    ${status}

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${details}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=${details}
    Append To List    ${results}    ${result}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student and Teacher Results
    # Load JSON files
    ${student_data}    Load JSON Data    ${STUDENT_FILE}
    ${teacher_data}    Load JSON Data    ${TEACHER_FILE}
    
    # Initialize results list
    @{results}    Create List

    IF    ${student_data} != None    
        ${comparison_status}    Compare Results    ${student_data}[testresult]    ${teacher_data}[testresult]
    ELSE
        ${comparison_status}    Set Variable    FAIL
    END

    
    # Add comparison result
    Add Comparison Result    ${results}    ${comparison_status}    ${student_data}[testresult] vs ${teacher_data}[testresult]
    
    # Save results
    Save Results    ${results}