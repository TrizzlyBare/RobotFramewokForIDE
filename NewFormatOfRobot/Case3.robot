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

Normalize String
    [Arguments]    ${input_string}
    ${normalized}    Replace String    ${input_string}    \r\n    ${SPACE}
    ${normalized}    Replace String    ${normalized}    \n    ${SPACE}
    ${normalized}    Replace String    ${normalized}    \r    ${SPACE}
    RETURN    ${normalized}

Compare Single Result
    [Arguments]    ${student_result}    ${teacher_result}
    ${student_normalized}    Normalize String    ${student_result}
    ${teacher_normalized}    Normalize String    ${teacher_result}
    ${status}    Run Keyword And Return Status
    ...    Should Be Equal As Strings    ${student_normalized}    ${teacher_normalized}
    ${result}    Set Variable If    ${status}    PASS    FAIL
    RETURN    ${result}

Compare Multiple Results
    [Arguments]    ${student_results}    ${teacher_results}
    @{comparison_results}    Create List
    ${student_length}    Get Length    ${student_results}
    ${teacher_length}    Get Length    ${teacher_results}
    
    Run Keyword If    ${student_length} != ${teacher_length}
    ...    Append To List    ${comparison_results}    FAIL
    ...    ELSE    Compare Result Lists    ${student_results}    ${teacher_results}    ${comparison_results}
    
    RETURN    @{comparison_results}

Compare Result Lists
    [Arguments]    ${student_results}    ${teacher_results}    ${comparison_results}
    FOR    ${index}    IN RANGE    0    len(${student_results})
        ${status}    Compare Single Result    ${student_results}[${index}]    ${teacher_results}[${index}]
        Append To List    ${comparison_results}    ${status}
    END

Add Comparison Result
    [Arguments]    ${results}    ${status}    ${student_value}    ${teacher_value}    ${index}=${None}
    ${student_normalized}    Normalize String    ${student_value}
    ${teacher_normalized}    Normalize String    ${teacher_value}
    ${result}    Create Dictionary
    ...    status=${status}
    ...    details=Result ${index}: Student=${student_normalized} vs Teacher=${teacher_normalized}
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
    
    # Handle both single and multiple results
    ${student_results}    Set Variable    ${student_data}[testresult]
    ${teacher_results}    Set Variable    ${teacher_data}[testresult]
    
    # Check if the results are lists
    ${is_list}    Evaluate    isinstance($student_results, list)
    
    IF    ${is_list}
        @{comparison_statuses}    Compare Multiple Results    ${student_results}    ${teacher_results}
        FOR    ${index}    ${status}    IN ENUMERATE    @{comparison_statuses}
            Add Comparison Result    
            ...    ${results}    
            ...    ${status}    
            ...    ${student_results}[${index}]    
            ...    ${teacher_results}[${index}]    
            ...    ${index + 1}
        END
    ELSE
        ${comparison_status}    Compare Single Result    ${student_results}    ${teacher_results}
        Add Comparison Result    
        ...    ${results}    
        ...    ${comparison_status}    
        ...    ${student_results}    
        ...    ${teacher_results}
    END
    
    # Save results
    Save Results    ${results}