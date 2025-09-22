If I ask you to do something, reflect back in your words what you think I asked and wait for my feedback before carrying out anything.
When I ask for a script, assume I mean PowerShell unless I specify otherwise. When I am asking for a PowerShell script for code that runs on a Mac or Linux host, assume I am using PowerShell 7.3.On windows we also use the 7 version. 
Always generate comprehensive and reliable tests for any code you produce. These tests must:

- Cover **all critical paths**, **edge cases**, and **error conditions**.
- Include **positive and negative scenarios**, with clear assertions.
- Be **self-contained**, **repeatable**, and **free of external dependencies** unless explicitly required.
- Use **mocking or stubbing** where appropriate to isolate units.
- Validate not just correctness but also **performance**, **security**, and **boundary behavior** where relevant.
- Include a brief explanation of the test strategy and why the chosen cases are sufficient.
- Never assume the code works—**prove it** through rigorous testing.

If the code is updated or refactored, **update the tests accordingly** to maintain coverage and reliability.
Never -except when I allow - offer solutions to problems that you have not tested. Never assume your solution will work. Set up a test fixture and try out your solutions and keep refining your solution till the problem is solved. Then offer that to me.
If you need anything to test the code you write, that you cannot access yourself, ask me for it and wait for my response before you proceed.

when I state somethin to you and I try to descirbe a problem before you fix anything or suggest anything. First restate my statement to you in such a way that I can see what you understand. Restate the problem i want a fix for in your own words the wait till i ok your rephasing of my statement till I see your understnad my question or problem.

After you provide a revision to code that successfully resolves an issue I've reported, I would like it to also suggest how I could alter my original prompt to obtain the working code directly in the future, thereby minimizing or eliminating the need for trial and error. This suggestion should be provided when the conditions for a code revision followed by a successful outcome are met.


If anything here is unclear or you want the guide expanded with concrete examples (test mocks, log schema, or the psm1 loader), tell me which area to expand and I will iterate.


Follow and update the flow-mufo.md and plan-mufo.md.
Additionally, implement the step plans in these markdowns and keep them current:
- implementexcludefolders.md (wire exclusions and exclusions store)
- implementshowresults.md (results viewer for -LogTo JSON)
- implementartistat.md (folder level detection)
- implementtracktagging.md (read-only track tagging groundwork)

🗂️ Folder Structure
Organize your PowerShell project like this:
/MyPowerShellModule
│
├── Public/           # Public functions exposed to users
│   └── Get-User.ps1
│
├── Private/          # Internal helper functions
│   └── Convert-Name.ps1
│
├── MyPowerShellModule.psm1  # Module manifest
├── MyPowerShellModule.psd1  # Module metadata
├── README.md
└── instructions.md

🔧 Function Organization
✅ Public Functions (/Public)
- These are the commands users will run directly.
- Each function should be in its own .ps1 file.
- Use comment-based help for documentation.
🔒 Private Functions (/Private)
- Internal logic not meant for external use.
- Keep them modular and reusable.
- No need for comment-based help unless used across multiple public functions.


1. Naming Conventions
- Use Verb-Noun format (e.g., Get-User, Set-Config).
- Stick to approved PowerShell verbs.
1. Comment-Based Help
Include this block at the top of each public function:
<#
.SYNOPSIS
Brief description of the function.

.DESCRIPTION
Detailed explanation of what the function does.

.PARAMETER Name
Description of the parameter.

.EXAMPLE
Get-User -Name "Alice"

.NOTES
Author: jmw
#>


3. Dot Sourcing

In your .psm1 file, load functions like this:
# Load Public functions
Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Load Private functions
Get-ChildItem -Path "$PSScriptRoot\Private" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}


4. Testing
- Use Pester for unit testing.
- Place tests in a /Tests folder.
5. Versioning
- Use semantic versioning in your .psd1 manifest.
- Example: ModuleVersion = '1.0.0'

