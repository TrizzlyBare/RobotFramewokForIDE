*** Settings ***
Documentation     Enhanced test suite for validating web development code
...               Provides specific, detailed feedback on differences

Library           ${CURDIR}/WebCourseLibrary.py
Library           OperatingSystem
Library           Collections
Library           JSONLibrary
Library           DateTime
Library           String
Library           Process
Suite Setup       Setup Test Environment
Suite Teardown    Teardown Test Environment

*** Variables ***
${STUDENTS_JSON}   ${CURDIR}/students.json
${TEACHERS_JSON}   ${CURDIR}/teachers.json
${OUTPUT_DIR}      ${CURDIR}/test_results
${REPORT_FILE}     ${OUTPUT_DIR}/validation_report.json
${HELPER_SCRIPT}    ${CURDIR}/json_helper.py


*** Test Cases ***
Test Default Code Consistency With Specific Feedback
    [Documentation]    Test defaultcode consistency with enhanced specific feedback
    
    # Extract JSON contents to files
    ${student_paths}=    Extract JSON Files    ${STUDENTS_JSON}
    ${teacher_paths}=    Extract JSON Files    ${TEACHERS_JSON}
    
    # Read the files directly
    ${student_html}=    Get File    ${student_paths["html_path"]}
    ${student_css}=     Get File    ${student_paths["css_path"]}
    ${student_js}=      Get File    ${student_paths["js_path"]}
    
    ${teacher_html}=    Get File    ${teacher_paths["html_path"]}
    ${teacher_css}=     Get File    ${teacher_paths["css_path"]}
    ${teacher_js}=      Get File    ${teacher_paths["js_path"]}
    
    # Compare HTML with specific feedback on differences
    ${html_match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_html}    ${teacher_html}
    
    # Initialize empty lists for differences
    @{html_differences}=    Create List
    @{css_differences}=     Create List
    @{js_differences}=      Create List
    
    # Get differences if content doesn't match
    IF    not ${html_match}
        ${html_diff_result}=    Compare Html Structure    ${student_html}    ${teacher_html}
        @{html_differences}=    Set Variable    ${html_diff_result}
        Log    HTML differences found:    WARN
        Log Many    @{html_differences}    WARN
    END
    
    # Compare CSS with specific feedback on differences
    ${css_match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_css}    ${teacher_css}
    
    IF    not ${css_match}
        ${css_diff_result}=    Compare Css Rules    ${student_css}    ${teacher_css}
        @{css_differences}=    Set Variable    ${css_diff_result}
        Log    CSS differences found:    WARN
        Log Many    @{css_differences}    WARN
    END
    
    # Compare JS with specific feedback on differences
    ${js_match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_js}    ${teacher_js}
    
    IF    not ${js_match}
        ${js_diff_result}=    Compare Js Functionality    ${student_js}    ${teacher_js}
        @{js_differences}=    Set Variable    ${js_diff_result}
        Log    JavaScript differences found:    WARN
        Log Many    @{js_differences}    WARN
    END
    
    # Create detailed result object
    ${timestamp}=    Get Current Date    result_format=epoch
    ${result_obj}=    Create Dictionary
    ...    timestamp=${timestamp}
    ...    html_match=${html_match}
    ...    css_match=${css_match}
    ...    js_match=${js_match}
    ...    html_differences=${html_differences}
    ...    css_differences=${css_differences}
    ...    js_differences=${js_differences}
    
    # Save detailed report
    ${result_json}=    Evaluate    json.dumps(${result_obj}, indent=2)    modules=json
    ${filename}=    Set Variable    ${OUTPUT_DIR}/defaultcode_comparison_result.json
    Create File    ${filename}    ${result_json}
    
    # Calculate overall match
    ${overall_match}=    Evaluate    ${html_match} and ${css_match} and ${js_match}
    
    # Pass or fail the test based on match
    Should Be True    ${overall_match}    Defaultcode does not match teacher reference

Test Student Submission Against Teacher Reference
    [Documentation]    Test defaultcode in student JSON against teacher reference
    
    # Create output directory if it doesn't exist
    Create Directory    ${OUTPUT_DIR}
    
    # Extract JSON contents to files
    ${student_paths}=    Extract JSON Files    ${STUDENTS_JSON}
    ${teacher_paths}=    Extract JSON Files    ${TEACHERS_JSON}
    
    # Compare HTML files
    ${html_result}=    Compare Code Files    
    ...    ${student_paths["html_path"]}    
    ...    ${teacher_paths["html_path"]}
    ...    html
    
    # Compare CSS files
    ${css_result}=    Compare Code Files    
    ...    ${student_paths["css_path"]}    
    ...    ${teacher_paths["css_path"]}
    ...    css
    
    # Compare JS files
    ${js_result}=    Compare Code Files    
    ...    ${student_paths["js_path"]}    
    ...    ${teacher_paths["js_path"]}
    ...    js
    
    # Calculate overall match
    ${overall_match}=    Evaluate    ${html_result["match"]} and ${css_result["match"]} and ${js_result["match"]}
    ${overall_match_bool}=    Convert To Boolean    ${overall_match}
    
    # Create the validation report
    ${validation_data}=    Create Dictionary
    ...    html_match=${html_result["match"]}
    ...    css_match=${css_result["match"]}
    ...    js_match=${js_result["match"]}
    ...    overall_match=${overall_match_bool}
    ...    html_differences=${html_result["differences"]}
    ...    css_differences=${css_result["differences"]}
    ...    js_differences=${js_result["differences"]}
    
    # Save the validation report
    ${report_file}=    Set Variable    ${OUTPUT_DIR}/student_validation.json
    ${report_json}=    Evaluate    json.dumps(${validation_data}, indent=2)    modules=json
    Create File    ${report_file}    ${report_json}
    
    # Log the overall result
    IF    ${overall_match_bool}
        Log    All code parts match! Student submission is correct.    INFO
    ELSE
        Log    Student submission has differences. Check the detailed report.    WARN
    END
    
    # Fail the test if submission doesn't match
    Should Be True    ${overall_match_bool}    Student submission does not match the teacher reference

*** Keywords ***
Setup Test Environment
    Create Directory    ${OUTPUT_DIR}
    # Clear any existing result files to avoid confusion
    Remove Files    ${OUTPUT_DIR}/*.json

Teardown Test Environment
    # Combine all results into a single report file
    ${files}=    List Files In Directory    ${OUTPUT_DIR}    *.json
    ${all_results}=    Create List
    
    FOR    ${file}    IN    @{files}
        # Skip the validation report itself if it exists
        Continue For Loop If    '${file}' == 'validation_report.json'
        ${file_path}=    Join Path    ${OUTPUT_DIR}    ${file}
        
        # Use a more robust way to read and parse JSON files
        TRY
            ${json_content}=    Get File    ${file_path}
            # Use evaluation instead of JSONLibrary for more robustness
            ${json_obj}=    Evaluate    json.loads('''${json_content}''')    modules=json
            Append To List    ${all_results}    ${json_obj}
        EXCEPT
            Log    Error parsing JSON file: ${file_path}    level=WARN
        END
    END
    
    ${final_report}=    Create Dictionary    results=${all_results}
    ${final_json}=    Evaluate    json.dumps(${final_report}, indent=2)    modules=json
    Create File    ${REPORT_FILE}    ${final_json}
    
    # Clean up temporary directories
    ${temp_dir}=    Join Path    ${CURDIR}    temp
    ${dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${temp_dir}
    Run Keyword If    ${dir_exists}    Remove Directory    ${temp_dir}    recursive=True
    Log    Temporary directory status: ${dir_exists}

Extract JSON Files
    [Arguments]    ${file_path}
    # Use external Python process to extract JSON into separate files
    ${result}=    Run Process    python    ${HELPER_SCRIPT}    extract    ${file_path}
    Should Be Equal As Integers    ${result.rc}    0    Failed to extract data from ${file_path}
    
    # Parse the output to get file paths
    ${lines}=    Split To Lines    ${result.stdout}
    ${html_path}=    Set Variable    ${EMPTY}
    ${css_path}=     Set Variable    ${EMPTY}
    ${js_path}=      Set Variable    ${EMPTY}
    
    FOR    ${line}    IN    @{lines}
        ${stripped}=    Strip String    ${line}
        IF    "${stripped}" != "${EMPTY}"
            IF    $stripped.startswith("HTML_PATH:")
                ${html_path}=    Set Variable    ${stripped.replace("HTML_PATH:", "")}
            ELSE IF    $stripped.startswith("CSS_PATH:")
                ${css_path}=     Set Variable    ${stripped.replace("CSS_PATH:", "")}
            ELSE IF    $stripped.startswith("JS_PATH:")
                ${js_path}=      Set Variable    ${stripped.replace("JS_PATH:", "")}
            END
        END
    END
    
    # Create a dictionary with paths
    ${paths}=    Create Dictionary    
    ...    html_path=${html_path}    
    ...    css_path=${css_path}    
    ...    js_path=${js_path}
    
    RETURN    ${paths}

Compare Code Files
    [Arguments]    ${student_file}    ${teacher_file}    ${code_type}
    # Read the files
    ${student_code}=    Get File    ${student_file}
    ${teacher_code}=    Get File    ${teacher_file}
    
    # Compare codes
    ${match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_code}    ${teacher_code}
    
    # If they don't match, get the differences
    @{differences}=    Create List
    
    IF    not ${match}
        IF    "${code_type}" == "html"
            ${diff_result}=    Compare Html Structure    ${student_code}    ${teacher_code}
        ELSE IF    "${code_type}" == "css"
            ${diff_result}=    Compare Css Rules    ${student_code}    ${teacher_code}
        ELSE IF    "${code_type}" == "js"
            ${diff_result}=    Compare Js Functionality    ${student_code}    ${teacher_code}
        END
        
        @{differences}=    Set Variable    ${diff_result}
        Log    ${code_type} differences found:    WARN
        Log Many    @{differences}    WARN
    END
    
    # Return results
    ${result}=    Create Dictionary
    ...    match=${match}
    ...    differences=${differences}
    
    RETURN    ${result}