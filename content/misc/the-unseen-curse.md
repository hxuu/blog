---
title: "Ingeneer25 (Problem Solving) - The Unseen Curse"
date: 2025-05-22T19:59:22+01:00
tags: ["ctf", "write-up", "problem-solving"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "Challenge write-up for The Unseen Curse, problem solving challenge."
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

```
**Challenge Name**: The Unseen Curse
**Category**: Problem Solving
**Author**: hxuu
**Difficulty**: Tough
**Tags**: `pure logic`, `tough`
```

## Challenge Description

  During a clandestine lesson in the Forbidden Forest, Professor Moody gathers the apprentices for a test of perception and logic.

  > *"Among these ancient trees, some bear the Phantom Mark—a dark sigil invisible to the one who stands beneath it. Each of you will be assigned a tree, but you cannot see your own. Look around: How many marks do you see?"*

  - **Alice** counts **A** marked trees.
  - **Bob** counts **B** marked trees.

  The total number of marks, **T**, is either **X** or **Y** (X < Y), but neither knows for sure.

  **The Ritual of Declaration:**
  Each night, the professor asks the apprentices in Turn:
  > *"Is the true number of marks **X** or **Y**?"*

  If an apprentice can logically deduce the answer, they must declare it at midnight. If not, the ritual repeats.

  **Your Task:**
  Given **A**, **B**, **X**, and **Y**, determine the **minimum number of nights** before one apprentice can conclusively declare the true count.

  **Input Format:**
  * Line 1: Two integers **A** and **B** (0 ≤ A, B ≤ 10^9)
  * Line 2: Two integers **X** and **Y** (1 ≤ X < Y ≤ 10^18)

  **Output Format:**
  * A single integer: the number of nights required.

  > *The flag is forged from the answers to hidden trials, wrapped in `1ng3neer2k25{}`.*

---

## Initial Analysis

This challenge presents a variation of the *Muddy Children* epistemic logic puzzle, cloaked in a magical narrative.

- Alice and Bob each see a number of trees, independent of one another.
- No one knows how many trees the other sees.
- The total number of trees is `T` which is equal to `A + B`

Each night, they are asked if they can determine whether the true total is **X** or **Y**.
If neither can be certain, the professor asks again the next night. This process continues until one of them is logically certain and makes a declaration.

The puzzle is fundamentally about **logical inference over time**, based on:
- **What each person sees**
- **What each person knows the other sees**
- **What each person knows the other knows**, and so on.

This is a classic **common knowledge puzzle**, where the lack of an answer over time becomes **new information**.

> If you feel I threw a lot of new terms, [here](https://www.youtube.com/watch?v=KVOpXJZWLC4&t=796s) is a good lecture about epistemic logic and types of knowledge.

---

## Task Analysis

We are given:
- **A** and **B**: the number of trees seen by Alice and Bob.
- **X** and **Y**: the two possible values for the total number of marked trees.

Our goal is to determine the **minimum number of nights** before **either Alice or Bob** can logically deduce
whether the true (i.e. total) number of trees is `X` or `Y`.

### Input:

```bash
Line 1: A B      # integers: how many trees Alice and Bob see
Line 2: X Y      # integers: possible values for total number of trees
...etc
```

### Output (for a single test case):

```bash
One integer: the minimum number of nights before one of them deduces the correct total
````

For example, if Alice sees 12 marks, Bob sees 8 marks, and the possible totals are 18 and 20,
then we want to find out how many nights pass before one of them can definitively declare that the true total is, say, 20.

---

## Solve

The challenge is solved using a simulation that alternates deduction attempts between Alice and Bob,
is simpler words: We pretend to be Alice and Bob, see how we do (can or cannot answer and why?) and reach the target night.

Here's the core logic, implemented in Python:

```python
def nights_simulation(A=12, B=8, X=18, Y=20):
    if X == Y:
        return "1"

    nights = 1
    atleast = 0
    utmost = Y
    delta = Y - X

    while nights <= 30:
        # Alice tries to deduce
        if utmost - delta + 1 <= A <= utmost:
            return str(nights)  # Alice can deduce
        else:
            utmost -= delta  # Alice fails, Bob gains knowledge

        # Bob tries to deduce
        if atleast <= B <= atleast + delta - 1:
            return str(nights)  # Bob can deduce
        else:
            atleast += delta  # Bob fails, Alice gains knowledge

        nights += 1

    return "-1"  # No conclusion reached within 30 nights
````

### How It Works:

* At the 1st night, Alice is asked whether she sees 18 or 20 trees. Had she seen 19 or 20, she would've answered 20, but she only sees 12, so she passes.
* Bob, having known that Alice's passing results in her seeing at most 18 trees, would be able to answer if he sees 0 or 1 trees in total (0+18 = 18, 1+17 = 18 => answer is 18)

* At the 2nd night, Alice is asked again. Now she knows bob couldn't have seen 0 or 1, he must've seen AT LEAST 2. Armed with this knowledge, she would've answered 20 if she had either 18 or 17 (but not 16!). Alice sees 12 though, so she passes.
* Bob, having known that Alice's passing results in her seeing at most 16 trees, would be able to answer if he sees 2 or 3 trees in total (2+16 = 18, 3+15 = 18 => answer is 18)

Do you notice the pattern? Here it is:

* Each night, the current player sees if he can answer
* The passing (failure to declare) of one player is an implicit message to the other that eliminates certain worlds from existence (world where Alice has 19 or 20 in night 1).
* Over time, this silent communication builds up into logical certainty, and one player can make a declaration.

* `utmost` and `atleast` represent shrinking bounds for each player's certainty window.
* Over time, **the failure to deduce becomes information** — if Alice doesn't speak up on night 1, Bob learns something new about what Alice must have seen.
* Eventually, someone can eliminate one possibility and declare the truth.

### Batch Evaluation and Flag Generation

To solve multiple test cases and derive the final flag, the script reads inputs in pairs from a file (`the-unseen-curse.txt`):

```python
if __name__ == "__main__":
    with open("../files/the-unseen-curse.txt") as f:
        lines = [line.strip() for line in f if line.strip()]

    assert len(lines) % 2 == 0

    results = []

    for i in range(0, len(lines), 2):
        A, B = map(int, lines[i].split())
        X, Y = map(int, lines[i + 1].split())

        if X > Y:
            X, Y = Y, X

        result = new_reasoning_solver(A, B, X, Y)
        results.append(result)

    print("Flag:", f"1ng3neer2k25{{{''.join(results)}}}")
```

Each result becomes a digit in the final flag. then the final flag is:

```
1ng3neer2k25{5211322412311434132}
```

---

### Summary

This challenge masterfully blends **deductive logic**, **iterative inference**, and a compelling magical narrative. It requires understanding how knowledge propagates in rounds and how silence becomes information. By modeling the interactions over successive nights, we compute the precise moment someone can break the uncertainty and solve the puzzle.
