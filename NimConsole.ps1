function Remove-ThinkingTrace([string]$text) {
    if (-not $text) { return "" }
    $out =$text -replace "(?s)<think>.*?</think>", ""
    $out =$out -replace "(?s)Here's a thinking process:.*?(\r?\n\r?\n|$)", ""
    return $out.Trim()
}

    if ($Active) {
        $Global:AnimCancel = [System.Threading.CancellationTokenSource]::new()
        $token = $Global:AnimCancel.Token
        $Global:AnimTask = [System.Threading.Tasks.Task]::Run([Action]{
            $width = 20
            $pos = 0
            $dir = 1
            [System.Console]::CursorVisible = $false
            while (-not $token.IsCancellationRequested) {
                $left  = "=" * $pos
                $right = "=" * ($width - $pos - 1)
                [System.Console]::Write("`r   AI is reasoning... [")
                [System.Console]::ForegroundColor = [System.ConsoleColor]::DarkGreen
                [System.Console]::Write($left)
                [System.Console]::ForegroundColor = [System.ConsoleColor]::White
                [System.Console]::Write([char]9608)
                [System.Console]::ForegroundColor = [System.ConsoleColor]::DarkGreen
                [System.Console]::Write($right)
                [System.Console]::ResetColor()
                [System.Console]::Write("] ")
                $pos += $dir
                if ($pos -ge ($width - 1)) { $pos = $width - 1; $dir = -1 }
                elseif ($pos -le 0) { $pos = 0; $dir = 1 }
                [System.Threading.Thread]::Sleep(45)
            }
            [System.Console]::CursorVisible = $true
            $pad = " " * ([Math]::Max(10, [System.Console]::WindowWidth - 1))
            [System.Console]::Write("`r" + $pad + "`r")
        }, $token)
    } else {
        if ($Global:AnimCancel) {
            $Global:AnimCancel.Cancel()
            if ($Global:AnimTask) {
                try { [void]$Global:AnimTask.Wait(400) } catch {}
                try { $Global:AnimTask.Dispose() } catch {}
                $Global:AnimTask = $null
            }
            try { $Global:AnimCancel.Dispose() } catch {}
            $Global:AnimCancel = $null
        }
        [System.Console]::CursorVisible = $true
        $pad = " " * ([Math]::Max(10, [System.Console]::WindowWidth - 1))
        [System.Console]::Write("`r" + $pad + "`r")
    }
}

# =====================================================================
# ANIMATED PROGRESS BAR ENGINE (Sweeping White across Green)
# =====================================================================
function Invoke-AnimatedReasoning {
    param(
        [scriptblock]$TaskScriptBlock,
        [string]$Label = "AI is reasoning"
    )
    $job = Start-Job -ScriptBlock$TaskScriptBlock
    $width = 24
$pos = 0
    $direction = 1
    [Console]::CursorVisible =$false
    try {
        while ($job.State -eq "Running") {
            $barLeft  = "=" * $pos
            $barRight = "=" * ($width -$pos - 1)
            Write-Host -NoNewline "`r   $Label [" -ForegroundColor Gray
            Write-Host -NoNewline "$barLeft" -ForegroundColor DarkGreen
            Write-Host -NoNewline ([char]0x2588) -ForegroundColor White
            Write-Host -NoNewline "$barRight" -ForegroundColor DarkGreen
            Write-Host -NoNewline "] " -ForegroundColor Gray
            $pos += $direction
            if ($pos -ge ($width - 1)) {
                $pos = $width - 1
                $direction = -1
            } elseif ($pos -le 0) {
                $pos = 0
                $direction = 1
            }
            Start-Sleep -Milliseconds 45
        }
        Write-Host -NoNewline ("`r" + (" " * ([Console]::WindowWidth - 1)) + "`r")
        return (Receive-Job -Job $job)
    }
    finally {
        [Console]::CursorVisible = $true
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}
# =====================================================================
function Invoke-AnimatedReasoning {
    param(
        [scriptblock]$TaskScriptBlock,
        [string]$Label = "AI is reasoning"
    )

    $job = Start-Job -ScriptBlock $TaskScriptBlock
    $esc = [char]27
    $width = 24
    $pos = 0
    $direction = 1

    # Hide cursor during animation
    [Console]::CursorVisible = $false

    try {
        while ($job.State -eq "Running") {
            # Build bar: green background track with sweeping white highlight
            $barLeft  = "=" * $pos
            $barRight = "=" * ($width - $pos - 1)

            Write-Host -NoNewline "`r   $Label [" -ForegroundColor Gray
            Write-Host -NoNewline "$barLeft" -ForegroundColor DarkGreen
            Write-Host -NoNewline "█" -ForegroundColor White
            Write-Host -NoNewline "$barRight" -ForegroundColor DarkGreen
            Write-Host -NoNewline "] " -ForegroundColor Gray

            # Bounce animation across bar
            $pos +=$direction
            if ($pos -ge ($width - 1)) {
                $pos =$width - 1
                $direction = -1             } elseif ($pos -le 0) {
                $pos = 0$direction = 1
            }

            Start-Sleep -Milliseconds 45
        }

        # Clear line completely when job completes
        Write-Host -NoNewline ("`r" + (" " * ([Console]::WindowWidth - 1)) + "`r")
        $result = Receive-Job -Job$job
        return $result
    }
    finally {
        [Console]::CursorVisible = $true
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}
# =====================================================================
# =====================================================================
# CONTINUATION-RESOLUTION & SESSION PERSISTENCE HOOK
# =====================================================================
$stateFile = Join-Path $PSScriptRoot ".nim_session_state.json"

function Save-SessionCheckpoint {
    param([string]$LastPrompt, [string]$LastResponse, [string]$Status="Active")
    $checkpoint = [PSCustomObject]@{
        Timestamp    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        CommitHash   = (git rev-parse HEAD 2>$null)
        Branch       = (git rev-parse --abbrev-ref HEAD 2>$null)
        LastPrompt   = $LastPrompt
        LastResponse = $LastResponse
        Status       = $Status
    }
    $checkpoint | ConvertTo-Json -Depth 4 | Set-Content -Path $stateFile -Encoding UTF8
}

function Check-SessionResume {
    if (Test-Path $stateFile) {
        try {
            $prev = Get-Content -Path $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($prev.Status -eq "Interrupted" -or $prev.Status -eq "Active") {
                Write-Host "`n[CONTINUATION DETECTED] Unfinished or interrupted session found from $($prev.Timestamp)" -ForegroundColor Yellow
                Write-Host "Prior prompt: `"$($prev.LastPrompt)`"" -ForegroundColor DarkGray
                $ans = Read-Host "Resume previous session state? (Y/n)"
                if ($ans -notmatch "^[Nn]") {
                    Write-Host "[RESUMED] Context restored to active memory." -ForegroundColor Green
                    return $prev
                }
            }
        } catch {}
    }
    return $null
}

$resumedSession = Check-SessionResume
# =====================================================================
function Get-ConsoleTimestamp {
    return "[{0:yyyy-MM-dd hh:mm tt}]" -f (Get-Date)
}


function Get-RemoteBranches {
    Write-Host "Querying GitHub remote..." -ForegroundColor DarkGray
    $raw = git ls-remote --heads origin 2>$null
    $branches = @()
    if ($raw) {
        foreach ($line in $raw) {
            if ($line -match 'refs/heads/(.+)$') {
                $branches += $matches[1].Trim()
            }
        }
    }
    return $branches
}

function Select-GitHubBranch {
    $branches = Get-RemoteBranches
    if ($branches.Count -eq 0) {
        Write-Host "No remote branches found or remote unreachable." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return $null
    }

    Write-Host "`nAvailable branches on GitHub:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $branches.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $branches[$i]) -ForegroundColor Cyan
    }
    Write-Host ""
    $choice = Read-Host "Select branch number (or Enter to cancel)"
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and$idx -lt $branches.Count) {$selected = $branches[$idx]

            # Auto-stash check: inspect working tree for unstaged/staged dirty files
            $status = git status --porcelain 2>$null
            if ($status) {
                $stashTag = "auto-stash-pre-branch-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))"
                Write-Host "Uncommitted local changes detected. Creating stash: $stashTag..." -ForegroundColor Yellow
                git stash push --include-untracked -m $stashTag 2>$null
                Write-Host "Work stashed safely." -ForegroundColor Green
            }

            Write-Host "Switching to origin/$selected and aligning local tree..." -ForegroundColor Green
            git fetch origin $selected 2>$null
            git checkout -B $selected "origin/$selected" --force 2>$null
            git reset --hard "origin/$selected" 2>$null
            Start-Sleep -Seconds 1
            return $selected
        }
    }
    return $null
}

function Render-Banner {
    Clear-Host
    $blockWidth = 75
    $winWidth =$Host.UI.RawUI.WindowSize.Width
    if ($winWidth -le 0) { $winWidth = 100 }$padLeft = [Math]::Max(0, [int](($winWidth -$blockWidth) / 2))
    $margin = " " * $padLeft

    $divider    = '=' * $blockWidth
    $subDivider = '-' * $blockWidth
    $title      = "NVIDIA NIM AGENTIC GIT CONSOLE"
    $titlePad   = " " * [Math]::Max(0, [int](($blockWidth -$title.Length) / 2))

    $curDir = (Get-Location).Path
    $curRemote = (git config --get remote.origin.url 2>$null)
    if (-not $curRemote) {$curRemote = "No remote configured" }
    
    $remoteBranch = (git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
    if (-not $remoteBranch) { 
        $curBranch = (git branch --show-current 2>$null)
        $remoteBranch = "origin/$curBranch"
    }

    Write-Host "$margin$divider" -ForegroundColor Green
    Write-Host "$margin$titlePad$title" -ForegroundColor Green
    Write-Host "$margin$divider" -ForegroundColor Green
    Write-Host "$margin$('Model'.PadRight(12)):$Global:Model" -ForegroundColor Cyan
    Write-Host "$margin$('Directory'.PadRight(12)):$curDir" -ForegroundColor DarkGray
    Write-Host "$margin$('Git Remote'.PadRight(12)):$curRemote" -ForegroundColor DarkGray
    Write-Host "$margin$('GitHub Ref'.PadRight(12)):$remoteBranch (synced)" -ForegroundColor Yellow
    Write-Host "$margin$('Time'.PadRight(12)):$(Get-ConsoleTimestamp)" -ForegroundColor Gray
    Write-Host "$margin$('Commands'.PadRight(12)): :branch (auto-stash picker), :sync, 'clear', 'exit'" -ForegroundColor DarkCyan
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

    if ($userInput -eq ":branch") {
        $chosen = Select-GitHubBranch
        Render-Banner
        continue
    }

    if ($userInput -eq ":sync") {
        Write-Host "Resetting local tree to match GitHub verbatim..." -ForegroundColor DarkGray
        git fetch origin --prune 2>$null
        $current = (git branch --show-current 2>$null)
        git reset --hard "origin/$current" 2>$null
        Start-Sleep -Seconds 1
        Render-Banner
        continue
    }

    $Messages.Add(@{ role = "user"; content = $userInput })

    try {
        $body = @{
            model       = $Global:Model
            messages    = $Messages
            max_tokens  = 200
            temperature = 0.2
        } | ConvertTo-Json -Depth 5



        $ts = Get-ConsoleTimestamp
        Write-Host "$ts AI > " -ForegroundColor Cyan -NoNewline
        Write-Host $aiReply "`n"

        $Messages.Add(@{ role = "assistant"; content = $aiReply })
    }
    catch {
        Write-Host "`n[Error]: $($_.Exception.Message)`n" -ForegroundColor Red
    }
}
