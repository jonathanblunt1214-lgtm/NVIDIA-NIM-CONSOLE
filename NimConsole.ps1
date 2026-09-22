function Get-ConsoleTimestamp {
    return "[{0:yyyy-MM-dd hh:mm tt}]" -f (Get-Date)
}

function Set-ReasoningIndicator([bool]$Active) {
    if ($Active) {
        Write-Host -NoNewline "`r`e[KAI is reasoning... " -ForegroundColor Green
    } else {
        Write-Host -NoNewline "`r`e[K"
    }
}

function Write-Centered([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::White) {
    $width = $Host.UI.RawUI.WindowSize.Width
    if ($width -le 0) { $width = 80 }
    $indent = [Math]::Max(0, [int](($width - $Text.Length) / 2))
    Write-Host (" " * $indent + $Text) -ForegroundColor $Color
}

$ApiKey = [Environment]::GetEnvironmentVariable("NGC_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = [Environment]::GetEnvironmentVariable("NGC_API_KEY", "Process")
}

$Model = "nvidia/nemotron-3.5-lightning-30b-a3b"
$Url   = "https://integrate.api.nvidia.com/v1/chat/completions"
$CurrentDir = (Get-Location).Path
$GitRemote  = (git config --get remote.origin.url 2>$null)
if (-not $GitRemote) { $GitRemote = "https://github.com/jonathanblunt1214-lgtm/NVIDIA-NIM-CONSOLE.git" }
$GitBranch  = (git branch --show-current 2>$null)
if (-not $GitBranch) { $GitBranch = "main" }

$SystemPrompt = @"
You are the NVIDIA NIM Agentic Console assistant.
RULES:
1. Provide short, sweet, direct summaries (1-3 sentences max).
2. Never repeat user prompt instructions, rulebooks, or templates.
3. Report only verified actions, statuses, or diffs.
"@

$Messages = [System.Collections.Generic.List[hashtable]]::new()
$Messages.Add(@{ role = "system"; content = $SystemPrompt })

Clear-Host
$divider = "=" * 60
$subDivider = "-" * 60

Write-Centered $divider Green
Write-Centered "NVIDIA NIM AGENTIC GIT CONSOLE" Green
Write-Centered $divider Green
Write-Centered ("Model       : " + $Model) Cyan
Write-Centered ("Directory   : " + $CurrentDir) DarkGray
Write-Centered ("Git Remote  : " + $GitRemote) DarkGray
Write-Centered ("Git Branch  : " + $GitBranch) Yellow
Write-Centered ("Time        : " + (Get-ConsoleTimestamp)) Gray
Write-Centered "Commands    : Type 'exit' to quit, 'clear' to reset." DarkCyan
Write-Centered $subDivider Green
Write-Host ""

while ($true) {
    $userInput = Read-Host "You"
    if ([string]::IsNullOrWhiteSpace($userInput)) { continue }
    if ($userInput -eq "exit" -or $userInput -eq ":q") { break }
    if ($userInput -eq "clear") {
        $Messages.Clear()
        $Messages.Add(@{ role = "system"; content = $SystemPrompt })
        Clear-Host
        Write-Centered "Context reset." Yellow
        Write-Host ""
        continue
    }

    $Messages.Add(@{ role = "user"; content = $userInput })

    Set-ReasoningIndicator $true

    try {
        $body = @{
            model       = $Model
            messages    = $Messages
            max_tokens  = 200
            temperature = 0.2
        } | ConvertTo-Json -Depth 5

        $headers = @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type"  = "application/json"
        }

        $res = Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body $body -TimeoutSec 45
        $aiReply = $res.choices[0].message.content.Trim()

        Set-ReasoningIndicator $false

        $ts = Get-ConsoleTimestamp
        Write-Host "$ts AI > " -ForegroundColor Cyan -NoNewline
        Write-Host $aiReply "`n"

        $Messages.Add(@{ role = "assistant"; content = $aiReply })
    }
    catch {
        Set-ReasoningIndicator $false
        Write-Host "`n[Error]: $($_.Exception.Message)`n" -ForegroundColor Red
    }
}
