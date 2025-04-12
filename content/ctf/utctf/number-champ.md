---
title: "UTCTF25 - Number Champ (WEB)"
date: 2025-03-18T11:14:27+01:00
tags: ["ctf", "write-up", "utctf"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Number Champ"
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

![challenge-description](/blog/images/2025-03-18-11-21-52.png)
Link for the challenge is [here](https://numberchamp-challenge.utctf.live/)

## 1. Challenge Overview

After clicking on the link of the challenge, the website asks for permission to get our geographical
location. Also, according to the text on the screen, it seems like we're playing a game
of numbers against opponents of the same Elo (or level), hence the *"find match"* button.
![challenge-website](/blog/images/2025-03-18-11-25-24.png)

Say we allow the web application our location. We see a welcome message containing what seems to be
a random username and a starting elo of 1000.
![random username and starting elo](/blog/images/2025-03-18-11-29-41.png)

When we click on <find match> we see that we're matched with another player of relatively the same
elo, and interestingly, a relative distance from our current position in miles. We are also prompted
to enter a number and submit it to view the result of our battle. Let's do that:
![playing the game](/blog/images/2025-03-18-11-33-47.png)

Our result is a loss :)
![game result](/blog/images/2025-03-18-11-34-43.png)

In fact, no matter the number supplied to the game, we always lose the game lol, what a rigged game.

---

Since the UI rendered doesn’t give away much of the web application’s logic, let’s dive into the page source
to see how the latter works, namely, what endpoints are we interacting with, and what responses are we getting.

> My approach in analyzing code is having a top to bottom approach. I start with page source, move to intercepting
> requests to analyze responses and so on.

---

### `view-source (press ctrl+u)`

```html
<html>
  <head>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <title>Number Champ</title>
    <script>
      let userUUID=null,opponentUUID=null;var lat=0,lon=0;async function findMatch(){const e=await fetch(`/match?uuid=${userUUID}&lat=${lat}&lon=${lon}`,{method:"POST"}),t=await e.json();t.error?alert(t.error):(opponentUUID=t.uuid,document.getElementById("match-info").innerText=`Matched with ${t.user} (Elo: ${t.elo}, Distance: ${Math.round(t.distance)} miles)`,document.getElementById("match-section").style.display="none",document.getElementById("battle-section").style.display="block")}async function battle(){const e=document.getElementById("number-input").value;if(!e)return void alert("Please enter a number.");const t=await fetch(`/battle?uuid=${userUUID}&opponent=${opponentUUID}&number=${e}`,{method:"POST"}),n=await t.json();n.error?alert(n.error):(document.getElementById("battle-result").innerText=`Result: ${n.result}. Opponent's number: ${n.opponent_number}. Your new Elo: ${n.elo}`,document.getElementById("user-info").innerText=`Your updated Elo: ${n.elo}`,document.getElementById("battle-section").style.display="none",document.getElementById("match-section").style.display="block")}window.onload=async()=>{if(navigator.geolocation)navigator.geolocation.getCurrentPosition((async e=>{lat=e.coords.latitude,lon=e.coords.longitude;const t=await fetch(`/register?lat=${lat}&lon=${lon}`,{method:"POST"}),n=await t.json();userUUID=n.uuid,document.getElementById("user-info").innerText=`Welcome, ${n.user}! Elo: ${n.elo}`}));else{alert("Geolocation is not supported by this browser.");const e=await fetch(`/register?lat=${lat}&lon=${lon}`,{method:"POST"}),t=await e.json();userUUID=t.uuid,document.getElementById("user-info").innerText=`Welcome, ${t.user}! Elo: ${t.elo}`}};
    </script>
  </head>
  <body class="bg-light d-flex justify-content-center align-items-center vh-100 text-center">
    <div>
      <div class="container mt-5">
        <h1 class="display-4 text-primary">Number Champ</h1>
        <p class="lead text-secondary">Be the best. Show your opponent a higher number</p>
        <p id="user-info" class="text-success">Loading...</p>
        <img src="https://static.scientificamerican.com/sciam/cache/file/536BBA71-E627-4DB0-95D3A37002DB1CFD_source.jpg?w=600" class="img-fluid" style="max-width: 300px;" />
      </div>
      <div id="match-section" class="container mt-4">
        <p id="battle-result" class="text-info"></p>
        <button class="btn btn-primary" onclick="findMatch()">Find Match</button>
      </div>
      <div id="battle-section" class="container mt-4" style="display: none;">
        <p id="match-info" class="text-danger"></p>
        <h2 class="text-danger">Battle</h2>
        <div class="input-group mb-3">
          <input id="number-input" type="number" class="form-control" placeholder="Enter your number" />
          <button class="btn btn-success" onclick="battle()">Submit</button>
        </div>
      </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
  </body>
</html>
```
This is the underlying HTML of the web page we were at. As markup is not so interesting to us,
our main focal point are the `<script>` tags, namely, the one at the top:

### `<script> tag`
```html
<script>
  let userUUID = null,
    opponentUUID = null;
  var lat = 0,
    lon = 0;

  async function findMatch() {
    const e = await fetch(`/match?uuid=${userUUID}&lat=${lat}&lon=${lon}`, {
        method: "POST"
      }),
      t = await e.json();
    t.error ? alert(t.error) : (opponentUUID = t.uuid, document.getElementById("match-info").innerText = `Matched with ${t.user} (Elo: ${t.elo}, Distance: ${Math.round(t.distance)} miles)`, document.getElementById("match-section").style.display = "none", document.getElementById("battle-section").style.display = "block")
  }

  async function battle() {
    const e = document.getElementById("number-input").value;
    if (!e) return void alert("Please enter a number.");
    const t = await fetch(`/battle?uuid=${userUUID}&opponent=${opponentUUID}&number=${e}`, {
        method: "POST"
      }),
      n = await t.json();
    n.error ? alert(n.error) : (document.getElementById("battle-result").innerText = `Result: ${n.result}. Opponent's number: ${n.opponent_number}. Your new Elo: ${n.elo}`, document.getElementById("user-info").innerText = `Your updated Elo: ${n.elo}`, document.getElementById("battle-section").style.display = "none", document.getElementById("match-section").style.display = "block")
  }

  window.onload = async () => {
    if (navigator.geolocation) navigator.geolocation.getCurrentPosition((async e => {
      lat = e.coords.latitude, lon = e.coords.longitude;
      const t = await fetch(`/register?lat=${lat}&lon=${lon}`, {
          method: "POST"
        }),
        n = await t.json();
      userUUID = n.uuid, document.getElementById("user-info").innerText = `Welcome, ${n.user}! Elo: ${n.elo}`
    }));
    else {
      alert("Geolocation is not supported by this browser.");
      const e = await fetch(`/register?lat=${lat}&lon=${lon}`, {
          method: "POST"
        }),
        t = await e.json();
      userUUID = t.uuid, document.getElementById("user-info").innerText = `Welcome, ${t.user}! Elo: ${t.elo}`
    }
  };
</script>
```
As you can see, when the page loads (window.onload), we register ourselves at a given position
on earth, by default, that's our actual position in real life should we grant geolocation permission,
otherwise (lat,lon)=(0,0).

After that, we find a match player to play against. What's interesting about this is the use of
the (lat,lon) pair again as well as userUUID. Do we choose our location and what player we play with each match? Keep this in mind.

Finally, we battle an opponent player, which we get his UUID from the previous step, and our
elo (as well as their by extension) are updated based on the result of the battle which we know the game
doesn't allow us to win.

> Imagine Earth's surface as a grid: latitude lines wrap around it like belts, while longitude lines stretch from pole to pole.
> to learn more about the geographic coordinate system, check [this](https://www.youtube.com/watch?v=cwUuVdF8ohY)

## 2. Task Analysis

The challenge overview was long I know, but now we know what we have to do. Since the challenge
allows us to select any user to play the game with, and the goal is to figure out where 'geopy' trains to be the best.
We can play as many games as we need, switching from one player to another, until we level up to 3000elo.

After that, we end up with a *winner* player, that when matched with others, including geopy,
gets the latter relative distance to him. Our job then is to locate geopy.

## 3. Solution

Let's achieve the first task: Level up to 3000elo.

### `level-up.sh`

```bash
#!/usr/bin/env bash

lat=0
lon=0
e=99
base=https://numberchamp-challenge.utctf.live

# 1. Register our solo leveler - This player will reach 3000elo
registerRes=$(curl -s -X POST "$base/register?lat=$lat&lon=$lon")
winnerUUID=$(echo $registerRes | awk -F, '{ print $3 }'| awk -F: '{ print $2 }' | awk -F\" '{ print $2 }')
echo "winnerUUID: $winnerUUID"

# 2. Match this player with other players of his level
# (Note):
# a\ e doesn't matter, it always results in the loss of the left player
# b\ the points earned depend on the elo you're playing against (just like chess)

for ((i = 0; i < 30; i++)); do
    matchRes=$(curl -s -X POST "$base/match?uuid=$winnerUUID&lat=$lat&lon=$lon")
    matchResElo=$(echo $matchRes | awk -F, '{ print $2 }')
    matchUUID=$(echo $matchRes | awk -F, '{ print $4 }'| awk -F: '{ print $2 }' | awk -F\" '{ print $2 }')

    echo "match result: $matchRes"
    echo
    echo "match elo: $matchResElo"
    echo "matchUUID: $matchUUID"

    echo
    echo "[+] Playing against players"
    curl -s -X POST "$base/battle?uuid=$matchUUID&opponent=$winnerUUID&number=$e"
    curl -s -X POST "$base/battle?uuid=$matchUUID&opponent=$winnerUUID&number=$e"
    curl -s -X POST "$base/battle?uuid=$matchUUID&opponent=$winnerUUID&number=$e"
    curl -s -X POST "$base/battle?uuid=$matchUUID&opponent=$winnerUUID&number=$e"
    curl -s -X POST "$base/battle?uuid=$matchUUID&opponent=$winnerUUID&number=$e"
done

matchRes=$(curl -s -X POST "$base/match?uuid=$winnerUUID&lat=$lat&lon=$lon")
echo "winnerUUID: $winnerUUID"
echo "match result: $matchRes"
```

![results](/blog/images/2025-03-18-16-05-50.png)
Noice, we now have a player, a known geographical point against which the target has a known distance to.
The problem is: Which direction is geopy located at? As we are right now, geopy could exist
anywhere in the circle defined by winner location (ie lat,lon) and radius (distance) in miles.

Should we just guess every possible position along the circle? The answer is No.

---

It turns out the problem in our hand is a famous problem whose solution is used by GPS locators.

The use of distances (or "ranges") for determining the unknown position coordinates of a point of interest
is called Trilateration.

![trilateration picture](/blog/images/2025-03-18-21-12-46.png)

if you consider the Earth as a sphere, all points that are exactly X miles away from satellite 1 form a circle on the Earth's surface (the blue one). This circle is called a spherical circle or circle of radius X miles on the sphere. It is not a great circle (which would be the largest possible circle on a sphere), but rather a small circle because its center is not the center of the Earth.

The target could be anywhere along the blue circle. To narrow our options, we introduce another
*known* data point, that is exactly Y miles away from our target. The latter intersects with
our first circle in exactly two points, one of which is our target location. To narrow the search
even further, we introduce the third known data point which gives the exact location of the target.

To represent the problem mathematically, we first give the general equation of the sphere:

```bash
(x - x_i)^2 + (y - y_i)^2 + (z - z_i)^2 = r^2
```

Where x,y,z sub i are the locations of the data points, and r is their respective distance from the geopy.

The intersection of the equations of each data point forms an equation system that when solved,
gives the exact location of the target.

> Spherical distances require conversion to Cartesian for accurate calculations.

> When using earth's radius, ensure its unit matches that of distances (miles).

---

Ok. Where do we get the 3 known points from? Do we play the game using a different player?

No, it turns out, we can locate our winner player wherever we want. We just have to match him against
geopy from different points on earth and get the information, then use [this](https://github.com/akshayb6/trilateration-in-3d) implementation of Trilateration
to get his **exact** position.

### `trilateration.py`

![trilateration-repo](/blog/images/2025-03-18-22-53-35.png)

> Note: The script needs a quite some tweaking to get it right, and tbh, I got better
> results when my inital points were close enough. If somebody got an aswer to this,
> feel free to reach out and teach me! Username `@4nskarts` on discord

---

Perfect! We got our target latitude and longitude (`39.9404306, -82.9967132`).
![target reached](/blog/images/2025-03-18-22-57-30.png)
Flag is the address of this player (according to google maps), in the following format all lowercase:

```
utflag{<street-address>-<city>-<zip-code>}
```

Navigating to google maps, and entering the coordinates, we get:

1059 S High St, Columbus, OH 43206, United States

- **street address**: 1059 S High St
- **city**: Columbus
- **zip code**: 43206

Flag then is: `utflag{1059-s-high-st-columbus-43206}`

![this is the alt for the image](/blog/images/2025-03-27-09-37-50.png)
---

Lessons learned from this challenge:

1. [Trilateration](https://en.wikipedia.org/wiki/Trilateration)
2. [Converting from longitude\latitude to Cartesian coordinates](https://stackoverflow.com/questions/1185408/converting-from-longitude-latitude-to-cartesian-coordinates)
3. [Bash scripting](https://www.gnu.org/software/bash/manual/bash.html)
4. [NumPy](https://numpy.org/doc/stable/index.html)

---

This will be the place for the new image!
![this is the alt for the image](/blog/images/2025-03-27-09-37-50.png)


> note that the image path is the real path on the system
> you need its path in your blog. since my blog is running on /blog => path should be /blog/images/

