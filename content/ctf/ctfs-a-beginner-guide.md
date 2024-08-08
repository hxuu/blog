---
title: "Ctfs - A Beginner's Guide"
date: 2024-08-08T14:08:49+01:00
tags: ["ctf", "cybersecurity"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "Breaking into CTFs: A Beginner's Guide to Capture the Flag Competitions"
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


When I first encountered cybersecurity, it was through phishing sites that people used to steal their friends' Facebook accounts. One of my friends even used one against another one of our friends to send messages from his account. No, that's not some ghost story, lol.

After that, I started taking cybersecurity more seriously. Coming from an academic background, I thought the best approach was to learn all the concepts first and then practice my skills. However, this linear approach has major flaws:

1. You will forget most of what you learned by the time you start practicing.
2. The brain is a muscle that needs exercise to grow. In my experience, what you learn and what you practice are related but require different mindsets.

My main challenge was finding an **enjoyable and effective** way to learn and practice cybersecurity concepts. That's when I discovered Capture the Flag (CTF) competitions.

**From Wikipedia:**

> "Capture the Flag (CTF) in computer security is an exercise in which participants attempt to find text strings, called 'flags,' which are secretly hidden in purposefully-vulnerable programs or websites. They can be used for both competitive or educational purposes."

Before I dive into how to start playing CTFs and optimizing them for your learning, let me assure you that this practical approach to learning cybersecurity doesn't prevent you from studying more formally. In fact, you can do both.

With that out of the way, here are X steps to start playing CTFs:

## The Tools You Need

- **Linux**: Almost essential. Download any distro (e.g., Ubuntu or Kali), and get comfortable navigating the system using the command line. Learn to use `apt`, `pacman`, or whatever package manager your distro comes with. If you're coming from a Windows background, you'll find that installing packages is much easier in Linux once you know how.

- **Scripting Language**: Learn a scripting language, such as Python. It's not the only option, but it's widely used. You'll find yourself using it to solve problems and automate tedious tasks.

## What Kind of CTFs Should You Play?

CTF challenges come in various flavors. I'll focus on Jeopardy-style CTFs, where participants capture flags by solving challenges across multiple categories. Here's a list of common categories:

1. **Crypto**: Challenges involving cryptography, including encryption, decryption, and cryptanalysis.
2. **Reverse Engineering**: Analyzing binaries to understand or modify their behavior.
3. **Pwn/Exploitation**: Exploiting vulnerabilities in programs to gain control or execute arbitrary code.
4. **Web**: Challenges focused on web application vulnerabilities like SQL injection, XSS, and CSRF.
5. **Forensics**: Analyzing data, logs, or files to uncover hidden information or traces of attacks.
6. **Steganography**: The art of hiding messages or data within images, audio, or other media.
7. **Miscellaneous**: Unique or unconventional challenges that don’t fit into other categories.
8. **OSINT**: Gathering and analyzing publicly available information.
9. **Binary Exploitation**: Exploiting memory corruption or other vulnerabilities in binary files.
10. **Programming**: Writing scripts or code to solve problems or automate tasks.

## Resources and Tips for Learning

Now that you have Arch Linux rocking with Vim, Tmux, and maybe even i3 as your window manager (just kidding!), you're ready to start playing.

You might ask, "I have the tools, sure, but I know NOTHING about cybersecurity. How can I practice something I don't even understand?"

That's the beauty of Capture the Flag competitions—they're designed to teach you concepts and stretch your knowledge. My advice for every challenge is to read the description, Google any unfamiliar terms, and use the hints provided. If you ever get stuck, writeups (solutions) are publicly available and can teach you how to solve the challenge, so you can learn from them.

Oh, and by the way, I share those writeups too, so check out my blog!

With that in mind, I recommend starting with `picoCTF`. It covers challenges across six domains of cybersecurity, including general skills, cryptography, web exploitation, forensics, and more. The challenges are specifically designed to be hacked, making it an excellent and legal way to gain hands-on experience.

---

In conclusion, remember that cybersecurity is a community. You can always ask for help, and help will surely be provided. If you'd like to join my Discord server to connect with me and other cybersecurity enthusiasts, check the link on the main page. Take care!
