*** Settings ***
Library           JSONLibrary
Library           OperatingSystem
Library           Collections
Library           Process
Library           String
Library           DateTime
Library           XML

*** Variables ***
${SANDBOX_DIR}           ./sandbox
${TEST_DEFINITIONS_DIR}  ./test_definitions
${RESULTS_DIR}           ./results
${INSTRUMENTATION_DIR}   ./instrumentation
${TIMEOUT}               30s

*** Keywords ***
Initialize Dynamic Testing Environment
    [Documentation]    Set up secure sandbox environment for code execution
    Create Directory    ${SANDBOX_DIR}
    Create Directory    ${TEST_DEFINITIONS_DIR}
    Create Directory    ${RESULTS_DIR}
    Create Directory    ${INSTRUMENTATION_DIR}
    
    # Create isolated Python environment for code execution
    ${result}    Run Process    python    -m    venv    ${SANDBOX_DIR}/python_env
    ...    timeout=${TIMEOUT}    stderr=STDOUT
    
    # Install required packages in sandbox
    ${pip_path}    Set Variable    ${SANDBOX_DIR}/python_env/bin/pip
    Run Process    ${pip_path}    install    ast    json    sys    io    
    ...    timeout=${TIMEOUT}    stderr=STDOUT
    
    Log    Dynamic testing environment initialized

Load Test Definition
    [Arguments]    ${lesson_id}
    [Documentation]    Load dynamic test definition for a specific lesson
    ${test_def_file}    Set Variable    ${TEST_DEFINITIONS_DIR}/${lesson_id}.json
    ${test_definition}    Load JSON From File    ${test_def_file}
    RETURN    ${test_definition}

Create Instrumented Code Wrapper
    [Arguments]    ${user_code}    ${language}    ${instrumentation_config}
    [Documentation]    Wrap user code with instrumentation for behavioral analysis
    
    IF    '${language}' == 'python'
        ${instrumented_code}    Create Python Instrumentation    ${user_code}    ${instrumentation_config}
    ELSE IF    '${language}' == 'javascript'
        ${instrumented_code}    Create JavaScript Instrumentation    ${user_code}    ${instrumentation_config}
    ELSE
        Fail    Unsupported language: ${language}
    END
    
    RETURN    ${instrumented_code}

Create Python Instrumentation
    [Arguments]    ${user_code}    ${instrumentation_config}
    [Documentation]    Create instrumented Python code for behavioral analysis
    
    ${monitor_functions}    Get From Dictionary    ${instrumentation_config}    monitor_functions    default=${False}
    ${monitor_recursion}    Get From Dictionary    ${instrumentation_config}    monitor_recursion    default=${False}
    ${monitor_loops}        Get From Dictionary    ${instrumentation_config}    monitor_loops        default=${False}
    ${monitor_classes}      Get From Dictionary    ${instrumentation_config}    monitor_classes      default=${False}
    
    ${instrumentation_code}    Set Variable    
    ...    import json
    ...    import sys
    ...    import ast
    ...    import types
    ...    from collections import defaultdict
    ...    
    ...    # Execution monitoring data
    ...    execution_data = {
    ...        'function_calls': defaultdict(int),
    ...        'recursion_depth': defaultdict(int),
    ...        'loop_iterations': defaultdict(int),
    ...        'class_instantiations': defaultdict(int),
    ...        'execution_path': [],
    ...        'errors': []
    ...    }
    ...    
    ...    # Function call tracer
    ...    original_functions = {}
    ...    
    ...    def trace_function_calls(frame, event, arg):
    ...        if event == 'call':
    ...            func_name = frame.f_code.co_name
    ...            if not func_name.startswith('__') and not func_name.startswith('trace_'):
    ...                execution_data['function_calls'][func_name] += 1
    ...                execution_data['execution_path'].append(f"call:{func_name}")
    ...                
    ...                # Check for recursion
    ...                if func_name in [f.f_code.co_name for f in frame.f_back and get_stack_frames(frame.f_back) or []]:
    ...                    execution_data['recursion_depth'][func_name] += 1
    ...        return trace_function_calls
    ...    
    ...    def get_stack_frames(frame):
    ...        frames = []
    ...        while frame:
    ...            frames.append(frame)
    ...            frame = frame.f_back
    ...        return frames
    ...    
    ...    # AST analyzer for loop detection
    ...    class LoopAnalyzer(ast.NodeVisitor):
    ...        def __init__(self):
    ...            self.loop_count = 0
    ...            self.loop_types = []
    ...        
    ...        def visit_For(self, node):
    ...            self.loop_count += 1
    ...            self.loop_types.append('for')
    ...            execution_data['loop_iterations']['for'] += 1
    ...            self.generic_visit(node)
    ...        
    ...        def visit_While(self, node):
    ...            self.loop_count += 1
    ...            self.loop_types.append('while')
    ...            execution_data['loop_iterations']['while'] += 1
    ...            self.generic_visit(node)
    ...    
    ...    # Class instantiation monitor
    ...    original_new = type.__new__
    ...    def monitored_new(cls, *args, **kwargs):
    ...        if not cls.__name__.startswith('__'):
    ...            execution_data['class_instantiations'][cls.__name__] += 1
    ...        return original_new(cls)
    ...    type.__new__ = staticmethod(monitored_new)
    ...    
    ...    # Analyze user code AST
    ...    user_code_ast = compile("""${user_code}""", '<user_code>', 'exec')
    ...    loop_analyzer = LoopAnalyzer()
    ...    
    ...    try:
    ...        parsed_ast = ast.parse("""${user_code}""")
    ...        loop_analyzer.visit(parsed_ast)
    ...    except Exception as e:
    ...        execution_data['errors'].append(f"AST analysis error: {str(e)}")
    ...    
    ...    # Set up tracing
    ...    if ${monitor_functions} or ${monitor_recursion}:
    ...        sys.settrace(trace_function_calls)
    ...    
    ...    try:
    ...        # Execute user code
    ...        exec("""${user_code}""")
    ...    except Exception as e:
    ...        execution_data['errors'].append(f"Execution error: {str(e)}")
    ...    finally:
    ...        sys.settrace(None)
    ...    
    ...    # Output execution data
    ...    print("EXECUTION_DATA_START")
    ...    print(json.dumps(execution_data))
    ...    print("EXECUTION_DATA_END")
    
    RETURN    ${instrumentation_code}

Create JavaScript Instrumentation
    [Arguments]    ${user_code}    ${instrumentation_config}
    [Documentation]    Create instrumented JavaScript code for behavioral analysis
    
    ${instrumentation_code}    Set Variable    
    ...    // Execution monitoring
    ...    const executionData = {
    ...        functionCalls: new Map(),
    ...        recursionDepth: new Map(),
    ...        loopIterations: new Map(),
    ...        domManipulations: [],
    ...        eventHandlers: [],
    ...        executionPath: [],
    ...        errors: []
    ...    };
    ...    
    ...    // Function call monitoring
    ...    const originalFunctions = new Map();
    ...    
    ...    function wrapFunction(obj, funcName) {
    ...        if (typeof obj[funcName] === 'function' && !funcName.startsWith('wrap')) {
    ...            const original = obj[funcName];
    ...            originalFunctions.set(funcName, original);
    ...            
    ...            obj[funcName] = function(...args) {
    ...                executionData.functionCalls.set(funcName, (executionData.functionCalls.get(funcName) || 0) + 1);
    ...                executionData.executionPath.push(`call:${funcName}`);
    ...                
    ...                try {
    ...                    return original.apply(this, args);
    ...                } catch (error) {
    ...                    executionData.errors.push(`Function ${funcName} error: ${error.message}`);
    ...                    throw error;
    ...                }
    ...            };
    ...        }
    ...    }
    ...    
    ...    // DOM manipulation monitoring
    ...    if (typeof document !== 'undefined') {
    ...        const originalQuerySelector = document.querySelector;
    ...        const originalGetElementById = document.getElementById;
    ...        const originalAddEventListener = Element.prototype.addEventListener;
    ...        
    ...        document.querySelector = function(...args) {
    ...            executionData.domManipulations.push(`querySelector: ${args[0]}`);
    ...            return originalQuerySelector.apply(this, args);
    ...        };
    ...        
    ...        document.getElementById = function(...args) {
    ...            executionData.domManipulations.push(`getElementById: ${args[0]}`);
    ...            return originalGetElementById.apply(this, args);
    ...        };
    ...        
    ...        Element.prototype.addEventListener = function(...args) {
    ...            executionData.eventHandlers.push(`${args[0]} on ${this.tagName || 'unknown'}`);
    ...            return originalAddEventListener.apply(this, args);
    ...        };
    ...    }
    ...    
    ...    try {
    ...        // Execute user code
    ...        ${user_code}
    ...        
    ...        // Convert Map to Object for JSON serialization
    ...        const serializedData = {
    ...            functionCalls: Object.fromEntries(executionData.functionCalls),
    ...            recursionDepth: Object.fromEntries(executionData.recursionDepth),
    ...            loopIterations: Object.fromEntries(executionData.loopIterations),
    ...            domManipulations: executionData.domManipulations,
    ...            eventHandlers: executionData.eventHandlers,
    ...            executionPath: executionData.executionPath,
    ...            errors: executionData.errors
    ...        };
    ...        
    ...        console.log("EXECUTION_DATA_START");
    ...        console.log(JSON.stringify(serializedData));
    ...        console.log("EXECUTION_DATA_END");
    ...        
    ...    } catch (error) {
    ...        executionData.errors.push(`Global execution error: ${error.message}`);
    ...        console.log("EXECUTION_DATA_START");
    ...        console.log(JSON.stringify({
    ...            functionCalls: Object.fromEntries(executionData.functionCalls),
    ...            recursionDepth: Object.fromEntries(executionData.recursionDepth),
    ...            loopIterations: Object.fromEntries(executionData.loopIterations),
    ...            domManipulations: executionData.domManipulations,
    ...            eventHandlers: executionData.eventHandlers,
    ...            executionPath: executionData.executionPath,
    ...            errors: executionData.errors
    ...        }));
    ...        console.log("EXECUTION_DATA_END");
    ...    }
    
    RETURN    ${instrumentation_code}

Execute Code In Sandbox
    [Arguments]    ${instrumented_code}    ${language}    ${test_inputs}
    [Documentation]    Execute instrumented code in secure sandbox environment
    
    ${execution_results}    Create List
    
    FOR    ${test_input}    IN    @{test_inputs}
        ${input_data}    Get From Dictionary    ${test_input}    input    default=${EMPTY}
        ${expected_output}    Get From Dictionary    ${test_input}    expected_output    default=${EMPTY}
        
        IF    '${language}' == 'python'
            ${result}    Execute Python In Sandbox    ${instrumented_code}    ${input_data}
        ELSE IF    '${language}' == 'javascript'
            ${result}    Execute JavaScript In Sandbox    ${instrumented_code}    ${input_data}
        END
        
        # Parse execution data from result
        ${execution_data}    Extract Execution Data    ${result}
        ${test_result}    Create Dictionary
        ...    input=${input_data}
        ...    expected_output=${expected_output}
        ...    actual_output=${result}[output]
        ...    execution_data=${execution_data}
        ...    success=${result}[success]
        
        Append To List    ${execution_results}    ${test_result}
    END
    
    RETURN    ${execution_results}

Execute Python In Sandbox
    [Arguments]    ${code}    ${input_data}
    [Documentation]    Execute Python code in isolated environment
    
    # Create temporary file for code execution
    ${code_file}    Set Variable    ${SANDBOX_DIR}/temp_code.py
    ${input_file}    Set Variable    ${SANDBOX_DIR}/input.txt
    
    Create File    ${code_file}    ${code}
    IF    '${input_data}' != ''
        Create File    ${input_file}    ${input_data}
    END
    
    # Execute in sandbox
    ${python_path}    Set Variable    ${SANDBOX_DIR}/python_env/bin/python
    
    IF    '${input_data}' != ''
        ${result}    Run Process    ${python_path}    ${code_file}
        ...    stdin=${input_file}    timeout=${TIMEOUT}    stderr=STDOUT
    ELSE
        ${result}    Run Process    ${python_path}    ${code_file}
        ...    timeout=${TIMEOUT}    stderr=STDOUT
    END
    
    ${success}    Set Variable    ${result.rc == 0}
    ${output}    Set Variable    ${result.stdout}
    
    # Cleanup
    Remove File    ${code_file}
    Run Keyword If    '${input_data}' != ''    Remove File    ${input_file}
    
    ${execution_result}    Create Dictionary
    ...    success=${success}
    ...    output=${output}
    ...    return_code=${result.rc}
    
    RETURN    ${execution_result}

Execute JavaScript In Sandbox
    [Arguments]    ${code}    ${input_data}
    [Documentation]    Execute JavaScript code in Node.js sandbox
    
    # Create temporary file for code execution
    ${code_file}    Set Variable    ${SANDBOX_DIR}/temp_code.js
    Create File    ${code_file}    ${code}
    
    # Execute with Node.js
    ${result}    Run Process    node    ${code_file}
    ...    timeout=${TIMEOUT}    stderr=STDOUT
    
    ${success}    Set Variable    ${result.rc == 0}
    ${output}    Set Variable    ${result.stdout}
    
    # Cleanup
    Remove File    ${code_file}
    
    ${execution_result}    Create Dictionary
    ...    success=${success}
    ...    output=${output}
    ...    return_code=${result.rc}
    
    RETURN    ${execution_result}

Extract Execution Data
    [Arguments]    ${execution_result}
    [Documentation]    Extract instrumentation data from execution output
    
    ${output}    Get From Dictionary    ${execution_result}    output
    
    # Find execution data markers
    ${start_marker}    Set Variable    EXECUTION_DATA_START
    ${end_marker}    Set Variable    EXECUTION_DATA_END
    
    TRY
        ${start_index}    Get Index From List    ${output.split('\n')}    ${start_marker}
        ${end_index}    Get Index From List    ${output.split('\n')}    ${end_marker}
        
        ${data_lines}    Get Slice From List    ${output.split('\n')}    ${start_index + 1}    ${end_index}
        ${data_json}    Evaluate    '\n'.join($data_lines)
        ${execution_data}    Evaluate    json.loads($data_json)    json
        
        RETURN    ${execution_data}
    EXCEPT
        Log    Could not extract execution data from output
        ${empty_data}    Create Dictionary
        ...    function_calls=${{}}
        ...    recursion_depth=${{}}
        ...    loop_iterations=${{}}
        ...    execution_path=@{EMPTY}
        ...    errors=@{EMPTY}
        RETURN    ${empty_data}
    END

Analyze Behavioral Requirements
    [Arguments]    ${execution_results}    ${behavioral_requirements}
    [Documentation]    Analyze execution data against behavioral requirements
    
    ${analysis_results}    Create Dictionary
    
    FOR    ${requirement}    IN    @{behavioral_requirements}
        ${requirement_type}    Get From Dictionary    ${requirement}    type
        ${analysis_result}    Analyze Single Requirement    ${execution_results}    ${requirement}
        Set To Dictionary    ${analysis_results}    ${requirement_type}    ${analysis_result}
    END
    
    RETURN    ${analysis_results}

Analyze Single Requirement
    [Arguments]    ${execution_results}    ${requirement}
    [Documentation]    Analyze a single behavioral requirement
    
    ${requirement_type}    Get From Dictionary    ${requirement}    type
    ${criteria}    Get From Dictionary    ${requirement}    criteria
    
    IF    '${requirement_type}' == 'recursion'
        ${result}    Analyze Recursion Requirement    ${execution_results}    ${criteria}
    ELSE IF    '${requirement_type}' == 'loops'
        ${result}    Analyze Loop Requirement    ${execution_results}    ${criteria}
    ELSE IF    '${requirement_type}' == 'function_calls'
        ${result}    Analyze Function Call Requirement    ${execution_results}    ${criteria}
    ELSE IF    '${requirement_type}' == 'dom_manipulation'
        ${result}    Analyze DOM Manipulation Requirement    ${execution_results}    ${criteria}
    ELSE
        ${result}    Create Dictionary    satisfied=${False}    reason=Unknown requirement type
    END
    
    RETURN    ${result}

Analyze Recursion Requirement
    [Arguments]    ${execution_results}    ${criteria}
    [Documentation]    Check if code demonstrates recursion
    
    ${min_recursive_calls}    Get From Dictionary    ${criteria}    min_calls    default=2
    ${function_name}    Get From Dictionary    ${criteria}    function_name    default=${EMPTY}
    
    FOR    ${test_result}    IN    @{execution_results}
        ${execution_data}    Get From Dictionary    ${test_result}    execution_data
        ${recursion_depth}    Get From Dictionary    ${execution_data}    recursion_depth    default=${{}}
        
        IF    '${function_name}' != ''
            ${recursive_calls}    Get From Dictionary    ${recursion_depth}    ${function_name}    default=0
            IF    ${recursive_calls} >= ${min_recursive_calls}
                ${result}    Create Dictionary    
                ...    satisfied=${True}    
                ...    details=Function ${function_name} recursed ${recursive_calls} times
                RETURN    ${result}
            END
        ELSE
            # Check any function for recursion
            FOR    ${func_name}    ${call_count}    IN    &{recursion_depth}
                IF    ${call_count} >= ${min_recursive_calls}
                    ${result}    Create Dictionary    
                    ...    satisfied=${True}    
                    ...    details=Function ${func_name} recursed ${call_count} times
                    RETURN    ${result}
                END
            END
        END
    END
    
    ${result}    Create Dictionary    
    ...    satisfied=${False}    
    ...    reason=No recursive function calls detected
    RETURN    ${result}

Analyze Loop Requirement
    [Arguments]    ${execution_results}    ${criteria}
    [Documentation]    Check if code uses loops appropriately
    
    ${required_loop_types}    Get From Dictionary    ${criteria}    loop_types    default=${{ ['for', 'while'] }}
    ${min_iterations}    Get From Dictionary    ${criteria}    min_iterations    default=1
    
    FOR    ${test_result}    IN    @{execution_results}
        ${execution_data}    Get From Dictionary    ${test_result}    execution_data
        ${loop_iterations}    Get From Dictionary    ${execution_data}    loop_iterations    default=${{}}
        
        FOR    ${loop_type}    IN    @{required_loop_types}
            ${iterations}    Get From Dictionary    ${loop_iterations}    ${loop_type}    default=0
            IF    ${iterations} >= ${min_iterations}
                ${result}    Create Dictionary    
                ...    satisfied=${True}    
                ...    details=${loop_type} loop executed ${iterations} times
                RETURN    ${result}
            END
        END
    END
    
    ${result}    Create Dictionary    
    ...    satisfied=${False}    
    ...    reason=Required loop patterns not detected
    RETURN    ${result}

Analyze Function Call Requirement
    [Arguments]    ${execution_results}    ${criteria}
    [Documentation]    Check if required functions are called
    
    ${required_functions}    Get From Dictionary    ${criteria}    functions
    ${all_satisfied}    Set Variable    ${True}
    ${details}    Create List
    
    FOR    ${required_func}    IN    @{required_functions}
        ${func_name}    Get From Dictionary    ${required_func}    name
        ${min_calls}    Get From Dictionary    ${required_func}    min_calls    default=1
        ${func_found}    Set Variable    ${False}
        
        FOR    ${test_result}    IN    @{execution_results}
            ${execution_data}    Get From Dictionary    ${test_result}    execution_data
            ${function_calls}    Get From Dictionary    ${execution_data}    function_calls    default=${{}}
            ${call_count}    Get From Dictionary    ${function_calls}    ${func_name}    default=0
            
            IF    ${call_count} >= ${min_calls}
                ${func_found}    Set Variable    ${True}
                Append To List    ${details}    Function ${func_name} called ${call_count} times
                BREAK
            END
        END
        
        IF    not ${func_found}
            ${all_satisfied}    Set Variable    ${False}
            Append To List    ${details}    Function ${func_name} not called enough times
        END
    END
    
    ${result}    Create Dictionary    
    ...    satisfied=${all_satisfied}    
    ...    details=${details}
    RETURN    ${result}

Analyze DOM Manipulation Requirement
    [Arguments]    ${execution_results}    ${criteria}
    [Documentation]    Check if code manipulates DOM appropriately
    
    ${required_operations}    Get From Dictionary    ${criteria}    operations
    ${all_satisfied}    Set Variable    ${True}
    ${details}    Create List
    
    FOR    ${operation}    IN    @{required_operations}
        ${op_found}    Set Variable    ${False}
        
        FOR    ${test_result}    IN    @{execution_results}
            ${execution_data}    Get From Dictionary    ${test_result}    execution_data
            ${dom_manipulations}    Get From Dictionary    ${execution_data}    domManipulations    default=@{EMPTY}
            
            FOR    ${manipulation}    IN    @{dom_manipulations}
                ${contains_operation}    Run Keyword And Return Status    Should Contain    ${manipulation}    ${operation}
                IF    ${contains_operation}
                    ${op_found}    Set Variable    ${True}
                    Append To List    ${details}    DOM operation ${operation} detected: ${manipulation}
                    BREAK
                END
            END
            
            IF    ${op_found}
                BREAK
            END
        END
        
        IF    not ${op_found}
            ${all_satisfied}    Set Variable    ${False}
            Append To List    ${details}    Required DOM operation ${operation} not found
        END
    END
    
    ${result}    Create Dictionary    
    ...    satisfied=${all_satisfied}    
    ...    details=${details}
    RETURN    ${result}

Run Dynamic Test Suite
    [Arguments]    ${user_code}    ${language}    ${test_definition}
    [Documentation]    Execute complete dynamic test suite
    
    Log    Starting dynamic test execution for ${language} code
    
    # Extract test configuration
    ${test_inputs}    Get From Dictionary    ${test_definition}    test_cases
    ${behavioral_requirements}    Get From Dictionary    ${test_definition}    behavioral_requirements
    ${instrumentation_config}    Get From Dictionary    ${test_definition}    instrumentation
    
    # Create instrumented code
    ${instrumented_code}    Create Instrumented Code Wrapper    ${user_code}    ${language}    ${instrumentation_config}
    
    # Execute tests
    ${execution_results}    Execute Code In Sandbox    ${instrumented_code}    ${language}    ${test_inputs}
    
    # Analyze behavioral requirements
    ${behavioral_analysis}    Analyze Behavioral Requirements    ${execution_results}    ${behavioral_requirements}
    
    # Compile final results
    ${test_results}    Create Dictionary
    ...    execution_results=${execution_results}
    ...    behavioral_analysis=${behavioral_analysis}
    ...    language=${language}
    ...    total_tests=${{ len($test_inputs) }}
    ...    passed_tests=${{ len([r for r in $execution_results if r['success']]) }}
    
    # Calculate scores
    ${correctness_score}    Calculate Correctness Score    ${execution_results}
    ${behavioral_score}    Calculate Behavioral Score    ${behavioral_analysis}
    
    Set To Dictionary    ${test_results}    correctness_score    ${correctness_score}
    Set To Dictionary    ${test_results}    behavioral_score    ${behavioral_score}
    Set To Dictionary    ${test_results}    overall_score    ${{ (${correctness_score} + ${behavioral_score}) / 2 }}
    
    RETURN    ${test_results}

Calculate Correctness Score
    [Arguments]    ${execution_results}
    [Documentation]    Calculate score based on test case correctness
    
    ${total_tests}    Get Length    ${execution_results}
    ${passed_tests}    Set Variable    0
    
    FOR    ${result}    IN    @{execution_results}
        ${success}    Get From Dictionary    ${result}    success
        ${actual_output}    Get From Dictionary    ${result}    actual_output
        ${expected_output}    Get From Dictionary    ${result}    expected_output
        
        # Check both execution success and output correctness
        IF    ${success}
            ${output_matches}    Run Keyword And Return Status    Should Contain    ${actual_output}    ${expected_output}
            IF    ${output_matches}
                ${passed_tests}    Evaluate    ${passed_tests} + 1
            END
        END
    END
    
    ${score}    Evaluate    ${passed_tests} / ${total_tests} * 100 if ${total_tests} > 0 else 0
    RETURN    ${score}

Calculate Behavioral Score
    [Arguments]    ${behavioral_analysis}
    [Documentation]    Calculate score based on behavioral requirement satisfaction
    
    ${total_requirements}    Get Length    ${behavioral_analysis}
    ${satisfied_requirements}    Set Variable    0
    
    FOR    ${requirement_type}    ${analysis}    IN    &{behavioral_analysis}
        ${satisfied}    Get From Dictionary    ${analysis}    satisfied
        IF    ${satisfied}
            ${satisfied_requirements}    Evaluate    ${satisfied_requirements} + 1
        END
    END
    
    ${score}    Evaluate    ${satisfied_requirements} / ${total_requirements} * 100 if ${total_requirements} > 0 else 0
    RETURN    ${score}

Cleanup Dynamic Testing Environment
    [Documentation]    Clean up sandbox and temporary files
    Remove Directory    ${SANDBOX_DIR}    recursive=True

*** Test Cases ***
Dynamic Code Testing Example
    [Documentation]    Example of dynamic testing with instrumentation
    [Setup]    Initialize Dynamic Testing Environment
    [Teardown]    Cleanup Dynamic Testing Environment
    
    # Example test definition
    ${test_definition}    Create Dictionary
    ...    test_cases=@{[
    ...        {"input": "5", "expected_output": "120"},
    ...        {"input": "3", "expected_output": "6"},
    ...        {"input": "0", "expected_output": "1"}
    ...    ]}
    ...    behavioral_requirements=@{[
    ...        {
    ...            "type": "recursion",
    ...            "criteria": {"min_calls": 2, "function_name": "factorial"}
    ...        },
    ...        {
    ...            "type": "function_calls", 
    ...            "criteria": {"functions": [{"name": "factorial", "min_calls": 1}]}
    ...        }
    ...    ]}
    ...    instrumentation=${{
    ...        "monitor_functions": True,
    ...        "monitor_recursion": True,
    ...        "monitor_loops": False,
    ...        "monitor_classes": False
    ...    }}
    
    # Example user code (recursive factorial)
    ${user_code}    Set Variable    
    ...    def factorial(n):
    ...        if n <= 1:
    ...            return 1
    ...        return n * factorial(n - 1)
    ...    
    ...    import sys
    ...    if len(sys.argv) > 1:
    ...        n = int(sys.argv[1])
    ...    else:
    ...        n = int(input())
    ...    print(factorial(n))
    
    # Run dynamic test
    ${results}    Run Dynamic Test Suite    ${user_code}    python    ${test_definition}
    
    # Log results
    ${overall_score}    Get From Dictionary    ${results}    overall_score
    ${correctness_score}    Get From Dictionary    ${results}    correctness_score
    ${behavioral_score}    Get From Dictionary    ${results}    behavioral_score
    
    Log    Overall Score: ${overall_score}%
    Log    Correctness Score: ${correctness_score}%
    Log    Behavioral Score: ${behavioral_score}%
    
    # Save results
    ${results_json}    Evaluate    json.dumps($results, indent=2, default=str)    json
    Create File    ${RESULTS_DIR}/test_results.json    ${results_json}