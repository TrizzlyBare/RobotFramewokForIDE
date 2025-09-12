*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String
Library           DateTime
Resource          DynamicTestingFramework.robot

*** Variables ***
${INTEGRATED_RESULTS_DIR}    ./integrated_results
${WEB_SANDBOX_DIR}           ./web_sandbox
${BROWSER_TIMEOUT}           30s

*** Keywords ***
Initialize Integrated Testing Environment
    [Documentation]    Set up environment for both code execution and web testing
    Initialize Dynamic Testing Environment
    Create Directory    ${INTEGRATED_RESULTS_DIR}
    Create Directory    ${WEB_SANDBOX_DIR}
    
    Log    Integrated testing environment initialized

Load And Validate Test Definition
    [Arguments]    ${lesson_id}
    [Documentation]    Load and validate test definition structure
    ${test_definition}    Load Test Definition    ${lesson_id}
    
    # Validate required fields
    Should Contain    ${test_definition}    lesson_id
    Should Contain    ${test_definition}    test_cases
    Should Contain    ${test_definition}    behavioral_requirements
    Should Contain    ${test_definition}    execution_environment
    
    ${language}    Get From Dictionary    ${test_definition}[execution_environment]    language
    Log    Loaded test definition for ${lesson_id} (${language})
    
    RETURN    ${test_definition}

Determine Testing Mode
    [Arguments]    ${test_definition}
    [Documentation]    Determine whether to use code execution or browser testing
    ${execution_env}    Get From Dictionary    ${test_definition}    execution_environment
    ${runtime}    Get From Dictionary    ${execution_env}    runtime    default=code
    
    IF    '${runtime}' == 'browser'
        RETURN    web_testing
    ELSE
        RETURN    code_execution
    END

Execute Integrated Test Suite
    [Arguments]    ${user_submission}    ${lesson_id}
    [Documentation]    Execute comprehensive test suite based on lesson requirements
    
    # Load test definition
    ${test_definition}    Load And Validate Test Definition    ${lesson_id}
    
    # Determine testing approach
    ${testing_mode}    Determine Testing Mode    ${test_definition}
    
    Log    Executing ${testing_mode} for lesson ${lesson_id}
    
    IF    '${testing_mode}' == 'web_testing'
        ${results}    Execute Web Testing Suite    ${user_submission}    ${test_definition}
    ELSE
        ${results}    Execute Code Testing Suite    ${user_submission}    ${test_definition}
    END
    
    # Generate comprehensive feedback
    ${feedback}    Generate Integrated Feedback    ${results}    ${test_definition}
    Set To Dictionary    ${results}    feedback    ${feedback}
    
    # Save results
    ${timestamp}    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${results_file}    Set Variable    ${INTEGRATED_RESULTS_DIR}/results_${lesson_id}_${timestamp}.json
    ${results_json}    Evaluate    json.dumps($results, indent=2, default=str)    json
    Create File    ${results_file}    ${results_json}
    
    Log    Test results saved to ${results_file}
    RETURN    ${results}

Execute Code Testing Suite
    [Arguments]    ${user_submission}    ${test_definition}
    [Documentation]    Execute code-based testing with instrumentation
    
    ${language}    Get From Dictionary    ${test_definition}[execution_environment]    language
    ${user_code}    Get From Dictionary    ${user_submission}    code
    
    # Run dynamic test suite
    ${test_results}    Run Dynamic Test Suite    ${user_code}    ${language}    ${test_definition}
    
    # Add metadata
    Set To Dictionary    ${test_results}    testing_mode    code_execution
    Set To Dictionary    ${test_results}    lesson_id    ${test_definition}[lesson_id]
    Set To Dictionary    ${test_results}    timestamp    ${Get Current Date    result_format=%Y-%m-%d %H:%M:%S}
    
    RETURN    ${test_results}

Execute Web Testing Suite
    [Arguments]    ${user_submission}    ${test_definition}
    [Documentation]    Execute web-based testing with browser automation
    
    # Extract web components
    ${html_code}    Get From Dictionary    ${user_submission}    html
    ${css_code}    Get From Dictionary    ${user_submission}    css
    ${js_code}    Get From Dictionary    ${user_submission}    javascript
    
    # Create complete web page
    ${page_file}    Create Web Page For Testing    ${html_code}    ${css_code}    ${js_code}
    
    # Execute browser actions if defined
    ${browser_actions}    Get From Dictionary    ${test_definition}    browser_actions    default=@{EMPTY}
    ${interaction_results}    Execute Browser Action Sequence    ${page_file}    ${browser_actions}
    
    # Analyze behavioral requirements for web
    ${behavioral_requirements}    Get From Dictionary    ${test_definition}    behavioral_requirements
    ${behavioral_analysis}    Analyze Web Behavioral Requirements    ${html_code}    ${css_code}    ${js_code}    ${behavioral_requirements}
    
    # Compile results
    ${test_results}    Create Dictionary
    ...    testing_mode=web_testing
    ...    lesson_id=${test_definition}[lesson_id]
    ...    timestamp=${Get Current Date    result_format=%Y-%m-%d %H:%M:%S}
    ...    interaction_results=${interaction_results}
    ...    behavioral_analysis=${behavioral_analysis}
    ...    html_length=${{ len($html_code) }}
    ...    css_length=${{ len($css_code) }}
    ...    js_length=${{ len($js_code) }}
    
    # Calculate scores
    ${interaction_score}    Calculate Interaction Score    ${interaction_results}
    ${behavioral_score}    Calculate Behavioral Score    ${behavioral_analysis}
    ${code_quality_score}    Calculate Web Code Quality Score    ${html_code}    ${css_code}    ${js_code}
    
    ${grading}    Get From Dictionary    ${test_definition}    grading
    ${correctness_weight}    Get From Dictionary    ${grading}    correctness_weight    default=0.4
    ${behavioral_weight}    Get From Dictionary    ${grading}    behavioral_weight    default=0.4
    ${quality_weight}    Get From Dictionary    ${grading}    code_quality_weight    default=0.2
    
    ${overall_score}    Evaluate    
    ...    ${interaction_score} * ${correctness_weight} + ${behavioral_score} * ${behavioral_weight} + ${code_quality_score} * ${quality_weight}
    
    Set To Dictionary    ${test_results}    interaction_score    ${interaction_score}
    Set To Dictionary    ${test_results}    behavioral_score    ${behavioral_score}
    Set To Dictionary    ${test_results}    code_quality_score    ${code_quality_score}
    Set To Dictionary    ${test_results}    overall_score    ${overall_score}
    
    RETURN    ${test_results}

Create Web Page For Testing
    [Arguments]    ${html_code}    ${css_code}    ${js_code}
    [Documentation]    Create a complete HTML page for browser testing
    
    ${complete_html}    Set Variable    <!DOCTYPE html>
    ...    <html lang="en">
    ...    <head>
    ...        <meta charset="UTF-8">
    ...        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    ...        <title>Student Submission Test</title>
    ...        <style>
    ...        ${css_code}
    ...        </style>
    ...    </head>
    ...    <body>
    ...        ${html_code}
    ...        <script>
    ...        // Instrumentation wrapper
    ...        const testData = {
    ...            domOperations: [],
    ...            eventHandlers: [],
    ...            errors: []
    ...        };
    ...        
    ...        // Monitor DOM operations
    ...        const originalGetElementById = document.getElementById;
    ...        const originalQuerySelector = document.querySelector;
    ...        
    ...        document.getElementById = function(id) {
    ...            testData.domOperations.push('getElementById:' + id);
    ...            return originalGetElementById.call(this, id);
    ...        };
    ...        
    ...        document.querySelector = function(selector) {
    ...            testData.domOperations.push('querySelector:' + selector);
    ...            return originalQuerySelector.call(this, selector);
    ...        };
    ...        
    ...        // Monitor event listeners
    ...        const originalAddEventListener = Element.prototype.addEventListener;
    ...        Element.prototype.addEventListener = function(event, handler) {
    ...            testData.eventHandlers.push(event + ':' + this.tagName);
    ...            return originalAddEventListener.call(this, event, handler);
    ...        };
    ...        
    ...        // Execute user code
    ...        try {
    ...            ${js_code}
    ...        } catch (error) {
    ...            testData.errors.push(error.message);
    ...        }
    ...        
    ...        // Make test data globally accessible
    ...        window.testData = testData;
    ...        </script>
    ...    </body>
    ...    </html>
    
    ${page_file}    Set Variable    ${WEB_SANDBOX_DIR}/test_page.html
    Create File    ${page_file}    ${complete_html}
    
    RETURN    ${page_file}

Execute Browser Action Sequence
    [Arguments]    ${page_file}    ${browser_actions}
    [Documentation]    Execute sequence of browser actions (simulated for now)
    
    ${results}    Create List
    
    FOR    ${action}    IN    @{browser_actions}
        ${step}    Get From Dictionary    ${action}    step
        ${action_type}    Get From Dictionary    ${action}    action
        ${target}    Get From Dictionary    ${action}    target    default=${EMPTY}
        
        ${action_result}    Create Dictionary
        ...    step=${step}
        ...    action=${action_type}
        ...    target=${target}
        ...    success=${True}
        ...    message=Action simulated successfully
        
        # In a real implementation, this would use Playwright/Selenium
        # For now, we simulate the actions
        IF    '${action_type}' == 'load_page'
            Log    Simulating page load: ${target}
        ELSE IF    '${action_type}' == 'click'
            Log    Simulating click on: ${target}
        ELSE IF    '${action_type}' == 'verify_text'
            ${expected}    Get From Dictionary    ${action}    expected
            Log    Simulating text verification: ${target} should contain "${expected}"
        ELSE IF    '${action_type}' == 'verify_style'
            ${property}    Get From Dictionary    ${action}    property
            ${expected}    Get From Dictionary    ${action}    expected
            Log    Simulating style verification: ${target}.${property} should be "${expected}"
        END
        
        Append To List    ${results}    ${action_result}
    END
    
    RETURN    ${results}

Analyze Web Behavioral Requirements
    [Arguments]    ${html_code}    ${css_code}    ${js_code}    ${behavioral_requirements}
    [Documentation]    Analyze web code against behavioral requirements
    
    ${analysis_results}    Create Dictionary
    
    FOR    ${requirement}    IN    @{behavioral_requirements}
        ${requirement_type}    Get From Dictionary    ${requirement}    type
        ${name}    Get From Dictionary    ${requirement}    name
        
        IF    '${requirement_type}' == 'dom_manipulation'
            ${result}    Analyze DOM Manipulation Web    ${js_code}    ${requirement}
        ELSE IF    '${requirement_type}' == 'event_handling'
            ${result}    Analyze Event Handling Web    ${js_code}    ${requirement}
        ELSE IF    '${requirement_type}' == 'html_structure'
            ${result}    Analyze HTML Structure Web    ${html_code}    ${requirement}
        ELSE IF    '${requirement_type}' == 'css_styling'
            ${result}    Analyze CSS Styling Web    ${css_code}    ${requirement}
        ELSE
            ${result}    Create Dictionary    satisfied=${False}    reason=Unknown requirement type
        END
        
        Set To Dictionary    ${analysis_results}    ${name}    ${result}
    END
    
    RETURN    ${analysis_results}

Analyze DOM Manipulation Web
    [Arguments]    ${js_code}    ${requirement}
    [Documentation]    Check if JavaScript properly manipulates DOM
    
    ${criteria}    Get From Dictionary    ${requirement}    criteria
    ${operations}    Get From Dictionary    ${criteria}    operations
    ${min_operations}    Get From Dictionary    ${criteria}    min_operations    default=1
    
    ${found_operations}    Set Variable    0
    ${found_details}    Create List
    
    FOR    ${operation}    IN    @{operations}
        ${has_operation}    Run Keyword And Return Status    Should Contain    ${js_code}    ${operation}
        IF    ${has_operation}
            ${found_operations}    Evaluate    ${found_operations} + 1
            Append To List    ${found_details}    Found ${operation}
        END
    END
    
    ${satisfied}    Evaluate    ${found_operations} >= ${min_operations}
    
    ${result}    Create Dictionary
    ...    satisfied=${satisfied}
    ...    found_operations=${found_operations}
    ...    required_operations=${min_operations}
    ...    details=${found_details}
    
    RETURN    ${result}

Analyze Event Handling Web
    [Arguments]    ${js_code}    ${requirement}
    [Documentation]    Check if JavaScript properly handles events
    
    ${criteria}    Get From Dictionary    ${requirement}    criteria
    ${events}    Get From Dictionary    ${criteria}    events
    ${methods}    Get From Dictionary    ${criteria}    methods
    
    ${events_found}    Set Variable    0
    ${methods_found}    Set Variable    0
    ${details}    Create List
    
    FOR    ${event}    IN    @{events}
        ${has_event}    Run Keyword And Return Status    Should Contain    ${js_code}    ${event}
        IF    ${has_event}
            ${events_found}    Evaluate    ${events_found} + 1
            Append To List    ${details}    Event ${event} handling detected
        END
    END
    
    FOR    ${method}    IN    @{methods}
        ${has_method}    Run Keyword And Return Status    Should Contain    ${js_code}    ${method}
        IF    ${has_method}
            ${methods_found}    Evaluate    ${methods_found} + 1
            Append To List    ${details}    Method ${method} usage detected
        END
    END
    
    ${satisfied}    Evaluate    ${events_found} > 0 and ${methods_found} > 0
    
    ${result}    Create Dictionary
    ...    satisfied=${satisfied}
    ...    events_found=${events_found}
    ...    methods_found=${methods_found}
    ...    details=${details}
    
    RETURN    ${result}

Analyze HTML Structure Web
    [Arguments]    ${html_code}    ${requirement}
    [Documentation]    Check if HTML has required structure
    
    ${criteria}    Get From Dictionary    ${requirement}    criteria
    ${required_elements}    Get From Dictionary    ${criteria}    required_elements
    
    ${all_found}    Set Variable    ${True}
    ${details}    Create List
    
    FOR    ${element}    IN    @{required_elements}
        ${tag}    Get From Dictionary    ${element}    tag
        ${id}    Get From Dictionary    ${element}    id    default=${EMPTY}
        ${class}    Get From Dictionary    ${element}    class    default=${EMPTY}
        
        IF    '${id}' != ''
            ${pattern}    Set Variable    <${tag}[^>]*id=["']${id}["']
            ${found}    Run Keyword And Return Status    Should Match Regexp    ${html_code}    ${pattern}
            IF    ${found}
                Append To List    ${details}    Found <${tag}> with id="${id}"
            ELSE
                ${all_found}    Set Variable    ${False}
                Append To List    ${details}    Missing <${tag}> with id="${id}"
            END
        ELSE IF    '${class}' != ''
            ${pattern}    Set Variable    <${tag}[^>]*class=["'][^"']*${class}[^"']*["']
            ${found}    Run Keyword And Return Status    Should Match Regexp    ${html_code}    ${pattern}
            IF    ${found}
                Append To List    ${details}    Found <${tag}> with class="${class}"
            ELSE
                ${all_found}    Set Variable    ${False}
                Append To List    ${details}    Missing <${tag}> with class="${class}"
            END
        ELSE
            ${found}    Run Keyword And Return Status    Should Contain    ${html_code}    <${tag}
            IF    ${found}
                Append To List    ${details}    Found <${tag}> element
            ELSE
                ${all_found}    Set Variable    ${False}
                Append To List    ${details}    Missing <${tag}> element
            END
        END
    END
    
    ${result}    Create Dictionary
    ...    satisfied=${all_found}
    ...    details=${details}
    
    RETURN    ${result}

Analyze CSS Styling Web
    [Arguments]    ${css_code}    ${requirement}
    [Documentation]    Check if CSS has required styling
    
    ${criteria}    Get From Dictionary    ${requirement}    criteria
    ${selectors}    Get From Dictionary    ${criteria}    selectors
    ${properties}    Get From Dictionary    ${criteria}    properties
    
    ${selectors_found}    Set Variable    0
    ${properties_found}    Set Variable    0
    ${details}    Create List
    
    FOR    ${selector}    IN    @{selectors}
        ${has_selector}    Run Keyword And Return Status    Should Contain    ${css_code}    ${selector}
        IF    ${has_selector}
            ${selectors_found}    Evaluate    ${selectors_found} + 1
            Append To List    ${details}    Selector ${selector} found
        END
    END
    
    FOR    ${property}    IN    @{properties}
        ${has_property}    Run Keyword And Return Status    Should Contain    ${css_code}    ${property}
        IF    ${has_property}
            ${properties_found}    Evaluate    ${properties_found} + 1
            Append To List    ${details}    Property ${property} found
        END
    END
    
    ${satisfied}    Evaluate    ${selectors_found} > 0 and ${properties_found} > 0
    
    ${result}    Create Dictionary
    ...    satisfied=${satisfied}
    ...    selectors_found=${selectors_found}
    ...    properties_found=${properties_found}
    ...    details=${details}
    
    RETURN    ${result}

Calculate Interaction Score
    [Arguments]    ${interaction_results}
    [Documentation]    Calculate score based on browser interactions
    
    ${total_actions}    Get Length    ${interaction_results}
    ${successful_actions}    Set Variable    0
    
    FOR    ${result}    IN    @{interaction_results}
        ${success}    Get From Dictionary    ${result}    success
        IF    ${success}
            ${successful_actions}    Evaluate    ${successful_actions} + 1
        END
    END
    
    ${score}    Evaluate    ${successful_actions} / ${total_actions} * 100 if ${total_actions} > 0 else 100
    RETURN    ${score}

Calculate Web Code Quality Score
    [Arguments]    ${html_code}    ${css_code}    ${js_code}
    [Documentation]    Calculate overall code quality score for web code
    
    ${html_score}    Calculate HTML Quality    ${html_code}
    ${css_score}    Calculate CSS Quality    ${css_code}
    ${js_score}    Calculate JS Quality    ${js_code}
    
    ${overall_quality}    Evaluate    (${html_score} + ${css_score} + ${js_score}) / 3
    RETURN    ${overall_quality}

Calculate HTML Quality
    [Arguments]    ${html_code}
    [Documentation]    Calculate HTML code quality
    ${score}    Set Variable    70
    
    # Check for semantic elements
    ${has_semantic}    Run Keyword And Return Status    Should Match Regexp    ${html_code}    <(header|nav|main|section|article|aside|footer)
    IF    ${has_semantic}
        ${score}    Evaluate    ${score} + 15
    END
    
    # Check for proper attributes
    ${has_alt}    Run Keyword And Return Status    Should Contain    ${html_code}    alt=
    IF    ${has_alt}
        ${score}    Evaluate    ${score} + 10
    END
    
    # Check for accessibility
    ${has_labels}    Run Keyword And Return Status    Should Contain    ${html_code}    <label
    IF    ${has_labels}
        ${score}    Evaluate    ${score} + 5
    END
    
    RETURN    ${score}

Calculate CSS Quality
    [Arguments]    ${css_code}
    [Documentation]    Calculate CSS code quality
    ${score}    Set Variable    70
    
    # Check for modern layout
    ${has_flexbox}    Run Keyword And Return Status    Should Contain    ${css_code}    display: flex
    ${has_grid}    Run Keyword And Return Status    Should Contain    ${css_code}    display: grid
    IF    ${has_flexbox} or ${has_grid}
        ${score}    Evaluate    ${score} + 15
    END
    
    # Check for responsive design
    ${has_media}    Run Keyword And Return Status    Should Contain    ${css_code}    @media
    IF    ${has_media}
        ${score}    Evaluate    ${score} + 10
    END
    
    # Check for hover effects
    ${has_hover}    Run Keyword And Return Status    Should Contain    ${css_code}    :hover
    IF    ${has_hover}
        ${score}    Evaluate    ${score} + 5
    END
    
    RETURN    ${score}

Calculate JS Quality
    [Arguments]    ${js_code}
    [Documentation]    Calculate JavaScript code quality
    ${score}    Set Variable    70
    
    # Check for modern syntax
    ${has_const}    Run Keyword And Return Status    Should Contain    ${js_code}    const
    ${has_let}    Run Keyword And Return Status    Should Contain    ${js_code}    let
    IF    ${has_const} or ${has_let}
        ${score}    Evaluate    ${score} + 10
    END
    
    # Check for proper event handling
    ${has_addEventListener}    Run Keyword And Return Status    Should Contain    ${js_code}    addEventListener
    IF    ${has_addEventListener}
        ${score}    Evaluate    ${score} + 15
    END
    
    # Check for arrow functions
    ${has_arrow}    Run Keyword And Return Status    Should Contain    ${js_code}    =>
    IF    ${has_arrow}
        ${score}    Evaluate    ${score} + 5
    END
    
    RETURN    ${score}

Generate Integrated Feedback
    [Arguments]    ${test_results}    ${test_definition}
    [Documentation]    Generate comprehensive feedback combining all test aspects
    
    ${feedback_templates}    Get From Dictionary    ${test_definition}    feedback_templates
    ${feedback}    Create Dictionary
    
    ${overall_score}    Get From Dictionary    ${test_results}    overall_score
    ${testing_mode}    Get From Dictionary    ${test_results}    testing_mode
    
    # Overall performance message
    IF    ${overall_score} >= 90
        ${performance_message}    Set Variable    Excellent work! Your solution demonstrates mastery of the concepts.
    ELSE IF    ${overall_score} >= 75
        ${performance_message}    Set Variable    Good job! Your solution is solid with minor areas for improvement.
    ELSE IF    ${overall_score} >= 60
        ${performance_message}    Set Variable    Your solution shows understanding but needs improvement in key areas.
    ELSE
        ${performance_message}    Set Variable    Your solution requires significant improvement. Please review the concepts.
    END
    
    Set To Dictionary    ${feedback}    performance_message    ${performance_message}
    Set To Dictionary    ${feedback}    overall_score    ${overall_score}
    Set To Dictionary    ${feedback}    testing_mode    ${testing_mode}
    
    # Specific feedback based on testing mode
    IF    '${testing_mode}' == 'web_testing'
        ${web_feedback}    Generate Web Specific Feedback    ${test_results}    ${feedback_templates}
        Set To Dictionary    ${feedback}    web_specific    ${web_feedback}
    ELSE
        ${code_feedback}    Generate Code Specific Feedback    ${test_results}    ${feedback_templates}
        Set To Dictionary    ${feedback}    code_specific    ${code_feedback}
    END
    
    RETURN    ${feedback}

Generate Web Specific Feedback
    [Arguments]    ${test_results}    ${feedback_templates}
    [Documentation]    Generate feedback specific to web development testing
    
    ${web_feedback}    Create List
    ${behavioral_analysis}    Get From Dictionary    ${test_results}    behavioral_analysis
    
    FOR    ${requirement_name}    ${analysis}    IN    &{behavioral_analysis}
        ${satisfied}    Get From Dictionary    ${analysis}    satisfied
        IF    not ${satisfied}
            ${feedback_key}    Set Variable    ${requirement_name}_not_satisfied
            ${message}    Get From Dictionary    ${feedback_templates}    ${feedback_key}    default=Requirement ${requirement_name} not satisfied
            Append To List    ${web_feedback}    ${message}
        END
    END
    
    RETURN    ${web_feedback}

Generate Code Specific Feedback
    [Arguments]    ${test_results}    ${feedback_templates}
    [Documentation]    Generate feedback specific to code execution testing
    
    ${code_feedback}    Create List
    ${behavioral_analysis}    Get From Dictionary    ${test_results}    behavioral_analysis
    
    FOR    ${requirement_type}    ${analysis}    IN    &{behavioral_analysis}
        ${satisfied}    Get From Dictionary    ${analysis}    satisfied
        IF    not ${satisfied}
            ${reason}    Get From Dictionary    ${analysis}    reason    default=Requirement not met
            Append To List    ${code_feedback}    ${requirement_type}: ${reason}
        END
    END
    
    RETURN    ${code_feedback}

Cleanup Integrated Testing Environment
    [Documentation]    Clean up all testing environments
    Cleanup Dynamic Testing Environment
    Remove Directory    ${WEB_SANDBOX_DIR}    recursive=True

*** Test Cases ***
Integrated Testing Example - Recursion
    [Documentation]    Example of integrated testing with recursion
    [Setup]    Initialize Integrated Testing Environment
    [Teardown]    Cleanup Integrated Testing Environment
    
    # Test recursive factorial
    ${user_submission}    Create Dictionary
    ...    code=def factorial(n):\n    if n <= 1:\n        return 1\n    return n * factorial(n - 1)\n\nn = int(input())\nprint(factorial(n))
    
    ${results}    Execute Integrated Test Suite    ${user_submission}    recursion_factorial
    
    ${overall_score}    Get From Dictionary    ${results}    overall_score
    Log    Recursion Test - Overall Score: ${overall_score}%
    
    Should Be True    ${overall_score} >= 70    Recursive solution should pass

Integrated Testing Example - Web DOM
    [Documentation]    Example of integrated web testing
    [Setup]    Initialize Integrated Testing Environment
    [Teardown]    Cleanup Integrated Testing Environment
    
    # Test web DOM manipulation
    ${user_submission}    Create Dictionary
    ...    html=<div class="container"><button id="interactive-btn">Click Me</button></div>
    ...    css=.container { padding: 20px; } #interactive-btn { background-color: blue; color: white; }
    ...    javascript=document.getElementById('interactive-btn').addEventListener('click', function() { this.textContent = 'Clicked!'; this.style.backgroundColor = 'green'; });
    
    ${results}    Execute Integrated Test Suite    ${user_submission}    dom_manipulation_interactive_button
    
    ${overall_score}    Get From Dictionary    ${results}    overall_score
    Log    DOM Manipulation Test - Overall Score: ${overall_score}%
    
    Should Be True    ${overall_score} >= 60    DOM manipulation should show basic functionality

Dynamic Test Execution From Variables
    [Documentation]    Test execution using variables passed from main script
    [Setup]    Initialize Integrated Testing Environment
    [Teardown]    Cleanup Integrated Testing Environment
    
    # Get variables from command line (set by main.py)
    ${lesson_id}        Get Variable Value    ${LESSON_ID}    recursion_factorial
    ${submission_file}  Get Variable Value    ${SUBMISSION_FILE}    examples/factorial_submission.json
    ${testing_mode}     Get Variable Value    ${TESTING_MODE}    code
    
    Log    Executing dynamic test for lesson: ${lesson_id}
    Log    Submission file: ${submission_file}
    Log    Testing mode: ${testing_mode}
    
    # Load submission from file
    ${submission_data}    Load JSON From File    ${submission_file}
    
    # Execute the test suite
    ${results}    Execute Integrated Test Suite    ${submission_data}    ${lesson_id}
    
    # Log comprehensive results
    ${overall_score}    Get From Dictionary    ${results}    overall_score
    ${testing_mode_actual}    Get From Dictionary    ${results}    testing_mode
    
    Log    Test Results Summary:
    Log    - Lesson ID: ${lesson_id}
    Log    - Testing Mode: ${testing_mode_actual}
    Log    - Overall Score: ${overall_score}%
    
    # Save results for main script to retrieve
    Create Directory    ${INTEGRATED_RESULTS_DIR}
    ${timestamp}    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${results_file}    Set Variable    ${INTEGRATED_RESULTS_DIR}/results_${lesson_id}_${timestamp}.json
    ${results_json}    Evaluate    json.dumps($results, indent=2, default=str)    json
    Create File    ${results_file}    ${results_json}
    
    Log    Results saved to: ${results_file}
    
    # Pass/fail determination
    ${passed}    Evaluate    ${overall_score} >= 70
    Run Keyword If    not ${passed}    Fail    Test failed with score ${overall_score}% (minimum 70% required)