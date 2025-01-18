*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String
Library           SeleniumLibrary
Library           BuiltIn
Library           DateTime

*** Variables ***
# File Paths
${STUDENT_FILE}    ${EXECDIR}/students.json
${TEACHER_FILE}    ${EXECDIR}/teacher.json
${TEMP_DIR}        ${EXECDIR}/temp
${RESULTS_FILE}    ${EXECDIR}/comparison_results.json
${SCREENSHOT_DIR}    ${EXECDIR}/screenshots

# Browser Configuration
${BROWSER}         ${EMPTY}
${BROWSER_OPTIONS}    ${EMPTY}
${URL}             http://localhost:5173
${HEADLESS}        ${FALSE}
${BROWSER_WIDTH}    1920
${BROWSER_HEIGHT}    1080
@{browser_type}   chrome    firefox    edge 
${TIMEOUT}         20s

# Compiler Commands
${PYTHON_CMD}      python
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc

# Browser specific options
&{CHROME_OPTIONS}    
...    args=["--start-maximized", "--disable-extensions", "--disable-popup-blocking", "--disable-infobars"]
...    excludeSwitches=["enable-automation"]
...    prefs={"profile.default_content_settings.popups": 0}

&{FIREFOX_OPTIONS}    
...    args=["-width=${BROWSER_WIDTH}", "-height=${BROWSER_HEIGHT}"]
...    prefs={"browser.download.folderList": 2}

&{EDGE_OPTIONS}    
...    args=["--start-maximized", "--disable-extensions"]
...    excludeSwitches=["enable-automation"]

# UI Elements
${LOADING_SPINNER}    id=loading-spinner
${ERROR_MESSAGE}    id=error-message
${SUCCESS_MESSAGE}    id=success-message

*** Keywords ***
Initialize Test Environment
    [Documentation]    Initialize the test environment including directories and logging
    Create Directory    ${TEMP_DIR}
    Create Directory    ${SCREENSHOT_DIR}
    Set Screenshot Directory    ${SCREENSHOT_DIR}
    Set Selenium Timeout    ${TIMEOUT}
    Set Selenium Speed    0.1s

Configure Browser Options
    [Documentation]
    [Arguments]    ${browser_type}    ${headless}=${HEADLESS}
    ${options}=    Set Variable If    
    ...    '${browser_type.lower()}' == 'chrome'    ${CHROME_OPTIONS}
    ...    '${browser_type.lower()}' == 'firefox'    ${FIREFOX_OPTIONS}
    ...    '${browser_type.lower()}' == 'edge'    ${EDGE_OPTIONS}
    ...    ${EMPTY}
    
    IF    ${headless} == ${TRUE}
        Run Keyword If    '${browser_type.lower()}' == 'chrome'
        ...    Set To Dictionary    ${options}    args    --headless
        Run Keyword If    '${browser_type.lower()}' == 'firefox'
        ...     Set To Dictionary    ${options}[args]    --headless
        Run Keyword If    '${browser_type.lower()}' == 'edge'
        ...     Set To Dictionary    ${options}[args]    --headless
    END
    
    Set Global Variable    ${BROWSER_OPTIONS}    ${options}

Open Code Testing Application
    [Arguments]    ${browser_type}=chrome    ${headless}=${HEADLESS}
    Configure Browser Options    ${browser_type}    ${headless}
    
    ${caps}=    Create Dictionary
    Run Keyword If    '${browser_type.lower()}' == 'chrome'
    ...    Create Webdriver    Chrome    chrome_options=${BROWSER_OPTIONS}
    ...    ELSE IF    '${browser_type.lower()}' == 'firefox'
    ...    Create Webdriver    Firefox    firefox_options=${BROWSER_OPTIONS}
    ...    ELSE IF    '${browser_type.lower()}' == 'edge'
    ...    Create Webdriver    Edge    edge_options=${BROWSER_OPTIONS}
    ...    ELSE
    ...    Fail    Unsupported browser type: ${browser_type}
    
    Set Window Size    ${BROWSER_WIDTH}    ${BROWSER_HEIGHT}
    Go To    ${URL}
    Wait Until Element Is Visible    id=code-testing-app    timeout=10s

Handle Browser Error
    [Arguments]    ${error_msg}
    Log    Browser Error: ${error_msg}    WARN
    Close Browser

Setup Test Environment
    [Documentation]    Setup the test environment and load necessary data
    Initialize Test Environment
    ${students}    Load JSON From File    ${STUDENT_FILE}
    ${teachers}    Load JSON From File    ${TEACHER_FILE}
    @{results}    Create List
    RETURN    ${students}    ${teachers}    ${results}

Cleanup Test Environment
    [Documentation]    Clean up the test environment
    Remove Directory    ${TEMP_DIR}    recursive=True
    Close All Browsers

Execute Code And Verify UI
    [Arguments]    ${code}    ${language}    ${expected_output}    ${student_name}    ${problem_name}
    Wait Until Element Is Visible    id=language-selector
    Click Element    id=language-selector
    Click Element    xpath=//option[text()='${language}']
    
    Wait Until Element Is Visible    id=code-editor-${problem_name}
    Execute JavaScript    ace.edit("code-editor-${problem_name}").setValue(arguments[0])    ARGUMENTS    ${code}
    
    Click Button    id=run-${problem_name}
    Wait Until Element Is Not Visible    ${LOADING_SPINNER}    timeout=10s
    Wait Until Element Is Visible    id=output-${problem_name}    timeout=10s
    
    ${ui_output}    Get Text    id=output-${problem_name}
    
    ${status}    ${backend_output}    Execute Code    ${code}    ${language}
    
    Run Keyword And Continue On Failure    Should Be Equal As Strings    ${ui_output.strip()}    ${backend_output.strip()}
    Run Keyword And Continue On Failure    Should Be Equal As Strings    ${backend_output.strip()}    ${expected_output.strip()}
    
    ${status_element}    Set Variable    id=status-${problem_name}
    ${status_class}    Get Element Attribute    ${status_element}    class
    Should Contain    ${status_class}    ${status}

Execute Code
    [Arguments]    ${code}    ${language}
    ${timestamp}    Get Time    epoch
    ${filename}    Set Variable    test_${timestamp}
    ${ext}    Set Variable If    
    ...    '${language}' == 'Python'    .py
    ...    '${language}' == 'C++'       .cpp
    ...    '${language}' == 'Rust'      .rs
    
    Create File    ${TEMP_DIR}/${filename}${ext}    ${code}
    
    ${status}    Set Variable    success
    ${output}    Set Variable    ${EMPTY}
    
    TRY
        IF    '${language}' == 'Python'
            ${result}    Run Process    ${PYTHON_CMD}    ${TEMP_DIR}/${filename}${ext}    shell=True    timeout=10s
            ${output}    Set Variable    ${result.stdout.strip()}
            
        ELSE IF    '${language}' == 'C++'
            ${compile_result}    Run Process    ${CPP_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    timeout=30s
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    shell=True    timeout=10s
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
            
        ELSE IF    '${language}' == 'Rust'
            ${compile_result}    Run Process    ${RUST_COMPILER}    ${TEMP_DIR}/${filename}${ext}    -o    ${TEMP_DIR}/${filename}    shell=True    timeout=30s
            IF    ${compile_result.rc} == 0
                ${result}    Run Process    ${TEMP_DIR}/${filename}    shell=True    timeout=10s
                ${output}    Set Variable    ${result.stdout.strip()}
            ELSE
                ${status}    Set Variable    compilation_error
                ${output}    Set Variable    ${compile_result.stderr}
            END
        END
    EXCEPT    AS    ${error}
        ${status}    Set Variable    runtime_error
        ${output}    Set Variable    ${error}
    FINALLY
        Remove File    ${TEMP_DIR}/${filename}${ext}
        Run Keyword If    '${language}' != 'Python'    Remove File    ${TEMP_DIR}/${filename}
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
    ${timestamp}    Get Time    epoch
    ${result}    Create Dictionary
    ...    student_name=${student_name}
    ...    topic_name=${topic_name}
    ...    problem_name=${problem_name}
    ...    status=${status}
    ...    details=${details}
    ...    language=${language}
    ...    timestamp=${timestamp}
    Append To List    ${results}    ${result}

Save Results
    [Arguments]    ${results}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}

Verify Problem UI Elements
    [Arguments]    ${problem_name}
    Wait Until Element Is Visible    id=code-editor-${problem_name}    timeout=10s
    Wait Until Element Is Visible    id=run-${problem_name}    timeout=10s
    Wait Until Element Is Visible    id=output-${problem_name}    timeout=10s
    Wait Until Element Is Visible    id=status-${problem_name}    timeout=10s
    Element Should Be Visible    id=code-editor-${problem_name}
    Element Should Be Visible    id=run-${problem_name}
    Element Should Be Visible    id=output-${problem_name}
    Element Should Be Visible    id=status-${problem_name}

Run Tests In Multiple Browsers
    [Arguments]    ${browsers}
    FOR    ${browser}    IN    @{browsers}
        Log    Starting tests in ${browser}
        TRY
            Run Keyword And Continue On Failure    Run Test Suite    ${browser}
        EXCEPT    AS    ${error}
            Handle Browser Error    ${error}
        END
    END

Run Test Suite
    [Arguments]    ${browser_type}
    Set Global Variable    ${BROWSER}    ${browser_type}
    Compare Student And Teacher Results With UI    ${browser_type}

Compare Student And Teacher Results With UI
    [Arguments]    ${browser_type}
    [Setup]    Run Keywords
    ...    Setup Test Environment
    ...    AND    Open Code Testing Application    ${browser_type}
    [Teardown]    Run Keywords
    ...    Cleanup Test Environment
    ...    AND    Close All Browsers
    ${browser_type}=    Set Variable    chrome
    
    ${students}    ${teachers}    ${results}    Setup Test Environment
    
    FOR    ${student}    IN    @{students}
        ${student_name}    Set Variable    ${student}[name]
        Log    Testing submissions for student: ${student_name}
        
        Wait Until Element Is Visible    id=student-selector
        Click Element    id=student-selector
        Click Element    xpath=//option[text()='${student_name}']
        
        ${first_topic}    Get From List    ${student}[enrolled_topics]    0
        ${first_submission}    Get From Dictionary    ${first_topic}[submitted_code]    hello_world
        ${student_language}    Set Variable    ${first_submission}[language]
        ${teacher}    Get Teacher For Language    ${teachers}    ${student_language}
        
        FOR    ${topic}    IN    @{student}[enrolled_topics]
            ${topic_name}    Set Variable    ${topic}[name]
            
            Wait Until Element Is Visible    id=topic-selector
            Click Element    id=topic-selector
            Click Element    xpath=//option[text()='${topic_name}']
            
            ${teacher_topic}    Set Variable    ${NONE}
            FOR    ${t_topic}    IN    @{teacher}[topics]
                IF    '${t_topic}[name]' == '${topic_name}'
                    ${teacher_topic}    Set Variable    ${t_topic}
                    BREAK
                END
            END
            
            FOR    ${problem_name}    IN    hello_world    sum_two_numbers    factorial
                Log    Testing problem: ${problem_name}
                
                Verify Problem UI Elements    ${problem_name}
                
                ${student_submission}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                ${teacher_example}    Get From Dictionary    ${teacher_topic}[example_code]    ${problem_name}
                
                TRY
                    Execute Code And Verify UI    
                    ...    ${student_submission}[code]    
                    ...    ${student_submission}[language]
                    ...    ${student_submission}[result]
                    ...    ${student_name}
                    ...    ${problem_name}
                    
                    Execute Code And Verify UI    
                    ...    ${teacher_example}[code]    
                    ...    ${teacher_example}[language]
                    ...    ${student_submission}[result]
                    ...    Teacher
                    ...    ${problem_name}
                    
                    ${student_output}    Get Text    id=output-${problem_name}
                    ${teacher_output}    Get Text    id=teacher-output-${problem_name}
                    
                    ${details}    Set Variable    Student output: "${student_output}"\nTeacher output: "${teacher_output}"
                    
                    IF    '${student_output}' == '${teacher_output}'
                        Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                        ...    PASS    ${details}    ${student_submission}[language]
                        Element Should Contain    id=status-${problem_name}    status-pass
                    ELSE
                        Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                        ...    FAIL    ${details}    ${student_submission}[language]
                        Element Should Contain    id=status-${problem_name}    status-fail
                    END
                EXCEPT    AS    ${error}
                    Log    Error in problem execution: ${error}    WARN
                    ${current_time}    Get Time    epoch
                    Capture Page Screenshot    problem-error-${problem_name}-${current_time}.png
                    Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                    ...    ERROR    Error during execution: ${error}    ${student_submission}[language]
                    Element Should Contain    id=status-${problem_name}    status-error
                END
            END
        END
    END
    
    Save Results    ${results}
    
    # Verify final UI state
    Wait Until Element Is Not Visible    ${LOADING_SPINNER}    timeout=10s
    Element Should Not Be Visible    ${ERROR_MESSAGE}
    Element Should Be Visible    ${SUCCESS_MESSAGE}

*** Test Cases ***
Run Tests Across Browsers
    [Documentation]    Run the test suite across multiple browsers
    @{browsers}=    Create List    chrome    firefox    edge
    Run Tests In Multiple Browsers    ${browsers}

Compare Student And Teacher Results With UI
    [Documentation]    Compare results between students and teachers
    [Setup]    Run Keywords
    ...    Setup Test Environment
    ...    AND    Open Code Testing Application    ${browser_type}
    [Teardown]    Run Keywords
    ...    Cleanup Test Environment
    ...    AND    Close All Browsers
    ${browser_type}=    Set Variable    chrome
    
    ${students}    ${teachers}    ${results}    Setup Test Environment
    
    FOR    ${student}    IN    @{students}
        ${student_name}    Set Variable    ${student}[name]
        Log    Testing submissions for student: ${student_name}
        
        Wait Until Element Is Visible    id=student-selector
        Click Element    id=student-selector
        Click Element    xpath=//option[text()='${student_name}']
        
        ${first_topic}    Get From List    ${student}[enrolled_topics]    0
        ${first_submission}    Get From Dictionary    ${first_topic}[submitted_code]    hello_world
        ${student_language}    Set Variable    ${first_submission}[language]
        ${teacher}    Get Teacher For Language    ${teachers}    ${student_language}
        
        FOR    ${topic}    IN    @{student}[enrolled_topics]
            ${topic_name}    Set Variable    ${topic}[name]
            
            Wait Until Element Is Visible    id=topic-selector
            Click Element    id=topic-selector
            Click Element    xpath=//option[text()='${topic_name}']
            
            ${teacher_topic}    Set Variable    ${NONE}
            FOR    ${t_topic}    IN    @{teacher}[topics]
                IF    '${t_topic}[name]' == '${topic_name}'
                    ${teacher_topic}    Set Variable    ${t_topic}
                    BREAK
                END
            END
            
            FOR    ${problem_name}    IN    hello_world    sum_two_numbers    factorial
                Log    Testing problem: ${problem_name}
                
                Verify Problem UI Elements    ${problem_name}
                
                ${student_submission}    Get From Dictionary    ${topic}[submitted_code]    ${problem_name}
                ${teacher_example}    Get From Dictionary    ${teacher_topic}[example_code]    ${problem_name}
                
                TRY
                    Execute Code And Verify UI    
                    ...    ${student_submission}[code]    
                    ...    ${student_submission}[language]
                    ...    ${student_submission}[result]
                    ...    ${student_name}
                    ...    ${problem_name}
                    
                    Execute Code And Verify UI    
                    ...    ${teacher_example}[code]    
                    ...    ${teacher_example}[language]
                    ...    ${student_submission}[result]
                    ...    Teacher
                    ...    ${problem_name}
                    
                    ${student_output}    Get Text    id=output-${problem_name}
                    ${teacher_output}    Get Text    id=teacher-output-${problem_name}
                    
                    ${details}    Set Variable    Student output: "${student_output}"\nTeacher output: "${teacher_output}"
                    
                    IF    '${student_output}' == '${teacher_output}'
                        Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                        ...    PASS    ${details}    ${student_submission}[language]
                        Element Should Contain    id=status-${problem_name}    status-pass
                    ELSE
                        Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                        ...    FAIL    ${details}    ${student_submission}[language]
                        Element Should Contain    id=status-${problem_name}    status-fail
                    END
                EXCEPT    AS    ${error}
                    Log    Error in problem execution: ${error}    WARN
                    ${current_time}    Get Time    epoch
                    Capture Page Screenshot    problem-error-${problem_name}-${current_time}.png
                    Add Comparison Result    ${results}    ${student_name}    ${topic_name}    ${problem_name}
                    ...    ERROR    Error during execution: ${error}    ${student_submission}[language]
                    Element Should Contain    id=status-${problem_name}    status-error
                END
            END
        END
    END
    
    Save Results    ${results}
    
    # Verify final UI state
    Wait Until Element Is Not Visible    ${LOADING_SPINNER}    timeout=10s
    Element Should Not Be Visible    ${ERROR_MESSAGE}
    Element Should Be Visible    ${SUCCESS_MESSAGE}

Verify Results File Structure
    [Documentation]    Verify that the results file has been created with correct structure
    [Setup]    Initialize Test Environment
    
    File Should Exist    ${RESULTS_FILE}
    ${results}    Load JSON From File    ${RESULTS_FILE}
    
    FOR    ${result}    IN    @{results}
        Dictionary Should Contain Key    ${result}    student_name
        Dictionary Should Contain Key    ${result}    topic_name
        Dictionary Should Contain Key    ${result}    problem_name
        Dictionary Should Contain Key    ${result}    status
        Dictionary Should Contain Key    ${result}    details
        Dictionary Should Contain Key    ${result}    language
        Dictionary Should Contain Key    ${result}    timestamp

        
        Should Be String    ${result}[student_name]
        Should Be String    ${result}[topic_name]
        Should Be String    ${result}[problem_name]
        Should Be String    ${result}[status]
        Should Be String    ${result}[details]
        Should Be String    ${result}[language]
        Should Match Regexp    ${result}[timestamp]    ^\\d$
    END