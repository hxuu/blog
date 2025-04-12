---
title: "LITCTF24 - Anti Inspect"
date: 2024-08-13T17:55:33+01:00
tags: ["ctf", "write-up", 'litctf']
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Anti Inspect"
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
name: anti-inspect
category: web exploitation
points: 109
```

can you find the answer? WARNING: do not open the link your computer will not enjoy it much.
URL: http://litctf.org:31779/ Hint: If your flag does not work, think about how to style the output of console.log

## Solution

Since the challenge warns us against opening the link on our browser, I assumed
there is some kind of infinite loop inside the script tag. Curling the link given
to us gives the following page:

```bash
➜ curl http://litctf.org:31779/
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Document</title>
  </head>
  <body>
    <script>
      const flag = "LITCTF{your_%cfOund_teh_fI@g_94932}";
      while (true)
        console.log(
          flag,
          "background-color: darkblue; color: white; font-style: italic; border: 5px solid hotpink; font-size: 2em;"
        );
    </script>
  </body>
</html>
```

At first when I tried to submit the flag `LITCTF{your_%cfOund_teh_fI@g_94932}`,
it said wrong flag, so I checked the hint, our flag doesn't work, let's take
the javascript code inside the script tag and run it with nodejs

![nodejs-pic](/blog/images/2024-08-13-18-30-38.png)

---

The flag is: `LITCTF{your_fOund_teh_fI@g_94932}`

Things learned from this challenge:

* How to inspect source code
* Simple usage of curl command
