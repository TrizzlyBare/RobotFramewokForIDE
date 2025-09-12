# Dynamic Testing System - Usage Guide

## Quick Start

The Dynamic Testing System provides a comprehensive platform for testing student code submissions with behavioral verification and sandboxed execution.

**IMPORTANT**: This system uses only the essential components after cleanup:

- `DynamicTestingFramework.robot` - Core execution engine
- `IntegratedTestRunner.robot` - Main orchestrator
- `test_definitions/*.json` - Lesson configurations

## Installation & Setup

1. **Prerequisites**:

   ```bash
   pip install robotframework
   pip install robotframework-jsonlibrary
   ```

2. **System Validation** (includes cleanup verification):
   ```bash
   python main.py --list-lessons
   ```
   The system will warn if any obsolete files are detected in NewDevelopment/.

## Command Line Usage

### Basic Testing

```bash
# Test a recursive factorial submission
python main.py --lesson-id recursion_factorial --submission examples/factorial_submission.json

# Test web development submission
python main.py --lesson-id dom_manipulation_interactive_button --submission examples/web_submission.json

# Force specific testing mode
python main.py --lesson-id loops_array_processing --submission code_submission.json --mode code
```

### System Management

```bash
# List all available lessons
python main.py --list-lessons

# Validate a test definition
python main.py --validate-definition recursion_factorial

# Save detailed results to file
python main.py --lesson-id recursion_factorial --submission student_code.json --output results.json

# Enable verbose logging
python main.py --lesson-id recursion_factorial --submission student_code.json --verbose
```

## Submission File Formats

### Code Submission (Python/JavaScript)

```json
{
  "submission_type": "code",
  "language": "python",
  "code": "def factorial(n):\n    if n <= 1:\n        return 1\n    return n * factorial(n - 1)\n\nn = int(input())\nprint(factorial(n))",
  "student_id": "student123",
  "submission_time": "2024-01-15T10:30:00Z"
}
```

### Web Development Submission

```json
{
  "submission_type": "web_development",
  "html": "<button id=\"btn\">Click Me</button>",
  "css": "#btn { background: blue; color: white; }",
  "javascript": "document.getElementById('btn').addEventListener('click', () => alert('Hi'));",
  "student_id": "student456",
  "submission_time": "2024-01-15T11:15:00Z"
}
```

## Testing Modes

### Code Execution Mode

- **Purpose**: Test algorithms, data structures, and programming logic
- **Features**:
  - Sandboxed execution in virtual environments
  - Behavioral analysis (recursion, loops, function calls)
  - Anti-cheat protection against built-in function usage
  - Memory and timeout limits

### Web Testing Mode

- **Purpose**: Test HTML, CSS, and JavaScript for web development
- **Features**:
  - DOM manipulation verification
  - Event handling validation
  - Browser interaction simulation
  - CSS styling verification

## Creating Custom Test Definitions

### Step 1: Create JSON Definition

Create a new file in `NewDevelopment/test_definitions/your_lesson.json`:

```json
{
  "lesson_id": "your_lesson",
  "title": "Your Lesson Title",
  "description": "Description of what students should implement",

  "test_cases": [
    {
      "name": "basic_test",
      "input": "test_input",
      "expected_output": "expected_result",
      "description": "What this test verifies"
    }
  ],

  "behavioral_requirements": [
    {
      "type": "recursion",
      "name": "must_use_recursion",
      "description": "Function must use recursive calls",
      "criteria": {
        "function_name": "your_function",
        "min_calls": 2,
        "required": true
      },
      "points": 40
    }
  ],

  "execution_environment": {
    "language": "python",
    "timeout_seconds": 10,
    "forbidden_patterns": ["built_in_function"]
  },

  "grading": {
    "correctness_weight": 0.6,
    "behavioral_weight": 0.4,
    "passing_threshold": 70
  }
}
```

### Step 2: Validate Definition

```bash
python main.py --validate-definition your_lesson
```

### Step 3: Test with Sample Submission

```bash
python main.py --lesson-id your_lesson --submission sample_submission.json
```

## Understanding Results

### Score Breakdown

- **Correctness Score**: Based on test case pass/fail
- **Behavioral Score**: Based on concept demonstration
- **Overall Score**: Weighted combination of above scores

### Result Status

- **PASSED**: Overall score ≥ 70%
- **FAILED**: Overall score < 70%
- **ERROR**: System error during execution
- **TIMEOUT**: Code execution exceeded time limit

### Sample Output

```
==================================================
DYNAMIC TESTING SYSTEM - RESULTS SUMMARY
==================================================
Lesson ID: recursion_factorial
Testing Mode: code
Execution Time: 20240115_103000
Overall Score: 85%
Status: PASSED

BEHAVIORAL ANALYSIS:
--------------------
must_use_recursion: ✅ PASSED
  - Function factorial recursed 4 times
correct_function_definition: ✅ PASSED
  - Function factorial called 1 times

SCORE BREAKDOWN:
---------------
Correctness: 80%
Behavioral: 90%

FEEDBACK:
---------
Good job! Your solution is solid with minor areas for improvement.
==================================================
```

## Advanced Features

### Environment Variables

The main script accepts these environment variables:

- `ROBOT_FRAMEWORK_PATH`: Custom Robot Framework installation path
- `TESTING_TIMEOUT`: Global timeout for test execution (default: 300s)
- `SANDBOX_CLEANUP`: Auto-cleanup sandbox directories (default: true)

### Integration with LMS

The system is designed for easy LMS integration:

```python
from main import DynamicTestingSystem

# Initialize system
system = DynamicTestingSystem()

# Execute test
results = system.execute_test_suite(lesson_id, submission_data)

# Extract key metrics
overall_score = results['overall_score']
feedback = results['feedback']['performance_message']
detailed_analysis = results['behavioral_analysis']
```

### Batch Processing

For processing multiple submissions:

```bash
# Process all submissions in a directory
for file in submissions/*.json; do
    python main.py --lesson-id recursion_factorial --submission "$file" --output "results/$(basename "$file")"
done
```

## Troubleshooting

### Common Issues

1. **Robot Framework Not Found**

   ```bash
   pip install robotframework
   # Ensure 'robot' command is in PATH
   ```

2. **Test Definition Invalid**

   ```bash
   python main.py --validate-definition lesson_name
   # Check JSON syntax and required fields
   ```

3. **Submission Format Error**

   - Ensure JSON is valid
   - Check required fields (code/html/css/javascript)
   - Verify submission_type matches lesson requirements

4. **Timeout Errors**
   - Reduce complexity of test cases
   - Check for infinite loops in student code
   - Increase timeout in test definition

### Log Files

- System logs: `testing_system.log`
- Robot Framework logs: `test_results/log_*.html`
- Detailed output: `test_results/output_*.xml`

## Security Considerations

The system implements multiple security layers:

- **Sandboxed Execution**: Code runs in isolated virtual environments
- **Resource Limits**: Memory and CPU constraints prevent abuse
- **Network Isolation**: No external network access during testing
- **File System Restrictions**: Limited to designated directories
- **Input Validation**: All submissions are validated and sanitized

## Performance Tips

1. **Optimize Test Definitions**: Minimize number of test cases for faster execution
2. **Use Timeouts**: Set appropriate timeout values for different lesson types
3. **Clean Results**: Regularly clean old result files to save disk space
4. **Monitor Resources**: Watch system memory and CPU usage during batch processing

## Support and Development

For issues, feature requests, or contributions:

1. Check the log files for detailed error information
2. Validate test definitions and submission formats
3. Ensure all dependencies are installed correctly
4. Review the Robot Framework documentation for advanced customization
