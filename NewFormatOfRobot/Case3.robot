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

Split String Into Characters
    [Arguments]    ${input_string}
    ${normalized}    Replace String    ${input_string}    \r\n    ${SPACE}
    ${normalized}    Replace String    ${normalized}    \n    ${SPACE}
    ${normalized}    Replace String    ${normalized}    \r    ${SPACE}
    ${chars}    Split String    ${normalized}    ${SPACE}
    RETURN    ${chars}

Compare Characters
    [Arguments]    ${student_chars}    ${teacher_chars}
    ${results_dict}    Create Dictionary
    ${student_length}    Get Length    ${student_chars}
    ${teacher_length}    Get Length    ${teacher_chars}
    
    Run Keyword If    ${student_length} != ${teacher_length}
    ...    Fail    Length mismatch: Student chars (${student_length}) ≠ Teacher chars (${teacher_length})
    
    FOR    ${index}    IN RANGE    0    ${student_length}
        ${case_key}    Set Variable    Case${index + 1}
        ${student_char}    Set Variable    ${student_chars}[${index}]
        ${teacher_char}    Set Variable    ${teacher_chars}[${index}]
        
        ${status}    Run Keyword And Return Status
        ...    Should Be Equal As Strings    ${student_char}    ${teacher_char}
        ${status_str}    Set Variable If    ${status}    PASS    FAIL
        
        ${case_dict}    Create Dictionary
        ...    status=${status_str}
        ...    detail=Student=${student_char} vs Teacher=${teacher_char}
        Set To Dictionary    ${results_dict}    ${case_key}=${case_dict}
    END
    
    RETURN    ${results_dict}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

*** Test Cases ***
Compare Student and Teacher Results
    # Load JSON files
    ${student_data}    Load JSON Data    ${STUDENT_FILE}
    ${teacher_data}    Load JSON Data    ${TEACHER_FILE}
    
    # Get test results
    ${student_result}    Set Variable    ${student_data}[testresult]
    ${teacher_result}    Set Variable    ${teacher_data}[testresult]
    
    # Split into individual characters
    ${student_chars}    Split String Into Characters    ${student_result}
    ${teacher_chars}    Split String Into Characters    ${teacher_result}
    
    # Compare characters and generate results
    ${results}    Compare Characters    ${student_chars}    ${teacher_chars}
    
    # Save results
    Save Results    ${results}