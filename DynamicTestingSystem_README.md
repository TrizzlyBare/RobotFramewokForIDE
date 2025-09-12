# Dynamic Testing System for Ed-Tech Platform

## Overview

This comprehensive dynamic testing system transforms static code analysis into true behavioral verification through **code execution sandboxing** and **instrumentation**. Unlike traditional systems that rely on pattern matching, this framework actually runs student code in controlled environments and monitors execution behavior to verify learning objectives.

## System Architecture

### Core Principles

1. **Code Execution Sandbox**: All code runs in isolated, secure environments preventing malicious access
2. **Behavioral Instrumentation**: Code is wrapped with monitoring to track function calls, recursion, loops, and DOM manipulation
3. **Dynamic Test Definitions**: JSON-based lesson configurations drive test generation without modifying core engine
4. **Multi-Language Support**: Handles Python, JavaScript, and web development (HTML/CSS/JS)
5. **Headless Browser Integration**: Real browser automation for web development testing

### Key Components

#### 1. Dynamic Testing Framework (`DynamicTestingFramework.robot`)

**Code Execution Sandbox**

- Isolated Python virtual environments for secure code execution
- Node.js sandbox for JavaScript testing
- Resource limits (memory, timeout) prevent abuse
- Input/output capture and monitoring

**Instrumentation Engine**

```python
# Python instrumentation example
def trace_function_calls(frame, event, arg):
    if event == 'call':
        func_name = frame.f_code.co_name
        execution_data['function_calls'][func_name] += 1
        # Check for recursion by analyzing call stack
        if func_name in [f.f_code.co_name for f in get_stack_frames(frame.f_back)]:
            execution_data['recursion_depth'][func_name] += 1
```

**JavaScript DOM Monitoring**

```javascript
// Intercept DOM operations
const originalGetElementById = document.getElementById;
document.getElementById = function (id) {
  executionData.domOperations.push("getElementById:" + id);
  return originalGetElementById.call(this, id);
};
```

#### 2. JSON Test Definitions (`test_definitions/`)

**Lesson Configuration Structure**

```json
{
  "lesson_id": "recursion_factorial",
  "test_cases": [{ "input": "5", "expected_output": "120" }],
  "behavioral_requirements": [
    {
      "type": "recursion",
      "criteria": { "function_name": "factorial", "min_calls": 2 }
    }
  ],
  "instrumentation": {
    "monitor_recursion": true,
    "monitor_functions": true
  }
}
```

#### 3. Integrated Test Runner (`IntegratedTestRunner.robot`)

**Intelligent Test Mode Selection**

- Analyzes test definition to determine execution approach
- Code execution mode for algorithms and logic
- Browser testing mode for web development
- Hybrid mode for full-stack applications

**Behavioral Analysis Engine**

- Function call monitoring and recursion detection
- Loop iteration tracking and pattern analysis
- DOM manipulation verification
- Event handling validation

## Dynamic Testing Capabilities

### 1. Recursion Detection

**Traditional Approach (Static)**: Search for function name in code

```python
# Fails to detect: This isn't actually recursive
def factorial(n):
    return math.factorial(n)  # Uses built-in, no recursion
```

**Dynamic Approach (Behavioral)**:

```python
# Instruments code execution to track call stack
# Only passes if function actually calls itself
execution_data['recursion_depth']['factorial'] = 3  # Actual recursive calls
```

**Test Definition Example**:

```json
{
  "type": "recursion",
  "criteria": {
    "function_name": "factorial",
    "min_calls": 2,
    "required": true
  }
}
```

### 2. Loop Analysis

**Problem**: Student uses built-in functions instead of loops

```python
# Should fail loop requirement
def sum_array(arr):
    return sum(arr)  # No actual loop
```

**Dynamic Detection**:

```python
# AST analysis + execution monitoring
class LoopAnalyzer(ast.NodeVisitor):
    def visit_For(self, node):
        execution_data['loop_iterations']['for'] += 1
```

**Enforcement**: Test definition can forbid built-in functions

```json
{
  "execution_environment": {
    "forbidden_patterns": ["sum\\(", "reduce\\("]
  }
}
```

### 3. Web Development Testing

**DOM Manipulation Verification**

```javascript
// Monitors actual DOM operations
document.querySelector = function (selector) {
  testData.domOperations.push("querySelector:" + selector);
  return originalQuerySelector.call(this, selector);
};
```

**Browser Action Sequences**

```json
{
  "browser_actions": [
    { "action": "click", "target": "#button" },
    { "action": "verify_text", "target": "#result", "expected": "Clicked!" }
  ]
}
```

### 4. Function Call Monitoring

**Tracks All Function Invocations**

```python
# Verifies specific functions are called with minimum frequency
{
  "type": "function_calls",
  "criteria": {
    "functions": [
      {"name": "helper_function", "min_calls": 1}
    ]
  }
}
```

## Security & Sandboxing

### Execution Isolation

- **Virtual Environments**: Separate Python environments per test
- **Resource Limits**: Memory and time constraints prevent abuse
- **Network Isolation**: No external network access during execution
- **File System Restrictions**: Limited to designated sandbox directories

### Malicious Code Prevention

```python
# Timeout protection
result = Run Process    python    code.py    timeout=10s

# Memory limits through virtual environment configuration
# Input validation and sanitization
```

### Safe Instrumentation

- Instrumentation code is pre-validated and secure
- Student code cannot access instrumentation functions
- All monitoring data is collected safely without exposing system internals

## Test Definition Examples

### 1. Recursive Factorial (`recursion_factorial.json`)

```json
{
  "lesson_id": "recursion_factorial",
  "test_cases": [
    { "input": "5", "expected_output": "120" },
    { "input": "0", "expected_output": "1" }
  ],
  "behavioral_requirements": [
    {
      "type": "recursion",
      "criteria": { "function_name": "factorial", "min_calls": 2 }
    }
  ],
  "execution_environment": {
    "forbidden_patterns": ["math.factorial", "itertools"]
  }
}
```

### 2. Loop-Based Array Processing (`loops_array_processing.json`)

```json
{
  "behavioral_requirements": [
    {
      "type": "loops",
      "criteria": { "loop_types": ["for", "while"], "min_iterations": 1 }
    },
    {
      "type": "no_built_in_functions",
      "criteria": { "forbidden_functions": ["sum", "reduce"] }
    }
  ]
}
```

### 3. Web DOM Manipulation (`dom_manipulation_interactive_button.json`)

```json
{
  "execution_environment": { "runtime": "browser" },
  "behavioral_requirements": [
    {
      "type": "dom_manipulation",
      "criteria": { "operations": ["getElementById", "addEventListener"] }
    }
  ],
  "browser_actions": [
    { "action": "click", "target": "#button" },
    { "action": "verify_text", "target": "#result", "expected": "Clicked!" }
  ]
}
```

## Usage Examples

### Running Dynamic Tests

```robot
# Initialize testing environment
Initialize Integrated Testing Environment

# Load test definition
${test_definition}    Load And Validate Test Definition    recursion_factorial

# Execute with student code
${user_submission}    Create Dictionary    code=${student_code}
${results}    Execute Integrated Test Suite    ${user_submission}    recursion_factorial

# Results include behavioral analysis
${behavioral_score}    Get From Dictionary    ${results}    behavioral_score
${correctness_score}   Get From Dictionary    ${results}    correctness_score
```

### Creating New Test Definitions

1. **Create JSON file** in `test_definitions/` directory
2. **Define test cases** with inputs and expected outputs
3. **Specify behavioral requirements** for concept verification
4. **Configure instrumentation** for execution monitoring
5. **Set execution environment** constraints and security

### Web Testing Integration

```robot
# Web submission format
${web_submission}    Create Dictionary
...    html=<button id="btn">Click</button>
...    css=#btn { background: blue; }
...    javascript=document.getElementById('btn').onclick = () => alert('Hi');

# Automatic mode detection and appropriate testing
${results}    Execute Integrated Test Suite    ${web_submission}    dom_manipulation_interactive_button
```

## Advanced Features

### 1. Execution Path Tracking

- Monitors complete function call sequences
- Detects algorithmic approach even with different implementations
- Verifies logical flow matches learning objectives

### 2. Multi-Language Instrumentation

- Python: AST analysis + sys.settrace monitoring
- JavaScript: Function wrapping + DOM operation interception
- Web: Browser automation + client-side instrumentation

### 3. Intelligent Feedback Generation

- Context-aware feedback based on execution patterns
- Specific guidance for failed behavioral requirements
- Recognition of partial implementations and alternative approaches

### 4. Performance Monitoring

- Execution time analysis for algorithm efficiency
- Memory usage tracking
- Recursion depth monitoring for optimization lessons

## Benefits Over Static Analysis

### Traditional Static Testing Problems:

❌ **False Positives**: Code contains keyword but doesn't use concept  
❌ **Workarounds**: Students find unintended solutions  
❌ **Limited Scope**: Can't verify actual execution behavior  
❌ **No Interaction Testing**: Web elements exist but don't work

### Dynamic Testing Solutions:

✅ **Behavioral Verification**: Code must actually demonstrate concept  
✅ **Execution Validation**: Functions must be called and work correctly  
✅ **Interactive Testing**: Web elements must respond to user actions  
✅ **Learning Reinforcement**: Students practice intended skills

## Integration & Deployment

### LMS Integration

- JSON-based input/output for seamless API integration
- Configurable test definitions per lesson/assignment
- Rich feedback data for gradebook integration
- Progress tracking and analytics

### Scalability Features

- Parallel test execution for multiple submissions
- Resource pooling and cleanup automation
- Caching for repeated test scenarios
- Monitoring and alerting for system health

### Extensibility

- Plugin architecture for new programming languages
- Custom behavioral analyzers for specialized concepts
- Integration points for additional security scanning
- Hooks for learning analytics and adaptation

This dynamic testing system provides a robust, secure, and educationally effective platform that ensures students truly understand and can apply the programming concepts they're learning, rather than just producing code that looks correct.
