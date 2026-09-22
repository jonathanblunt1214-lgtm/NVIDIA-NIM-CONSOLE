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

# Calculate shared left-margin to center the entire fixed-width block cleanly
$blockWidth = 75
$windowWidth = $Host.UI.RawUI.WindowSize.Width
if ($windowWidth -le 0) { $windowWidth = 100 }
$padLeft = [Math]::Max(0, [int](($windowWidth - $blockWidth) / 2))
$margin = " " * $padLeft

$divider    = "=" * $blockWidth
$subDivider = "-" * $blockWidth
$title      = "NVIDIA NIM AGENTIC GIT CONSOLE"
$titlePad   = " " * [Math]::Max(0, [int](($blockWidth - $title.Length) / 2))

Write-Host "$margin$divider" -ForegroundColor Green
Write-Host "$margin$titlePad$title" -ForegroundColor Green
Write-Host "$margin$divider" -ForegroundColor Green
Write-Host "$margin$('Model'.PadRight(12)): $Model" -ForegroundColor Cyan
Write-Host "$margin$('Directory'.PadRight(12)): $CurrentDir" -ForegroundColor DarkGray
Write-Host "$margin$('Git Remote'.PadRight(12)): $GitRemote" -ForegroundColor DarkGray
Write-Host "$margin$('Git Branch'.PadRight(12)): $GitBranch" -ForegroundColor Yellow
Write-Host "$margin$('Time'.PadRight(12)): $(Get-ConsoleTimestamp)" -ForegroundColor Gray
Write-Host "$margin$('Commands'.PadRight(12)): Type 'exit' to quit, 'clear' to reset." -ForegroundColor DarkCyan
Write-Host "$margin$subDivider`n" -ForegroundColor Green

while ($true) {$userInput = Read-Host "You"
    if ([string]::IsNullOrWhiteSpace($userInput)) { continue }
    if ($userInput -eq "exit" -or $userInput -eq ":q") { break }
    if ($userInput -eq "clear") {
        $Messages.Clear()
        $Messages.Add(@{ role = "system"; content = $SystemPrompt })
        Clear-Host
        Write-Host "$margin[Context reset]`n" -ForegroundColor Yellow
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
