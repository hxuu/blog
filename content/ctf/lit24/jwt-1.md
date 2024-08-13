---
title: "LITCTF24 - Jwt 1"
date: 2024-08-13T18:34:00+01:00
tags: ["ctf", "write-up", 'litctf']
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Jwt 1"
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
name: jwt-1
category: web
points: 111
```

I just made a website. Since cookies seem to be a thing of the old days, I updated my authentication! With these modern web technologies, I will never have to deal with sessions again. Come try it out at http://litctf.org:31781/.

## Solution

We are presented with this interface

![initial](/blog/images/2024-08-13-18-35-27.png)

If we hit GET FLAG, we see a simple unauthorized message, and since the challenge's
name is `jwt-1`, it's likely that we have to bypass the authorization mechanism put in place
by the developers of this application.

Let's go ahead and create an account and log in. After that, we can notice using
the developers' tools that a json web token cookie was generated.

![jwt-cookie](/blog/images/2024-08-13-18-38-44.png)

In case you weren't familar, JSON web tokens (JWTs) are a standardized format for sending cryptographically signed JSON data between systems.

A JWT consists of 3 parts: a header, a payload, and a signature. These are each separated by a dot, as shown in the following example:

![jwt-format](/blog/images/2024-08-13-18-40-55.png)

The reason why jwt tokens are secure even if stolen is because of the key used
in the process of generation, without it, it's almost impossible to generate a valid
token. Luckily for us, this is a CTF challenge, and the signature might not be verified.

Based on the decoding of the given jwt token, we can see the following format:

![jwt-decoded](/blog/images/2024-08-13-18-43-31.png)

As we can see, there is an admin field which is set to false in our case, let's generate
a new token with admin set to true and an arbitrary key. I used [jwt.io](https://jwt.io/)
to generate the new token. Here is the new token with admin set to True.

```bash
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiaHh1dSIsImFkbWluIjp0cnVlfQ.U_vtAik7xxrcSpVPH6DPAoZQSnw-21pJn7_0_IdN5w0
```

Using the browser application section to modify the cookie, we hit GET FLAG once again
with the new jwt in place:

![flag](/blog/images/2024-08-13-18-46-40.png)

---

flag is: `LITCTF{o0ps_forg0r_To_v3rify_1re4DV9}`

Things learned from this challenge:

* What json web tokens are and how they are formatted

