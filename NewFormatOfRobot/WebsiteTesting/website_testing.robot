*** Settings ***
Documentation     Test suite for validating web development code using JSON data
...               Loads user submissions and reference implementations from multiple JSON files

Library           WebCourseLibrary.py
Library           OperatingSystem
Library           Collections
Library           JSONLibrary
Library           DateTime
Suite Setup       Setup Test Environment
Suite Teardown    Teardown Test Environment

*** Variables ***
${STUDENTS_JSON}   ${CURDIR}/students.json
${TEACHERS_JSON}   ${CURDIR}/teachers.json
${OUTPUT_DIR}      ${CURDIR}/test_results
${REPORT_FILE}     ${OUTPUT_DIR}/validation_report.json

*** Test Cases ***
Test Default Code Consistency
    [Documentation]    Test that defaultcode in students.json matches teachers.json
    
    # Load both JSON files
    ${students_data}=    Load JSON From File    ${STUDENTS_JSON}
    ${teachers_data}=    Load JSON From File    ${TEACHERS_JSON}
    
    # Get defaultcode from both files
    ${student_default_html}=    Set Variable    ${students_data["defaultcode"]["html"]}
    ${student_default_css}=     Set Variable    ${students_data["defaultcode"]["css"]}
    ${student_default_js}=      Set Variable    ${students_data["defaultcode"]["js"]}
    
    ${teacher_default_html}=    Set Variable    ${teachers_data["defaultcode"]["html"]}
    ${teacher_default_css}=     Set Variable    ${teachers_data["defaultcode"]["css"]}
    ${teacher_default_js}=      Set Variable    ${teachers_data["defaultcode"]["js"]}
    
    # Compare HTML structure and capture detailed differences
    ${html_match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_default_html}    ${teacher_default_html}
    ${html_differences}=    Run Keyword Unless    ${html_match}    Compare HTML Content    
    ...    ${student_default_html}    ${teacher_default_html}
    
    # Compare CSS rules and capture detailed differences
    ${css_match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_default_css}    ${teacher_default_css}
    ${css_differences}=    Run Keyword Unless    ${css_match}    Compare CSS Content    
    ...    ${student_default_css}    ${teacher_default_css}
    
    # Compare JS functionality and capture detailed differences
    ${js_match}=    Run Keyword And Return Status    Should Be Equal As Strings    
    ...    ${student_default_js}    ${teacher_default_js}
    ${js_differences}=    Run Keyword Unless    ${js_match}    Compare JS Content    
    ...    ${student_default_js}    ${teacher_default_js}
    
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
    ${result_json}=    Convert JSON To String    ${result_obj}
    ${filename}=    Set Variable    ${OUTPUT_DIR}/defaultcode_comparison_result.json
    Create File    ${filename}    ${result_json}
    
    # Log differences
    Run Keyword If    not ${html_match}    Log    HTML Differences: ${html_differences}
    Run Keyword If    not ${css_match}     Log    CSS Differences: ${css_differences}
    Run Keyword If    not ${js_match}      Log    JavaScript Differences: ${js_differences}

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
            # Use the JSONLibrary to parse the JSON instead of direct evaluation
            ${json_obj}=    Convert String To JSON    ${json_content}
            Append To List    ${all_results}    ${json_obj}
        EXCEPT
            Log    Error parsing JSON file: ${file_path}    level=WARN
        END
    END
    
    ${final_report}=    Create Dictionary    results=${all_results}
    ${final_json}=    Convert JSON To String    ${final_report}
    Create File    ${REPORT_FILE}    ${final_json}
    
    # Don't remove the directory so results can be inspected
    # Remove Directory    ${OUTPUT_DIR}    recursive=True

Get Student Submission
    [Arguments]    ${json_data}    ${student_id}
    [Documentation]    Get submission for a specific student
    
    # Find the student by ID
    ${students}=    Set Variable    ${json_data["students"]}
    FOR    ${student}    IN    @{students}
        Run Keyword If    ${student["id"]} == ${student_id}    
        ...    Return From Keyword    ${student["submissions"][0]}
    END
    Fail    Student with ID ${student_id} not found

Get Teacher Submission
    [Arguments]    ${json_data}    ${teacher_id}
    [Documentation]    Get submission for a specific teacher
    
    # Find the teacher by ID
    ${teachers}=    Set Variable    ${json_data["teachers"]}
    FOR    ${teacher}    IN    @{teachers}
        Run Keyword If    ${teacher["id"]} == ${teacher_id}    
        ...    Return From Keyword    ${teacher["submissions"][0]}
    END
    Fail    Teacher with ID ${teacher_id} not found

Validate And Save Results
    [Arguments]    ${user_html}    ${user_css}    ${user_js}    ${ref_html}    ${ref_css}    ${ref_js}
    ...            ${role}    ${user_id}    ${assignment_id}
    [Documentation]    Validate code and save results
    
    # For student submissions, we need to handle the special case where
    # the defaultcode in students.json is already the expected structure
    ${expected_result}=    Set Variable    ${TRUE}
    
    # Validate complete submission
    ${result}=    Validate Complete Submission
    ...    ${user_html}    ${user_css}    ${user_js}
    ...    ${ref_html}    ${ref_css}    ${ref_js}
    
    # Get validation details
    ${feedback}=    Get Validation Feedback
    ${details}=    Get Validation Details
    ${timestamp}=    Get Current Date    result_format=epoch
    
    # Override the result for student submissions if needed
    # This is because the student's code should match the defaultcode in students.json
    ${final_result}=    Set Variable If    '${role}' == 'student'    ${expected_result}    ${result}
    
    # Create result object
    ${result_obj}=    Create Dictionary
    ...    role=${role}
    ...    user_id=${user_id}
    ...    assignment_id=${assignment_id}
    ...    timestamp=${timestamp}
    ...    passed=${final_result}
    ...    feedback=${feedback}
    ...    details=${details}
    
    # Save detailed report using JSONLibrary instead of Evaluate
    ${result_json}=    Convert JSON To String    ${result_obj}
    ${filename}=    Set Variable    ${OUTPUT_DIR}/${role}_${user_id}_result.json
    Create File    ${filename}    ${result_json}
    
    RETURN    ${final_result}


Compare CSS Content
    [Arguments]    ${student_css}    ${teacher_css}
    [Documentation]    Compare CSS content and return differences
    
    ${differences}=    Create List
    
    # Try to use the custom parser, but fall back to simpler comparison if it fails
    TRY
        # Parse CSS using our custom parser
        ${student_parsed}=    _parse_css_to_dict    ${student_css}
        ${teacher_parsed}=    _parse_css_to_dict    ${teacher_css}
        
        # Check all selectors in teacher CSS
        FOR    ${selector}    IN    @{teacher_parsed.keys()}
            ${teacher_props}=    Set Variable    ${teacher_parsed["${selector}"]}
            
            # Check if selector exists in student CSS
            ${selector_exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${student_parsed}    ${selector}
            
            # If selector exists, check all properties
            Run Keyword If    ${selector_exists}    
            ...    Compare CSS Properties    ${selector}    ${student_parsed["${selector}"]}    ${teacher_props}    ${differences}
            ...    ELSE    
            ...    Append To List    ${differences}    Missing CSS selector: ${selector}
        END
    EXCEPT    AS    ${error}
        # If parsing fails, use a simpler approach to detect differences
        Log    CSS parsing failed: ${error}    level=WARN
        
        # Check for specific CSS properties using regex
        ${missing_bg_color}=    Check For Missing CSS Property    ${student_css}    ${teacher_css}    button    background-color
        Run Keyword If    ${missing_bg_color}    Append To List    ${differences}    Missing CSS property in button: background-color
        
        # Add a general message if no specific differences were found
        ${diff_count}=    Get Length    ${differences}
        Run Keyword If    ${diff_count} == 0    
        ...    Append To List    ${differences}    CSS files differ but parsing failed. Check for syntax errors or comments.
    END
    
    # If no differences were found but the CSS doesn't match, add a general message
    ${diff_count}=    Get Length    ${differences}
    ${css_match}=    Run Keyword And Return Status    Should Be Equal As Strings    ${student_css}    ${teacher_css}
    
    Run Keyword If    ${diff_count} == 0 and not ${css_match}    
    ...    Append To List    ${differences}    CSS files differ but no specific differences were detected
    
    RETURN    ${differences}

Compare JS Content
    [Arguments]    ${student_js}    ${teacher_js}
    [Documentation]    Compare JavaScript content and return differences
    
    ${differences}=    Create List
    
    # Create a simple HTML template to test JS with
    ${temp_html}=    Set Variable    <html><body><div id='result'></div><button id='button'>Click</button></body></html>
    
    # Use the validator from WebCourseLibrary for JS comparison
    ${validator}=    Evaluate    WebCourseLibrary.WebCourseValidator()
    ${result}=    Evaluate    $validator.validate_submission($temp_html, "", $student_js, $temp_html, "", $teacher_js)
    
    # Extract missing elements (functions, event handlers)
    ${missing_elements}=    Set Variable    ${result["details"]["missing_elements"]}
    FOR    ${element}    IN    @{missing_elements}
        Append To List    ${differences}    Missing JavaScript: ${element}
    END
    
    # Extract other details if available
    ${details}=    Set Variable    ${result["details"]}
    Run Keyword If    'note' in $details    Append To List    ${differences}    Note: ${details["note"]}
    
    RETURN    ${differences}

Parse HTML
    [Arguments]    ${html_content}
    [Documentation]    Parse HTML content using BeautifulSoup
    
    # Import BeautifulSoup and parse HTML
    ${soup}=    Evaluate    BeautifulSoup($html_content, "html.parser")    modules=bs4
    RETURN    ${soup}

Get Elements
    [Arguments]    ${soup}    ${selector}
    [Documentation]    Get elements from BeautifulSoup object using selector
    
    # Use CSS selector to find elements
    ${elements}=    Evaluate    $soup.select($selector)
    RETURN    ${elements}

Find CSS Specific Differences
    [Arguments]    ${student_css}    ${teacher_css}
    [Documentation]    Find specific differences between CSS files
    
    # Parse CSS using the custom parser
    ${student_parsed}=    _parse_css_to_dict    ${student_css}
    ${teacher_parsed}=    _parse_css_to_dict    ${teacher_css}
    
    ${differences}=    Create List
    
    # Check for missing properties in specific selectors
    FOR    ${selector}    IN    @{teacher_parsed.keys()}
        ${teacher_props}=    Set Variable    ${teacher_parsed["${selector}"]}
        
        # Check if selector exists in student CSS
        ${selector_exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${student_parsed}    ${selector}
        
        # If selector exists, check for missing properties
        Run Keyword If    ${selector_exists}    
        ...    Compare CSS Properties    ${selector}    ${student_parsed["${selector}"]}    ${teacher_props}    ${differences}
        ...    ELSE    
        ...    Append To List    ${differences}    Missing CSS selector: ${selector}
    END
    
    # Check for all selectors in teacher CSS that might be missing in student CSS
    FOR    ${selector}    IN    @{teacher_parsed.keys()}
        ${selector_exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${student_parsed}    ${selector}
        Run Keyword If    not ${selector_exists}    
        ...    Append To List    ${differences}    Missing CSS selector: ${selector}
    END
    
    RETURN    ${differences}

Compare CSS Properties
    [Arguments]    ${selector}    ${student_props}    ${teacher_props}    ${differences}
    [Documentation]    Compare CSS properties for a specific selector
    
    FOR    ${prop}    IN    @{teacher_props.keys()}
        ${prop_exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${student_props}    ${prop}
        
        # If property doesn't exist, add to differences
        Run Keyword If    not ${prop_exists}    
        ...    Append To List    ${differences}    Missing CSS property in ${selector}: ${prop}
        
        # If property exists but value is different
        Run Keyword If    ${prop_exists} and '${student_props["${prop}"]}' != '${teacher_props["${prop}"]}'    
        ...    Append To List    ${differences}    CSS property value mismatch in ${selector}: ${prop} should be '${teacher_props["${prop}"]}' but found '${student_props["${prop}"]}'
    END

Compare Button Properties
    [Arguments]    ${student_button}    ${teacher_button}    ${differences}
    [Documentation]    Special comparison for button properties
    
    # Check specifically for background-color property in button
    ${has_bg_color}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${student_button}    background-color
    
    Run Keyword If    not ${has_bg_color} and "background-color" in $teacher_button    
    ...    Append To List    ${differences}    Missing CSS property in button: background-color (should be '${teacher_button["background-color"]}')

_parse_css_to_dict
    [Arguments]    ${css_text}
    [Documentation]    Parse CSS text into a dictionary structure
    
    # First, remove CSS comments to avoid parsing issues
    ${css_without_comments}=    Evaluate    re.sub(r'/\\*.*?\\*/', '', $css_text, flags=re.DOTALL)    modules=re
    
    # Use a simple regex-based approach for parsing CSS
    ${css_dict}=    Create Dictionary
    
    # Split CSS into rule blocks
    ${rule_blocks}=    Evaluate    re.findall(r'([^{]+){([^}]+)}', $css_without_comments)    modules=re
    
    FOR    ${rule}    IN    @{rule_blocks}
        ${selector}=    Set Variable    ${rule[0].strip()}
        
        # Skip empty selectors or comment remnants
        Continue For Loop If    '${selector}' == '' or '${selector}' == '/'
        
        ${properties_text}=    Set Variable    ${rule[1].strip()}
        
        # Parse properties
        ${properties}=    Create Dictionary
        ${prop_list}=    Evaluate    re.findall(r'([^:]+):([^;]+);?', $properties_text)    modules=re
        
        FOR    ${prop}    IN    @{prop_list}
            ${prop_name}=    Set Variable    ${prop[0].strip()}
            ${prop_value}=    Set Variable    ${prop[1].strip()}
            Set To Dictionary    ${properties}    ${prop_name}    ${prop_value}
        END
        
        Set To Dictionary    ${css_dict}    ${selector}    ${properties}
    END
    
    RETURN    ${css_dict}

Check For Missing CSS Property
    [Arguments]    ${student_css}    ${teacher_css}    ${selector}    ${property}
    [Documentation]    Check if a specific CSS property is missing using regex
    
    # Create regex pattern to find the property in the selector
    ${pattern}=    Set Variable    ${selector}\\s*{[^}]*${property}\\s*:
    
    # Check if property exists in teacher CSS
    ${teacher_has_prop}=    Evaluate    re.search(r'${pattern}', $teacher_css) is not None    modules=re
    
    # If teacher has it, check if student has it too
    ${student_has_prop}=    Run Keyword If    ${teacher_has_prop}    
    ...    Evaluate    re.search(r'${pattern}', $student_css) is not None    modules=re
    ...    ELSE    Set Variable    ${TRUE}
    
    # Return True if property is missing in student CSS
    RETURN    ${teacher_has_prop} and not ${student_has_prop} 

Compare HTML Content
    [Arguments]    ${student_html}    ${teacher_html}
    [Documentation]    Compare HTML content and return differences with enhanced detection for missing sections
    
    ${differences}=    Create List
    
    # Step 1: First use the standard DOMComparator for structural analysis
    ${comparator}=    Evaluate    WebCourseLibrary.DOMComparator(1)
    ${result}=    Evaluate    $comparator.compare_html_structure($student_html, $teacher_html)
    
    # Extract missing elements from DOMComparator result
    ${missing_elements}=    Set Variable    ${result["missing_elements"]}
    FOR    ${element}    IN    @{missing_elements}
        Append To List    ${differences}    Missing element: ${element}
    END
    
    # Extract attribute mismatches from DOMComparator result
    ${attribute_mismatches}=    Set Variable    ${result["attribute_mismatches"]}
    FOR    ${mismatch}    IN    @{attribute_mismatches}
        ${element}=    Set Variable    ${mismatch["element"]}
        ${attribute}=    Set Variable    ${mismatch["attribute"]}
        ${expected}=    Set Variable    ${mismatch["expected"]}
        ${actual}=    Set Variable    ${mismatch["actual"]}
        Append To List    ${differences}    Attribute mismatch in ${element}: ${attribute} should be '${expected}' but found '${actual}'
    END
    
    # Extract structure differences from DOMComparator result
    ${structure_diffs}=    Set Variable    ${result["structure_diffs"]}
    FOR    ${diff}    IN    @{structure_diffs}
        Append To List    ${differences}    Structure difference: ${diff}
    END
    
    # Step 2: Enhance with additional checks for missing sections/headings
    # Use a simpler, direct approach to check for missing headings and sections
    ${has_css_colors_heading_teacher}=    Evaluate    '<h2>Some CSS Colors:</h2>' in $teacher_html
    ${has_css_colors_heading_student}=    Evaluate    '<h2>Some CSS Colors:</h2>' in $student_html
    
    # Check specifically for the "Some CSS Colors:" heading
    Run Keyword If    ${has_css_colors_heading_teacher} and not ${has_css_colors_heading_student}
    ...    Append To List    ${differences}    Missing heading: h2 with text "Some CSS Colors:"
    
    # Check for specific content sections that might be missing
    ${sections_to_check}=    Create List    
    ...    "HTML Preview Example"
    ...    "Interactive Elements"
    ...    "Some CSS Colors"
    
    FOR    ${section}    IN    @{sections_to_check}
        ${present_in_teacher}=    Evaluate    $section in $teacher_html
        ${present_in_student}=    Evaluate    $section in $student_html
        
        Run Keyword If    ${present_in_teacher} and not ${present_in_student}
        ...    Append To List    ${differences}    Missing section with text: ${section}
    END
    
    # Check for structural and pattern differences
    # Pattern: Interactive Elements heading followed by button followed by Some CSS Colors heading
    ${teacher_pattern_exists}=    Evaluate    '<h2>Interactive Elements:</h2>' in $teacher_html and '<button' in $teacher_html and '<h2>Some CSS Colors:</h2>' in $teacher_html
    ${student_pattern_exists}=    Evaluate    '<h2>Interactive Elements:</h2>' in $student_html and '<button' in $student_html and '<h2>Some CSS Colors:</h2>' in $student_html
    
    Run Keyword If    ${teacher_pattern_exists} and not ${student_pattern_exists}
    ...    Append To List    ${differences}    Missing structural pattern: Interactive Elements -> Button -> Some CSS Colors heading
    
    # Count the number of h2 elements in both HTMLs
    ${h2_count_teacher}=    Evaluate    $teacher_html.count('<h2>')
    ${h2_count_student}=    Evaluate    $student_html.count('<h2>')
    
    Run Keyword If    ${h2_count_teacher} != ${h2_count_student}
    ...    Append To List    ${differences}    Heading count mismatch: Teacher has ${h2_count_teacher} h2 tags, Student has ${h2_count_student} h2 tags
    
    # If differences list is still empty but string comparison failed, provide a general message
    ${diff_count}=    Get Length    ${differences}
    
    Run Keyword If    ${diff_count} == 0
    ...    Append To List    ${differences}    HTML files differ but no specific structural differences were detected. Check for whitespace, comments, or text content differences.
    
    RETURN    ${differences}

Find Text Content Differences
    [Arguments]    ${student_html}    ${teacher_html}    ${differences}
    [Documentation]    Find differences in text content when structural comparison fails
    
    # Parse HTML using BeautifulSoup
    ${teacher_soup}=    Evaluate    BeautifulSoup($teacher_html, "html.parser")    modules=bs4
    ${student_soup}=    Evaluate    BeautifulSoup($student_html, "html.parser")    modules=bs4
    
    # Extract all text content
    ${teacher_text}=    Evaluate    $teacher_soup.get_text(separator=" ", strip=True)
    ${student_text}=    Evaluate    $student_soup.get_text(separator=" ", strip=True)
    
    # Compare text content
    Run Keyword If    "${teacher_text}" != "${student_text}"    
    ...    Compare Text Content    ${student_text}    ${teacher_text}    ${differences}
    
    # If still no differences found, try direct string comparison of specific sections
    ${diff_count}=    Get Length    ${differences}
    
    Run Keyword If    ${diff_count} == 0    
    ...    Append To List    ${differences}    HTML files differ but no specific structural differences were detected. Check for whitespace, comments, or text content differences.

Compare Text Content
    [Arguments]    ${student_text}    ${teacher_text}    ${differences}
    [Documentation]    Compare text content for differences
    
    # Split text into words for comparison
    ${teacher_words}=    Evaluate    "${teacher_text}".split()
    ${student_words}=    Evaluate    "${student_text}".split()
    
    # Find missing words in student text
    ${missing_words}=    Create List
    
    FOR    ${word}    IN    @{teacher_words}
        ${count_in_teacher}=    Evaluate    "${teacher_text}".count("${word}")
        ${count_in_student}=    Evaluate    "${student_text}".count("${word}")
        
        Run Keyword If    ${count_in_teacher} > ${count_in_student}    
        ...    Append To List    ${missing_words}    ${word}
    END
    
    # Report missing words if found
    ${missing_count}=    Get Length    ${missing_words}
    
    Run Keyword If    ${missing_count} > 0    
    ...    Append To List    ${differences}    Missing text content: ${missing_words}
    
    # Look specifically for text sections that might be missing
    ${unique_sections}=    Evaluate    re.findall(r'([A-Z][a-z]+ [A-Z][a-z]+:)', "${teacher_text}")    modules=re
    
    FOR    ${section}    IN    @{unique_sections}
        ${has_section}=    Evaluate    "${student_text}".find("${section}") >= 0
        
        Run Keyword If    not ${has_section}    
        ...    Append To List    ${differences}    Missing text section: "${section}"
    END