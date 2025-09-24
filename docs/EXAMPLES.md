# 📖 YOLOsandbox Examples

Learn by doing! These examples progress from simple to complex, showing you how to safely use AI for real coding tasks in your backyard sandbox.

## Before You Start

Make sure Docker is running and you're in the sandbox (your safe backyard playground):

```bash
# Check Docker is running
docker ps

# Enter the sandbox (if using command line)
docker-compose -f docker/docker-compose.yml exec simple-sandbox bash

# Or use VS Code: "Reopen in Container"
```

## Example 1: Hello World - Your First AI Program

**Goal**: Have AI write and run its first program safely.

### The Task
Ask your AI assistant:
> "Create a Python script called hello.py that prints 'Hello from the YOLOsandbox!' with the current date and time"

### What AI Will Do
```python
# AI creates hello.py
from datetime import datetime

print("Hello from the YOLOsandbox!")
print(f"Current time: {datetime.now()}")
```

### Running It
```bash
# AI runs the script
uv run python hello.py
```

### Expected Output
```
Hello from the YOLOsandbox!
Current time: 2024-01-15 10:30:45.123456
```

### What You Learned
✅ AI can create files in your project
✅ AI can run Python code safely
✅ The sandbox has Python pre-installed
✅ Your system time is accessible (read-only)

🏠 **Safety Note**: Remember, the child (AI) is playing safely in the backyard sandbox - your house (personal files and system) remains completely protected.

---

## Example 2: Package Installation - AI as Package Manager

**Goal**: Let AI install and use external packages without affecting your system.

### The Task
Ask your AI:
> "Install the 'requests' library and create a script that fetches a joke from a public API"

### What AI Will Do
```bash
# AI installs the package
uv pip install requests
```

```python
# AI creates joke_fetcher.py
import requests

response = requests.get("https://official-joke-api.appspot.com/random_joke")
joke = response.json()

print(f"Setup: {joke['setup']}")
print(f"Punchline: {joke['punchline']}")
```

### Running It
```bash
uv run python joke_fetcher.py
```

### Expected Output
```
Setup: Why don't scientists trust atoms?
Punchline: Because they make up everything!
```

### What You Learned
✅ AI can install Python packages safely
✅ Packages only exist in the sandbox
✅ AI can access the internet for APIs
✅ Your main Python installation is untouched

### Verify Isolation
```bash
# On your host system (outside sandbox)
python3 -c "import requests"
# Result: ModuleNotFoundError (unless you had it already)

# Inside sandbox
uv run python -c "import requests"
# Result: Works perfectly!
```

---

## Example 3: Web Scraping - Building Something Useful

**Goal**: Create a practical tool that scrapes data from websites.

### The Task
Ask your AI:
> "Create a web scraper that gets the top headlines from Hacker News and saves them to a JSON file"

### What AI Will Do
```bash
# AI installs required packages
uv pip install beautifulsoup4 requests
```

```python
# AI creates hn_scraper.py
import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime

def scrape_hackernews():
    url = "https://news.ycombinator.com/"
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')

    stories = []
    for item in soup.select('.storylink, .titleline > a')[:10]:
        stories.append({
            'title': item.text,
            'url': item.get('href', ''),
            'scraped_at': datetime.now().isoformat()
        })

    with open('headlines.json', 'w') as f:
        json.dump(stories, f, indent=2)

    return len(stories)

if __name__ == "__main__":
    count = scrape_hackernews()
    print(f"✅ Scraped {count} headlines from Hacker News")
    print("📁 Saved to headlines.json")
```

### Running It
```bash
uv run python hn_scraper.py
```

### Expected Output
```
✅ Scraped 10 headlines from Hacker News
📁 Saved to headlines.json
```

### What You Learned
✅ AI can build practical tools
✅ AI can install multiple dependencies
✅ Files created persist in your project
✅ AI can parse and process web data

---

## Example 4: Test Suite - AI Writing Tests

**Goal**: Have AI write and run tests for existing code.

### The Task
Ask your AI:
> "Look at the hn_scraper.py file and write comprehensive unit tests for it using pytest"

### What AI Will Do
```bash
# AI installs pytest
uv pip install pytest pytest-mock
```

```python
# AI creates test_hn_scraper.py
import pytest
import json
import os
from unittest.mock import patch, Mock
import hn_scraper

def test_scrape_creates_file():
    """Test that scraping creates the output file"""
    # Clean up any existing file
    if os.path.exists('headlines.json'):
        os.remove('headlines.json')

    with patch('requests.get') as mock_get:
        # Mock the response
        mock_response = Mock()
        mock_response.text = """
        <html>
            <a class="storylink">Test Story 1</a>
            <a class="storylink">Test Story 2</a>
        </html>
        """
        mock_get.return_value = mock_response

        # Run the scraper
        count = hn_scraper.scrape_hackernews()

        # Check results
        assert count > 0
        assert os.path.exists('headlines.json')

        with open('headlines.json') as f:
            data = json.load(f)
            assert len(data) > 0
            assert 'title' in data[0]
            assert 'url' in data[0]
            assert 'scraped_at' in data[0]

def test_handles_network_errors():
    """Test graceful handling of network errors"""
    with patch('requests.get') as mock_get:
        mock_get.side_effect = Exception("Network error")

        # Should handle the error gracefully
        with pytest.raises(Exception):
            hn_scraper.scrape_hackernews()

# Run with: pytest test_hn_scraper.py -v
```

### Running It
```bash
# AI runs the tests
uv run pytest test_hn_scraper.py -v
```

### Expected Output
```
============================= test session starts ==============================
test_hn_scraper.py::test_scrape_creates_file PASSED                     [ 50%]
test_hn_scraper.py::test_handles_network_errors PASSED                  [100%]

============================== 2 passed in 0.5s ================================
```

### What You Learned
✅ AI can analyze existing code
✅ AI can write professional test suites
✅ AI can mock external dependencies
✅ Tests run safely in isolation

---

## Example 5: Full Stack App - AI Building Complex Projects

**Goal**: Have AI create a complete web application with backend and frontend.

### The Task
Ask your AI:
> "Create a simple task manager web app with Flask that lets me add, view, and delete tasks. Include a nice HTML interface."

### What AI Will Do

```bash
# AI installs Flask
uv pip install flask
```

```python
# AI creates app.py
from flask import Flask, render_template, request, redirect, url_for, jsonify
import json
import os
from datetime import datetime

app = Flask(__name__)
TASKS_FILE = 'tasks.json'

def load_tasks():
    if os.path.exists(TASKS_FILE):
        with open(TASKS_FILE, 'r') as f:
            return json.load(f)
    return []

def save_tasks(tasks):
    with open(TASKS_FILE, 'w') as f:
        json.dump(tasks, f, indent=2)

@app.route('/')
def index():
    tasks = load_tasks()
    return render_template('index.html', tasks=tasks)

@app.route('/add', methods=['POST'])
def add_task():
    task = {
        'id': datetime.now().timestamp(),
        'text': request.form.get('task'),
        'created': datetime.now().isoformat()
    }
    tasks = load_tasks()
    tasks.append(task)
    save_tasks(tasks)
    return redirect(url_for('index'))

@app.route('/delete/<float:task_id>')
def delete_task(task_id):
    tasks = load_tasks()
    tasks = [t for t in tasks if t['id'] != task_id]
    save_tasks(tasks)
    return redirect(url_for('index'))

if __name__ == '__main__':
    os.makedirs('templates', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True)
```

```html
<!-- AI creates templates/index.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Task Manager</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .task {
            display: flex;
            justify-content: space-between;
            padding: 10px;
            margin: 10px 0;
            background: #f9f9f9;
            border-radius: 5px;
        }
        .task:hover {
            background: #f0f0f0;
        }
        .delete-btn {
            color: #d9534f;
            text-decoration: none;
            font-weight: bold;
        }
        .add-form {
            display: flex;
            margin-top: 20px;
        }
        input[type="text"] {
            flex: 1;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px 0 0 5px;
        }
        button {
            padding: 10px 20px;
            background: #5cb85c;
            color: white;
            border: none;
            border-radius: 0 5px 5px 0;
            cursor: pointer;
        }
        button:hover {
            background: #4cae4c;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📝 Task Manager</h1>

        <form action="/add" method="POST" class="add-form">
            <input type="text" name="task" placeholder="Enter a new task..." required>
            <button type="submit">Add Task</button>
        </form>

        <div class="tasks">
            {% for task in tasks %}
            <div class="task">
                <span>{{ task.text }}</span>
                <a href="/delete/{{ task.id }}" class="delete-btn">×</a>
            </div>
            {% endfor %}
        </div>

        {% if not tasks %}
        <p style="text-align: center; color: #999; margin-top: 30px;">
            No tasks yet. Add one above!
        </p>
        {% endif %}
    </div>
</body>
</html>
```

### Running It
```bash
# AI starts the Flask server
uv run python app.py
```

### Expected Output
```
 * Running on http://0.0.0.0:5000
 * Debug mode: on
```

Now open your browser to `http://localhost:5000` and you have a working task manager!

### What You Learned
✅ AI can create full web applications
✅ AI can manage multiple files and directories
✅ Web servers run safely in the sandbox
✅ Port forwarding works (access from your browser)
✅ Data persists between runs

---

## Example 6: Debugging and Fixing - AI as Your Debug Partner

**Goal**: Intentionally break code and have AI fix it.

### The Task
Create this broken Python script, then ask AI to fix it:

```python
# broken_script.py (you create this)
def calculate_average(numbers):
    total = 0
    for num in numbers:
        total += num
    return total / len(numbers)  # Bug: division by zero possible

def process_data(data):
    results = []
    for item in data:
        if item > 0:
            results.append(item * 2)
        else:
            results.append(item / 0)  # Bug: intentional division by zero
    return results

# Bug: undefined variable
print(f"Average: {calculate_average([])}")
print(f"Processed: {process_data([1, -2, 3])}")
print(f"Unknown: {unknown_variable}")  # Bug: undefined variable
```

Ask your AI:
> "This script is broken. Can you identify all the bugs, fix them, and add proper error handling?"

### What AI Will Create
```python
# fixed_script.py
def calculate_average(numbers):
    """Calculate average with proper error handling"""
    if not numbers:
        print("⚠️ Warning: Empty list provided, returning 0")
        return 0

    total = sum(numbers)
    return total / len(numbers)

def process_data(data):
    """Process data with error handling"""
    results = []
    for item in data:
        try:
            if item > 0:
                results.append(item * 2)
            else:
                # Fixed: handle negative numbers properly
                results.append(abs(item))
        except Exception as e:
            print(f"⚠️ Error processing {item}: {e}")
            results.append(0)
    return results

# Fixed: Handle edge cases properly
try:
    print(f"Average of empty list: {calculate_average([])}")
    print(f"Average of [1,2,3]: {calculate_average([1, 2, 3])}")
    print(f"Processed: {process_data([1, -2, 3])}")

    # Fixed: removed undefined variable
    # If we need it, define it first:
    unknown_variable = "Now it's defined!"
    print(f"Variable: {unknown_variable}")

except Exception as e:
    print(f"❌ Unexpected error: {e}")
```

### What You Learned
✅ AI can debug complex issues
✅ AI adds professional error handling
✅ AI can explain what was wrong
✅ AI can refactor for better practices

---

## Progressive Learning Path

### Beginner Level (You Are Here)
- ✅ Example 1: Hello World
- ✅ Example 2: Package Installation
- ✅ Example 3: Web Scraping

### Intermediate Level
- ✅ Example 4: Test Writing
- ✅ Example 5: Full Stack App
- ✅ Example 6: Debugging

### Advanced Level (Try These Next)
- **Data Science**: Ask AI to create a data analysis pipeline with pandas and matplotlib
- **Machine Learning**: Have AI build a simple ML model with scikit-learn
- **API Development**: Create a REST API with FastAPI and automatic documentation
- **Automation**: Build a file watcher that auto-processes uploads
- **CLI Tools**: Create a command-line application with Click or argparse

## Common Patterns and Tips

### Pattern 1: Let AI Install What It Needs
```
You: "Create a script that generates QR codes"
AI: [Installs qrcode, creates script, runs it]
```

### Pattern 2: Iterative Development
```
You: "Create a calculator"
You: "Now add scientific functions"
You: "Now add a GUI"
AI: [Builds incrementally, preserving previous work]
```

### Pattern 3: Learning from AI
```
You: "Explain what you just did and why you chose that approach"
AI: [Provides detailed explanation of the code]
```

### Pro Tips
1. **Be specific but not prescriptive** - Let AI choose the best approach
2. **Ask for tests** - Always ask AI to write tests for important code
3. **Request documentation** - AI can write excellent docstrings and README files
4. **Iterate freely** - The sandbox is safe, so experiment boldly
5. **Save good examples** - Build a library of useful scripts

## Verification Commands

Use these to verify the sandbox is working correctly:

```bash
# Check isolation (should fail to access host)
ls ~/.ssh/
# Result: No such file or directory

# Check internet access (should work)
curl -I https://google.com
# Result: HTTP/2 200

# Check resource limits
ulimit -a
# Shows limits in place

# Check user permissions
whoami
# Result: developer (not root)

# Check Python packages are isolated
uv pip list
# Shows only packages installed in sandbox
```

## Troubleshooting Common Issues

### AI Can't Import a Module
**Solution**: Ask AI to install it first with `uv pip install package-name`

### Web App Not Accessible
**Solution**: Make sure to use `host='0.0.0.0'` in Flask/FastAPI apps

### Files Disappear After Restart
**Solution**: Files in `/workspace` persist. Files elsewhere don't.

### Permission Denied Errors
**Solution**: The sandbox runs as user `developer`. Use `sudo` for system tasks.

## Next Steps

🎯 **Ready for real projects?** Start with your actual code!
🔒 **Want to understand the security?** → [UNDERSTANDING_SAFETY.md](UNDERSTANDING_SAFETY.md) *(uses helpful house/backyard analogies)*
🔧 **Need to customize?** → [TECHNICAL_REFERENCE.md](TECHNICAL_REFERENCE.md)
🚀 **Having fun?** Share your creations with the community!

---

Remember: **In YOLOsandbox, there are no mistakes, only experiments!** Like a child playing in the backyard sandbox, let AI try anything - your house stays safe and sound.