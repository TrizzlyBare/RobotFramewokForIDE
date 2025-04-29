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
${TEACHERS_JSON}   ${CURDIR}/teacher.json
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
    
    # Log whether the code matches instead of failing the test
    IF    ${overall_match}
        Log    All code parts match teacher reference.    INFO
    ELSE
        Log    Defaultcode does not match teacher reference. See JSON report for details.    WARN
    END
    
    # Always pass this test
    Pass Execution    Test completed with detailed results saved to JSON

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
    
    # Always pass this test
    Pass Execution    Test completed with detailed results saved to JSON

*** Keywords ***
Setup Test Environment
    Create Directory    ${OUTPUT_DIR}
    # Clear any existing result files to avoid confusion
    Remove Files    ${OUTPUT_DIR}/*.json
    
    # Ensure temp directory exists
    ${temp_dir}=    Join Path    ${CURDIR}    temp
    Create Directory    ${temp_dir}

Analyze JS Specific Differences
    [Arguments]    ${student_js}    ${teacher_js}
    # Run Python analyzer to get specific JS differences
    ${temp_student_js}=    Set Variable    ${CURDIR}/temp/student_js_analysis.js
    ${temp_teacher_js}=    Set Variable    ${CURDIR}/temp/teacher_js_analysis.js
    Create File    ${temp_student_js}    ${student_js}
    Create File    ${temp_teacher_js}    ${teacher_js}
    
    ${result}=    Run Process    python    ${HELPER_SCRIPT}    analyze_js    ${temp_student_js}    ${temp_teacher_js}
    Should Be Equal As Integers    ${result.rc}    0    Failed to analyze JS differences
    
    # Parse the output to get specific differences
    ${lines}=    Split To Lines    ${result.stdout}
    @{specific_differences}=    Create List
    FOR    ${line}    IN    @{lines}
        ${stripped}=    Strip String    ${line}
        IF    "${stripped}" != "${EMPTY}"
            Append To List    ${specific_differences}    ${stripped}
        END
    END
    
    # Clean up temp files
    Remove File    ${temp_student_js}
    Remove File    ${temp_teacher_js}
    
    RETURN    ${specific_differences}

Combine Lists
    [Arguments]    ${list1}    ${list2}
    ${combined}=    Create List
    FOR    ${item}    IN    @{list1}
        Append To List    ${combined}    ${item}
    END
    FOR    ${item}    IN    @{list2}
        Append To List    ${combined}    ${item}
    END
    RETURN    ${combined}

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
    
    # Clean up temporary directory after tests are complete
    ${temp_dir}=    Join Path    ${CURDIR}    temp
    ${dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${temp_dir}
    
    IF    ${dir_exists}
        Log    Cleaning up temporary directory: ${temp_dir}
        Remove Directory    ${temp_dir}    recursive=True
    ELSE
        Log    Temporary directory doesn't exist: ${temp_dir}
    END

Extract JSON Files
    [Arguments]    ${file_path}
    # Use external Python process to extract JSON into separate files
    Log    Extracting JSON from ${file_path}...
    ${result}=    Run Process    python    ${HELPER_SCRIPT}    extract    ${file_path}    stderr=STDOUT
    Log    Process output: ${result.stdout}
    
    # Check return code
    ${rc}=    Set Variable    ${result.rc}
    Log    Process return code: ${rc}
    
    Run Keyword If    ${rc} != 0    Log    Error extracting data: ${result.stdout}    WARN
    Should Be Equal As Integers    ${rc}    0    Failed to extract data from ${file_path}: ${result.stdout}
    
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
            
            # Also run the helper script for additional HTML analysis (especially order)
            ${html_order_result}=    Run Process    python    ${HELPER_SCRIPT}    analyze_html    ${student_file}    ${teacher_file}
            ${html_order_diff}=    Create List
            # Fix: Use proper variable syntax and string comparison for Robot Framework
            ${stdout_empty}=    Evaluate    $html_order_result.stdout == ""
            IF    $html_order_result.rc == 0 and not $stdout_empty
                ${html_order_lines}=    Split To Lines    ${html_order_result.stdout}
                FOR    ${line}    IN    @{html_order_lines}
                    ${stripped}=    Strip String    ${line}
                    ${is_empty}=    Evaluate    "${stripped}" == ""
                    IF    not ${is_empty}
                        Append To List    ${html_order_diff}    ${stripped}
                    END
                END
                # Only combine if we actually found differences
                ${diff_len}=    Get Length    ${html_order_diff}
                IF    ${diff_len} > 0
                    ${diff_result}=    Combine Lists    ${diff_result}    ${html_order_diff}
                END
            END
            
        ELSE IF    "${code_type}" == "css"
            ${diff_result}=    Compare Css Rules    ${student_code}    ${teacher_code}
            
            # Also run the helper script for additional CSS analysis (especially order)
            ${css_order_result}=    Run Process    python    ${HELPER_SCRIPT}    analyze_css    ${student_file}    ${teacher_file}
            ${css_order_diff}=    Create List
            # Fix: Use proper variable syntax and string comparison for Robot Framework
            ${stdout_empty}=    Evaluate    $css_order_result.stdout == ""
            IF    $css_order_result.rc == 0 and not $stdout_empty
                ${css_order_lines}=    Split To Lines    ${css_order_result.stdout}
                FOR    ${line}    IN    @{css_order_lines}
                    ${stripped}=    Strip String    ${line}
                    ${is_empty}=    Evaluate    "${stripped}" == ""
                    IF    not ${is_empty}
                        Append To List    ${css_order_diff}    ${stripped}
                    END
                END
                # Only combine if we actually found differences
                ${diff_len}=    Get Length    ${css_order_diff}
                IF    ${diff_len} > 0
                    ${diff_result}=    Combine Lists    ${diff_result}    ${css_order_diff}
                END
            END
            
        ELSE IF    "${code_type}" == "js"
            ${diff_result}=    Compare Js Functionality    ${student_code}    ${teacher_code}
            
            # Add enhanced JS analysis for more specific differences
            ${js_specific_analysis}=    Analyze JS Specific Differences    ${student_code}    ${teacher_code}
            Log    Detailed JavaScript Analysis:    WARN
            Log Many    @{js_specific_analysis}    WARN
            
            # Add the specific analysis to the diff result
            ${js_diff_len}=    Get Length    ${js_specific_analysis}
            IF    ${js_diff_len} > 0
                ${diff_result}=    Combine Lists    ${diff_result}    ${js_specific_analysis}
            END
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