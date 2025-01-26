*** Settings ***
Library           Collections
Library           OperatingSystem
Library           Process
Library           json

*** Variables ***
${STUDENTS_JSON}    students.json
${TEACHER_JSON}    teacher.json
${TEMP_DIR}        ./temp
${RESULTS_FILE}    comparison_results.json

# Language Execution Commands
${PYTHON_CMD}      python
${CPP_COMPILER}    g++
${RUST_COMPILER}   rustc
${JAVASCRIPT_CMD}  node

*** Keywords ***
Setup Test Environment
    Create Directory    ${TEMP_DIR}
    Log    Created temporary directory: ${TEMP_DIR}

Cleanup Test Environment
    Remove Directory    ${TEMP_DIR}    recursive=True
    Run Keyword If    File Exists    ${RESULTS_FILE}    Remove File    ${RESULTS_FILE}

Create Source File
    [Arguments]    ${code}    ${language}
    
    # Language-specific file extensions
    ${ext}    Set Variable If    
    ...    '${language}' == 'python'    .py
    ...    '${language}' == 'cpp'       .cpp
    ...    '${language}' == 'rust'      .rs
    ...    '${language}' == 'javascript'    .js
    ...    '${language}' == 'java'      .java
    ...    .txt
    
    # Generate unique filename
    ${filename}    Evaluate    f'code_{random.randint(1000, 9999)}'    modules=random
    ${full_path}    Set Variable    ${TEMP_DIR}/${filename}${ext}
    
    Create File    ${full_path}    ${code}
    Log    Created ${language} source file: ${full_path}
    RETURN    ${full_path}

Execute Python Code
    [Arguments]    ${file_path}
    ${result}    Run Process    ${PYTHON_CMD}    ${file_path}    shell=True    stderr=STDOUT
    RETURN    ${result}

Execute JavaScript Code
    [Arguments]    ${file_path}
    ${result}    Run Process    ${JAVASCRIPT_CMD}    ${file_path}    shell=True    stderr=STDOUT
    RETURN    ${result}

Compile And Execute CPP Code
    [Arguments]    ${file_path}
    ${compile_result}    Run Process    ${CPP_COMPILER}    ${file_path}    -o    ${file_path}.out    shell=True    stderr=STDOUT
    Run Keyword If    ${compile_result.rc} != 0    Fail    C++ Compilation Failed: ${compile_result.stderr}
    
    ${result}    Run Process    ${file_path}.out    shell=True    stderr=STDOUT
    RETURN    ${result}

Compile And Execute Rust Code
    [Arguments]    ${file_path}
    ${compile_result}    Run Process    ${RUST_COMPILER}    ${file_path}    -o    ${file_path}.out    shell=True    stderr=STDOUT
    Run Keyword If    ${compile_result.rc} != 0    Fail    Rust Compilation Failed: ${compile_result.stderr}
    
    ${result}    Run Process    ${file_path}.out    shell=True    stderr=STDOUT
    RETURN    ${result}

Execute Code
    [Arguments]    ${file_path}    ${language}
    
    ${result}    Run Keyword If    
    ...    '${language}' == 'python'    Execute Python Code    ${file_path}
    ...    ELSE IF    '${language}' == 'javascript'    Execute JavaScript Code    ${file_path}
    ...    ELSE IF    '${language}' == 'cpp'    Compile And Execute CPP Code    ${file_path}
    ...    ELSE IF    '${language}' == 'rust'    Compile And Execute Rust Code    ${file_path}
    ...    ELSE    Fail    Unsupported language: ${language}
    
    RETURN    ${result}

Prepare Comparison Results
    [Arguments]    ${students}    ${student_result}    ${teacher_result}    ${teacher_data}
    
    # Normalize outputs
    ${student_output}    Set Variable    ${student_result.stdout.strip()}
    ${teacher_output}    Set Variable    ${teacher_result.stdout.strip()}
    
    # Flexible comparison: check if outputs are numerically equivalent
    ${test_status}    Evaluate    
    ...    'PASS' if float(${student_output}) == float(${teacher_output}) else 'FAIL'

    # Create results dictionary
    ${result}    Create Dictionary
    ...    status=${test_status}
    ...    details=${students}[title]
    ...    language=${students}[language]
    ...    student_output=${student_output}
    ...    teacher_output=${teacher_output}
    ...    student_code=${students}[defaultCode]
    ...    teacher_code=${teacher_data}[defaultCode]
    ...    student_exit_code=${student_result.rc}
    ...    teacher_exit_code=${teacher_result.rc}
    ...    student_stderr=${student_result.stderr}
    ...    teacher_stderr=${teacher_result.stderr}

    # Write results to file
    ${results}    Create List    ${result}
    ${json_string}    Evaluate    json.dumps($results, indent=2)    json
    Create File    ${RESULTS_FILE}    ${json_string}
    
    RETURN    ${result}

*** Test Cases ***
Compare Student And Teacher Default Codes
    # Setup
    Setup Test Environment
    [Teardown]    Cleanup Test Environment
    
    # Read JSON files
    ${students_data}    Evaluate    json.load(open('${STUDENTS_JSON}'))    json
    ${teacher_data}    Evaluate    json.load(open('${TEACHER_JSON}'))    json
    
    # Extract codes and language
    ${language}    Set Variable    ${students_data['language'].lower()}
    ${student_code}    Set Variable    ${students_data['defaultCode']}
    ${teacher_code}    Set Variable    ${teacher_data['defaultCode']}
    
    # Create source files
    ${student_file}    Create Source File    ${student_code}    ${language}
    ${teacher_file}    Create Source File    ${teacher_code}    ${language}
    
    # Execute codes
    ${student_result}    Execute Code    ${student_file}    ${language}
    ${teacher_result}    Execute Code    ${teacher_file}    ${language}
    
    # Prepare and verify results
    ${comparison_result}    Prepare Comparison Results    ${students_data}    ${student_result}    ${teacher_result}    ${teacher_data}
    
    # Assertions
    Should Be Equal As Integers    ${student_result.rc}    0    msg=Student code execution failed
    Should Be Equal As Integers    ${teacher_result.rc}    0    msg=Teacher code execution failed
    
    # Use numerical comparison instead of strict string comparison
    ${student_num}    Convert To Number    ${student_result.stdout.strip()}
    ${teacher_num}    Convert To Number    ${teacher_result.stdout.strip()}
    Should Be Equal    ${student_num}    ${teacher_num}    msg=Outputs differ
    
    # Cleanup
    Cleanup Test Environment