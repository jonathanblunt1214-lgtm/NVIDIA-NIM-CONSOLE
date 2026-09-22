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

function Render-Banner {
    Clear-Host
    $blockWidth = 75
    $winWidth =$Host.UI.RawUI.WindowSize.Width
    if ($winWidth -le 0) { $winWidth = 100 }$padLeft = [Math]::Max(0, [int](($winWidth -$blockWidth) / 2))
    $margin = " " * $padLeft

    $divider    = "=" * $blockWidth$subDivider = "-" * $blockWidth$title      = "NVIDIA NIM AGENTIC GIT CONSOLE"
    $titlePad   = " " * [Math]::Max(0, [int](($blockWidth -$title.Length) / 2))

    $curDir = (Get-Location).Path
    $curRemote = (git config --get remote.origin.url 2>$null)
    if (-not $curRemote) {$curRemote = "No remote configured" }
    $curBranch = (git branch --show-current 2>$null)
    if (-not $curBranch) {$curBranch = "HEAD (detached)" }

    Write-Host "$margin$divider" -ForegroundColor Green
    Write-Host "$margin$titlePad$title" -ForegroundColor Green
    Write-Host "$margin$divider" -ForegroundColor Green
    Write-Host "$margin$('Model'.PadRight(12)):$Global:Model" -ForegroundColor Cyan
    Write-Host "$margin$('Directory'.PadRight(12)):$curDir" -ForegroundColor DarkGray
    Write-Host "$margin$('Git Remote'.PadRight(12)):$curRemote" -ForegroundColor DarkGray
    Write-Host "$margin$('Git Branch'.PadRight(12)):$curBranch" -ForegroundColor Yellow
    Write-Host "$margin$('Time'.PadRight(12)):$(Get-ConsoleTimestamp)" -ForegroundColor Gray
    Write-Host "$margin$('Commands'.PadRight(12)): :branch <name>, :dir <path>, :remote <url>, 'clear', 'exit'" -ForegroundColor DarkCyan
    Write-Host "$margin$subDivider`n" -ForegroundColor Green
}

$ApiKey = [Environment]::GetEnvironmentVariable("NGC_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = [Environment]::GetEnvironmentVariable("NGC_API_KEY", "Process")
}

$Global:Model = "nvidia/nemotron-3.5-lightning-30b-a3b"
$Url   = "https://integrate.api.nvidia.com/v1/chat/completions"

$SystemPrompt = @"
You are the NVIDIA NIM Agentic Console assistant.
RULES:
1. Provide short, sweet, direct summaries (1-3 sentences max).
2. Never repeat user prompt instructions, rulebooks, or templates.
3. Report only verified actions, statuses, or diffs.
"@

$Messages = [System.Collections.Generic.List[hashtable]]::new()
$Messages.Add(@{ role = "system"; content = $SystemPrompt })

Render-Banner

while ($true) {
    $userInput = Read-Host "You"
    if ([string]::IsNullOrWhiteSpace($userInput)) { continue }
    if ($userInput -eq "exit" -or $userInput -eq ":q") { break }
    
    if ($userInput -eq "clear") {
        $Messages.Clear()
        $Messages.Add(@{ role = "system"; content = $SystemPrompt })
        Render-Banner
        continue
    }

    # Switch branch command: :branch <name>
    if ($userInput -like ":branch *") {
        $targetBranch = ($userInput -split " ")[1]
        git fetch origin 2>$null
        git checkout $targetBranch 2>$null
        if ($LASTEXITCODE -ne 0) {
            git checkout -b $targetBranch "origin/$targetBranch" 2>$null
        }
        Render-Banner
        continue
    }

    # Switch directory command: :dir <path>
    if ($userInput -like ":dir *") {
        $targetDir = ($userInput -split " ", 2)[1]
        if (Test-Path $targetDir) {
            Set-Location -Path $targetDir
            Render-Banner
        } else {
            Write-Host "Directory not found: $targetDir" -ForegroundColor Red
        }
        continue
    }

    # Switch remote command: :remote <url>
    if ($userInput -like ":remote *") {
        $targetRemote = ($userInput -split " ")[1]
        git remote set-url origin $targetRemote
        Render-Banner
        continue
    }

    $Messages.Add(@{ role = "user"; content = $userInput })
    Set-ReasoningIndicator $true

    try {
        $body = @{
            model       = $Global:Model
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
