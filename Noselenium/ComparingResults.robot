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
Find Teacher With Matching Language
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

Get Teacher Problem Output
    [Arguments]    ${teacher}    ${topic_name}    ${problem_name}
    FOR    ${topic}    IN    @{teacher}[topics]
        IF    '${topic}[name]' == '${topic_name}'
            RETURN    ${topic}[example_code][${problem_name}][output]
        END
    END
    Fail    msg=No matching topic found for ${topic_name}

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
Compare Student and Teacher Result Case 3
    [Documentation]    Compare results from students.json and teacher.json
    
    # Load student and teacher files
    ${students}    Load JSON From File    ${STUDENT_FILE}
    ${teachers}    Load JSON From File    ${TEACHER_FILE}
    
    # Initialize results list
    @{results}    Create List
    
    # Compare student results with teacher results
    FOR    ${student}    IN    @{students}
        ${student_name}    Set Variable    ${student}[name]
        
        FOR    ${topic}    IN    @{student}[topics]
            ${topic_name}    Set Variable    ${topic}[name]
            
            # Dynamically get problem names from submitted_code
            @{problem_names}    Get Dictionary Keys    ${topic}[submitted_code]
            
            FOR    ${problem_name}    IN    @{problem_names}
                ${student_code}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                
                # Find matching teacher
                ${teacher_match}    Find Teacher With Matching Language    ${teachers}    ${student_code}[language]
                
                # Attempt to get teacher output, skip if not found
                ${teacher_output_status}    Run Keyword And Return Status    
                ...    Get Teacher Problem Output    ${teacher_match}    ${topic_name}    ${problem_name}
                Continue For Loop If    not ${teacher_output_status}
                
                # Get teacher's expected output for this problem
                ${teacher_output}    Get Teacher Problem Output    ${teacher_match}    ${topic_name}    ${problem_name}
                
                # Compare student result with teacher output
                ${status}    Set Variable If    
                ...    '${student_code}[result]' == '${teacher_output}'    PASS    FAIL
                
                # Add comparison result
                Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                ...    ${status}    ${student_code}[result]    ${student_code}[language]
            END
        END
    END
    
    # Save comparison results
    Save Results    ${results}