# Algorithm to writing a good writeup

the goal is how to produce a first draft. This is the creative part of the job,
after that comes the analytic part of the job, but NOT before the first.

## Preliminaries

[x] 1. review notes taken on stuff you read that are relevant to the writeup you're trying to make (Renew your literature search)
    * Here is the algorithm to review the necessary information:
        1. Look at the keywords of the paper. Not interested? => Stop.
        2. Read the conclusions/figures/tables...etc. Not relevant? => Stop.
        3. Start at the introduction => Provides background information /why the paper was written.
        4. Dive deeper into the results/conclusions => This is the heart of the paper
        5. IF THE PAPER IS EXTREMELY RELEVANT => Dig very deeply into the experimental. Learn how they did things.

[x] 2. Determine your audience
=> it's a ctf writeup (how a player solved solved a challenge)
=> it is intented for ctf participants that couldn't solve the challenge, but ALWAYS the reviewers
=> Reviewers of CTF writeups typically look for technical depth, clarity, correctness, reproducibility, insight, brevity, originality, and style (also entertainment value)
=> you can spot brevity in a writeup when it avoids fluff and rambling, uses direct explanations and minimal setup

## The big picture

- producing the first draft is the creative part of the job. Editing that first job is the analytical part.
- Resist the temptation to edit the first draft.
- your job is to produce a complete first draft, not a perfect first draft.

### The algorithm

[x] 1. just get started

[x] 2. work from an outline
=> [x] Challenge overview (description, title, category...etc)
=> [x] TL;DR (summary of the whole challenge, at least 50 words but not more than 100)
=> [x] Initial analysis (application wide analysis - looking at the app as a whole and hinting at a suspection)
=> [x] Task analysis (diving deeper into that single point of failure or of vulnerability)
=> [x] Exploitation (crafting the payload and delivering the attack)
=> [x] Conclusions (what was learned from this challenge - in list format)
=> [x] References (links to more detail)

[ ] 3. do not write the introduction-like stuff now! (it induces procrastination)
=> The easiest part to write is the experimental (actual code, exploitation)

[ ] 4. Arrange all images related to the ctf in logical sequence, much like you organize a thought.

[ ] 5. move forward to other sections except the introduction. analyze and review the task analysis and exploitations.

[ ] 6. Produce the conclusions: in a list format.

[ ] 7. do the introduction:
=> Why was i drawn into the task analysis topic? 'why did seem fishy in the app?'
=> Give the reader sufficient background to clear it for him why you did what you did.

[ ] 8. get the exact references for everything you said (the exact anchors)

