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
2. Comment-Based Help
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

