# Example: Interactive Button Click Assessment

## Scenario

Student task: Create a webpage with a button that changes text when clicked, demonstrating:

- HTML structure
- CSS styling
- JavaScript event handling
- DOM manipulation

## Student Submission

### HTML

```html
<div class="container">
  <h1>Interactive Demo</h1>
  <button id="clickBtn" class="btn-primary">Click Me!</button>
  <p id="message" class="hidden">Hello, World!</p>
</div>
```

### CSS

```css
.container {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 20px;
}

.btn-primary {
  background-color: #007bff;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 5px;
  cursor: pointer;
}

.btn-primary:hover {
  background-color: #0056b3;
}

.hidden {
  display: none;
}

.visible {
  display: block;
  color: #28a745;
  font-weight: bold;
}
```

### JavaScript

```javascript
document.addEventListener("DOMContentLoaded", function () {
  const button = document.getElementById("clickBtn");
  const message = document.getElementById("message");

  button.addEventListener("click", function () {
    message.classList.remove("hidden");
    message.classList.add("visible");
    button.textContent = "Clicked!";
  });
});
```

## Assessment Configuration

```json
{
  "lesson_type": "javascript_fundamentals",
  "test_config": {
    "html_tests": [
      {
        "tag": "button",
        "attributes": { "id": "clickBtn" },
        "content": ""
      },
      {
        "tag": "p",
        "attributes": { "id": "message" },
        "content": ""
      }
    ],
    "css_tests": [
      {
        "selector": ".container",
        "property": "display",
        "value": "flex"
      },
      {
        "selector": ".btn-primary",
        "property": "background-color",
        "value": "rgb(0, 123, 255)"
      }
    ],
    "interactions": [
      {
        "action": "click",
        "target": "#clickBtn",
        "verification": {
          "type": "text_content",
          "target": "#clickBtn",
          "expected": "Clicked!"
        }
      },
      {
        "action": "click",
        "target": "#clickBtn",
        "verification": {
          "type": "element_visible",
          "target": "#message",
          "expected": true
        }
      }
    ],
    "required_concepts": ["dom_manipulation", "event_handling", "functions"]
  }
}
```

## Expected Assessment Results

### Correctness Score: 100%

- ✅ All HTML elements present with correct attributes
- ✅ CSS styles applied correctly
- ✅ Button click interaction works as expected
- ✅ Message visibility toggle functions properly

### Concept Demonstration: 100%

- ✅ **DOM Manipulation**: Uses `getElementById`, `classList.remove/add`
- ✅ **Event Handling**: Implements `addEventListener` for click events
- ✅ **Functions**: Uses anonymous function and DOMContentLoaded

### Code Quality: 85%

- ✅ Modern JavaScript syntax (const, arrow functions)
- ✅ Semantic HTML structure
- ✅ CSS flexbox for layout
- ✅ Proper event listener attachment
- ⚠️ Could improve with more descriptive class names

### Final Score: 95%

**Result**: PASS (threshold: 70%)

## Generated Feedback

### Overall Assessment

> Excellent! Your solution passes all tests and demonstrates the required concepts effectively.

### Detailed Feedback

- ✅ **DOM Manipulation**: Great use of `getElementById` and `classList` methods
- ✅ **Event Handling**: Proper implementation of click event listener
- ✅ **Functions**: Good use of modern JavaScript function syntax
- ✅ **HTML Structure**: Well-structured semantic HTML
- ✅ **CSS Styling**: Effective use of flexbox for layout and hover effects

### Suggestions for Improvement

- Consider using more descriptive CSS class names for better maintainability
- Add aria-labels for better accessibility
- Consider using CSS transitions for smoother hover effects

## Robot Framework Test Execution

```robot
*** Test Cases ***
Button Click Interactive Assessment
    [Documentation]    Test student's button click implementation

    # Student submission data
    ${student_code}    Create Dictionary
    ...    html=<div class="container"><h1>Interactive Demo</h1><button id="clickBtn" class="btn-primary">Click Me!</button><p id="message" class="hidden">Hello, World!</p></div>
    ...    css=.container { display: flex; flex-direction: column; align-items: center; padding: 20px; } .btn-primary { background-color: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; } .hidden { display: none; } .visible { display: block; color: #28a745; font-weight: bold; }
    ...    javascript=document.addEventListener('DOMContentLoaded', function() { const button = document.getElementById('clickBtn'); const message = document.getElementById('message'); button.addEventListener('click', function() { message.classList.remove('hidden'); message.classList.add('visible'); button.textContent = 'Clicked!'; }); });

    # Run comprehensive assessment
    ${results}    Run Web Assessment With Parameters    javascript_fundamentals    ${student_code}

    # Verify results
    Should Be True    ${results}[passed]
    Should Be Equal As Numbers    ${results}[final_score]    0.95    precision=2

    Log    Assessment completed successfully: ${results}[feedback][overall_message]
```

This example demonstrates how the testing system evaluates a complete web development exercise, providing comprehensive feedback across all assessment dimensions.
