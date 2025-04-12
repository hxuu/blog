---
title: "Looking at the Top Command - But More..."
date: 2024-10-16T20:21:55+01:00
tags: ["tutorial", "it-concepts", "guide"]
author: "hxuu"
showToc: true
TocOpen: true
draft: false
hidemeta: false
comments: true
description: "An in-depth guide on Looking at the Top Command"
summary: "Learn about Looking at the Top Command in this detailed article."
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

## Introduction

Today, while studying operating systems at school, we discussed the procfs virtual filesystem and how we can extract system information using the `top` command.

In this article, I want to explore this concept in depth, as well as its relation to the `top` command.

## Key Concepts

### Windows vs Linux

In the realm of Windows, the system doesn’t aim to create a uniform filesystem that handles all other filesystems interacting with it. Instead, it simply assigns each filesystem a letter for reference.

Linux, on the other hand, strives to unify the filesystem experience. For example, the root filesystem could be of type ext4, but another media mounted on `/mnt/data` could have an NTFS filesystem. This begs the question: What is the means of creating this level of abstraction?

### Virtual Filesystems

Here comes the notion of VFS (Virtual Filesystems), which are an abstraction layer—essentially an interface that manages filesystems by providing an upper interface to user space (via syscalls like `read`, `write`, etc.), and a lower interface made up of functions that need to be implemented by the actual filesystems and supplied to the VFS to perform common operations, regardless of the underlying filesystem.

## Why Filesystems are Needed

As obvious as it may seem, data stored in main memory is volatile and won’t persist after a shutdown. Moreover, the size of main memory is usually too small for most applications to store all their data in it. Hence, we need a solution that satisfies the following constraints:

1. Multiple processes must have the ability to access information simultaneously.
2. The information must persist after process termination.
3. The storage medium must be large enough to handle significant amounts of data.

Furthermore, raw storage solutions don’t provide the necessary features we need (like just reading or writing a block). Therefore, we create an abstraction around files—a part that handles everything related to files, which we call a `filesystem`.

## The /proc Filesystem

Now that we know how the filesystem works and what it does (through the concept of VFS), let's take a look at something else.

The `/proc` (process) filesystem is a Linux filesystem responsible for information retrieval. The idea originated in the 8th version of UNIX, but Linux extended it in several ways. The basic idea was to create a file for every process, containing multiple pieces of information about the process (command line, environment variables, etc.).

However, this idea extended to include information about the CPU, disk partitions, and more. The files aren’t located on disk but are instead read from system data structures on demand. Commands like `top` (the next section in this article) use this feature to retrieve system behavior information in a safe way.

## The `top` Command

We’ve covered a fair bit about filesystems—some of this information you might have already known, and some you might not have—but now we move to a higher level, one that we interact with daily.

### `man-page top`

> "The  top  program  provides  a dynamic real-time view of a running system.  It can display system summary information as well as a list of processes or threads currently being managed by the Linux kernel. The types of system summary information shown and the types, order, and size of information displayed for processes are all user configurable, and that configuration can be made persistent across restarts."

Having read the man page for `top`, what I’m most interested in exploring is the meaning of the PR (priority) field.

### Real-Time vs Normal

In the Linux operating system, processes can be categorized into two main types based on their scheduling policies: real-time and normal processes. Real-time processes have the highest priority and can preempt normal processes. These processes are generally used for tasks that require immediate attention. Normal processes have a lower priority than real-time processes, meaning they are less urgent.

Priorities are represented by numbers, just like the `chrt` command shows:

```bash
➜ chrt -m
SCHED_OTHER min/max priority    : 0/0
SCHED_FIFO min/max priority     : 1/99
SCHED_RR min/max priority       : 1/99
SCHED_BATCH min/max priority    : 0/0
SCHED_IDLE min/max priority     : 0/0
SCHED_DEADLINE min/max priority : 0/0
```

Real-time processes have a priority number range of 1 to 99, with 1 being the least urgent and 99 being the most urgent. Normal processes have a range of 100 to 139, with 100 being the least urgent and 139 the most urgent. This may seem counterintuitive, but the kernel actually inverts the priority order.

> Here’s the sched.h file in the Linux source code:

```c
/*
* Priority of a process goes from 0..MAX_PRIO-1, valid RT
* priority is 0..MAX_RT_PRIO-1, and SCHED_NORMAL/SCHED_BATCH
* tasks are in the range MAX_RT_PRIO..MAX_PRIO-1. Priority
* values are inverted: lower p->prio value means higher priority.
*
* The MAX_USER_RT_PRIO value allows the actual maximum
* RT priority to be separate from the value exported to
* user-space.  This allows kernel threads to set their
* priority to a value higher than any user task. Note:
* MAX_RT_PRIO must not be smaller than MAX_USER_RT_PRIO.
*/

#define MAX_USER_RT_PRIO        100
#define MAX_RT_PRIO             MAX_USER_RT_PRIO

#define MAX_PRIO                (MAX_RT_PRIO + 40)
#define DEFAULT_PRIO            (MAX_RT_PRIO + 20)
```

---

The `top` command uses these priority numbers as a basis of representation. It does, however, perform some calculations to represent the priority in the PR field.

1. For normal processes, we know that the 1 in range(100,139) stays the same, thus making it more efficient to represent the priorities from 00 through 39. These are represented in the PR field using a `nice` value within the range(-20, +19), "inclusive", using this equation:

   ```
   PR = +20 + $nice // nice defaults to Zero
   ```

2. For real-time processes, and to avoid interference with the priority numbers of normal processes, we take a different approach and represent **rt** (real-time) priorities with negative numbers in the range(-1, -100) "inclusive", using this equation:

   ```
   PR = -1 - $rt_priority // rt_priority in range(0,+99) "inclusive"
   ```

> This is why -51 in the following top command result represents a real-time high-priority process.

![top-command-result](/blog/images/2024-10-18-19-45-58.png)

*But how about the `rt` flag just above? Why aren’t we using a negative value instead?* - The answer is idk~ It's to indicate a real-time scheduling algorithm, but -51 does the same.

## Conclusion

In this article, we explored the concept of virtual filesystems, specifically procfs, and how they abstract away complex system information for user interaction. Linux’s VFS plays a key role in standardizing filesystem interaction across various types. We also discussed the `/proc` filesystem, which provides crucial system data like process and CPU information. The `top` command leverages this, displaying real-time system activity, including process priorities. We examined the difference between real-time and normal process priorities, understanding how `top` represents them. Through this, we gained deeper insights into Linux’s process scheduling and resource management.
