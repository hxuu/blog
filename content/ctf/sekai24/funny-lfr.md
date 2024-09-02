---
title: "SEKAI 24 - Funny Lfr"
date: 2024-08-30T11:01:21+01:00
tags: ["ctf", "write-up", "sekaictf"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Funny Lfr"
summary: "The article explains exploiting a race condition in a Starlette app to bypass `os.stat` checks, using symlinks, and ultimately retrieving the flag from `/proc/self/environ`."
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
name: funny lfr
category: web exploitation
points: 183
solves: 36 solves
```

You can access the challenge via SSH:
```bash
ncat -nlvp 2222 -c "ncat --ssl funny-lfr.chals.sekai.team 1337" & ssh -p2222 user@localhost
```
SSH access is only for convenience and is not related to the challenge.

## Analysis

We are given the following source files:

```bash
├── app.py
└── Dockerfile
```

Which represent a simple [Starlette](https://www.starlette.io/) application:

```python
from starlette.applications import Starlette
from starlette.routing import Route
from starlette.responses import FileResponse


async def download(request):
    return FileResponse(request.query_params.get("file"))


app = Starlette(routes=[Route("/", endpoint=download)])
```

And a Dockerfile

```bash
FROM python:3.9-slim

RUN pip install --no-cache-dir starlette uvicorn

WORKDIR /app

COPY app.py .

ENV FLAG="SEKAI{test_flag}"

CMD ["uvicorn", "app:app", "--host", "0", "--port", "1337"]
```

At first glance the challenge seems very simple. You make a request to `/?file=<path>`
and get the file contents displayed to you.

### `Inside SSH`

![inside-ssh](/blog/images/2024-08-30-11-28-28.png)

The flag as highlighted by the Dockerfile is stored inside an environment variable
called `FLAG`. Doing a quick google search, we can see that environment variables
in linux systems are stored in the `/proc/pid/environ` file.

With that knowledge in hand, we should get the flag just by getting the results of
`/proc/self/environ` which stores the environment variables of the current running process.

Right?

![right?](/blog/images/2024-08-30-11-38-10.png)

We got nothing... That's weird.

We know the application should return the contents of the files we ask for. However,
asking for `/proc/self/environ` doesn't return anything. Why?

Well, the python application is a Starlette application that adheres to ASGI specs,
the FileResponse class is responsible for returning files to the client. Before serving
a file, FileResponse checks the file's size using the os.stat syscall.

### `from Starlette source code`

![stat-check](/blog/images/2024-08-30-11-52-53.png)

The `os.stat` function retrieves various attributes about a file, such as its size, modification time, and permissions. When `os.stat` is called on a file, it checks the filesystem for this information.

However, in the case of `/proc/self/environ`, which resides within the `procfs` virtual filesystem (VFS), there’s a unique situation. The `procfs` VFS provides access to kernel and process information, and many files within it are not regular files but rather interfaces to the kernel's data structures. These files often have special behaviors, and their contents may be dynamically generated when accessed.

When `os.stat` **checks** `/proc/self/environ`, it reports the file size as zero because, in many cases, the file doesn’t have a traditional size; it's an interface to process-specific information that’s only generated on demand. Consequently, when `FileResponse` sees a size of zero, it might interpret this as an empty or non-existent file, even though reading from `/proc/self/environ` would normally return environment variables for the process.

This behavior can lead to the application not returning any content when asked for `/proc/self/environ`, despite the file being non-empty in a traditional sense. The mismatch between how `os.stat` reports the file's size and the file's actual contents in `procfs` **is the root cause of this issue.**


---

So, what can we do then?

It turns out, we can trigger a race condition to do the following:

1. request a file whose size is greater than 0.
2. right after `os.stat` and before the actual **read**, we swap the latter file,
with the desired file which is `/proc/pid/environ`.

To achieve such a thing, we can make use of [symlinks](https://en.wikipedia.org/wiki/Symbolic_link), create a symlink that points
to a bigger file, bypass the `os.stat` step, then right before the file read, we change
the link to `/proc/pid/environ` and successfully get the flag.


## Exploitation

To trigger the race condition, let's first create a bash script that creates a large file,
create a symlink to it, and then create an infinite loop which swaps the links between this file
and `/proc/pid/environ`.

> Note that you should replace pid with the actuall process id of the running python application.
You can figure that using `ps aux`. pid=7 in my case.

### `solve.sh`

```bash
#!/usr/bin/env bash

cat /etc/passwd > /home/user/big-file.txt

ln -s big-file.txt /home/user/the-link

while true; do
    ln -sf /proc/7/environ          /home/user/the-link
    ln -sf /home/user/big-file.txt  /home/user/the-link
done
```

Running this on remote, and doing few curls of the `the-link` file should give us the flag.

![solve](/blog/images/2024-08-30-12-32-01.png)

---

Flag is: `SEKAI{b04aef298ec8d45f6c62e6b6179e2e66de10c542}`

Things we learned from this challenge:

Here are the key lessons from the challenge:

- **`os.stat` and `procfs`**: Learned how `os.stat` retrieves file attributes and why it reports `/proc/self/environ` as size zero in `procfs`.

- **Race Condition Exploit**: Discovered how to exploit race conditions using symlinks to bypass `os.stat` and read sensitive files.

- **Symlink Usage**: Learned to manipulate file paths using symlinks for exploitation purposes.
