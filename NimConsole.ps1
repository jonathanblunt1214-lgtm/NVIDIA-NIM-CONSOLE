function Get-ConsoleTimestamp {
    $nowUtc = [DateTime]::UtcNow
    $month = $nowUtc.Month
    $offset = if ($month -ge 3 -and $month -lt 11) { -5 } else { -4 }
    $localTime = $nowUtc.AddHours($offset)
    return "[{0:yyyy-MM-dd hh:mm tt}]" -f $localTime
}
$ApiKey = [Environment]::GetEnvironmentVariable("NGC_API_KEY", "User");
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = "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";
    [Environment]::SetEnvironmentVariable("NGC_API_KEY", $ApiKey, "User");
}

$Model = "nvidia/nemotron-3.5-lightning-30b-a3b";
$Url   = "https://integrate.api.nvidia.com/v1/chat/completions";

Clear-Host;

$gitBranch = "";
$gitRemote = "";
$headPath = Join-Path (Get-Location).Path ".git\HEAD";
$configPath = Join-Path (Get-Location).Path ".git\config";

if (Test-Path $headPath) {
    try {
        $head = Get-Content $headPath -Raw -ErrorAction SilentlyContinue;
        if ($head -match 'ref: refs/heads/(.+)') { $gitBranch = $matches[1].Trim(); }
    } catch {}
}

if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw -ErrorAction SilentlyContinue;
        if ($cfg -match 'url\s*=\s*(.+)') { $gitRemote = $matches[1].Trim(); }
    } catch {}
}

$prompt = "You are an autonomous Git and coding assistant in PowerShell. Current Directory: " + (Get-Location).Path + ". Git Branch: " + $(if ($gitBranch) { $gitBranch } else { "No Git repo" }) + ". Git Remote: " + $(if ($gitRemote) { $gitRemote } else { "None" }) + ". When proposing a command to run, enclose it in a single ```powershell code block.";

$History = New-Object System.Collections.Generic.List[hashtable];
$History.Add(@{ role = "system"; content = $prompt });

function Send-Chat($msgs) {$hdr = @{
        "Authorization" = "Bearer " + $ApiKey;
        "Accept"        = "application/json";
    };
    $arr = New-Object System.Collections.ArrayList;
    for ($i = 0; $i -lt $msgs.Count; $i++) {$item = $msgs[$i];
        $null =$arr.Add([ordered]@{
            role    = $item["role"];
            content = $item["content"];
        });
    }
    $payload = [ordered]@{
        model       = $Model;
        messages    = $arr;
        max_tokens  = 2048;
        temperature = 0.2;
    };
    $body = ConvertTo-Json -InputObject $payload -Depth 10;
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body);
        $res = Invoke-RestMethod -Uri $Url -Method Post -Headers $hdr -ContentType "application/json; charset=utf-8" -Body $bytes;
        return $res.choices[0].message.content;
    } catch {
        Write-Host "`nAPI Error: $($_.Exception.Message)" -ForegroundColor Red;
        return $null;
    }
}

Write-Host "==========================================================" -ForegroundColor DarkCyan;
Write-Host "       NVIDIA NIM AGENTIC GIT CONSOLE                     " -ForegroundColor Cyan;
Write-Host "==========================================================" -ForegroundColor DarkCyan;
Write-Host ("Model       : " + $Model) -ForegroundColor Yellow;
Write-Host ("Directory   : " + (Get-Location).Path) -ForegroundColor Gray;
if ($gitRemote) {
    Write-Host ("Git Remote  : " + $gitRemote) -ForegroundColor Green;
    Write-Host ("Git Branch  : " + $gitBranch) -ForegroundColor Green;
} else {
    Write-Host "Git Repo    : None in current directory" -ForegroundColor DarkGray;
}
Write-Host "Commands    : Type 'exit' to quit, 'clear' to reset." -ForegroundColor DarkGray;
Write-Host "----------------------------------------------------------" -ForegroundColor DarkCyan;
Write-Host "";

while ($true) {
    Write-Host "You > " -ForegroundColor Green -NoNewline;
    $val = Read-Host;
    if ([string]::IsNullOrWhiteSpace($val)) { continue; }
    $cmd = $val.Trim().ToLower();
    if ($cmd -eq "exit" -or $cmd -eq "quit") { break; }
    if ($cmd -eq "clear") {
        Clear-Host;
        $History.Clear();
        $History.Add(@{ role = "system"; content = $prompt });
        Write-Host "[History Cleared]" -ForegroundColor DarkYellow;
        continue;
    }

    $History.Add(@{ role = "user"; content = $val });
    $loop = $true;
    while ($loop) {
        Write-Host "`nAI is reasoning..." -ForegroundColor DarkGray;
        $reply = Send-Chat $History;
        if ($null -eq $reply) { break; }

        Write-Host "`r                  `r" -NoNewline;
        Write-Host "$((Get-ConsoleTimestamp)) AI > " -ForegroundColor Cyan;
        Write-Host $reply;
        Write-Host "";

        $History.Add(@{ role = "assistant"; content = $reply });

        $tick = [char]96;
        $pat = "(?ms)" + $tick + "{3}powershell\s*\r?\n(.*?)\r?\n" + $tick + "{3}";
        if ($reply -match $pat) {
            $toRun =$matches[1].Trim();
            Write-Host "----------------------------------------------------------" -ForegroundColor DarkYellow;
            Write-Host "Proposed Action:" -ForegroundColor Yellow;
            Write-Host ("  " + $toRun) -ForegroundColor White;
            Write-Host "----------------------------------------------------------" -ForegroundColor DarkYellow;
            Write-Host "Run this command? [Y/n]: " -ForegroundColor Cyan -NoNewline;
            $confirm = Read-Host;
            $c =$confirm.Trim().ToLower();
            if ($c -eq "" -or $c -eq "y" -or $c -eq "yes") {
                Write-Host "`nRunning..." -ForegroundColor DarkGray;
                try {
                    $out = Out-String -InputObject (Invoke-Expression $toRun 2>&1);
                    if ([string]::IsNullOrWhiteSpace($out)) { $out = "[Executed successfully with no output]"; }
                } catch {
                    $out = "Error: " + $_.Exception.Message;
                }
                Write-Host "Output:" -ForegroundColor DarkCyan;
                Write-Host $out -ForegroundColor Gray;
                $History.Add(@{ role = "user"; content = "Command Output:`n" + $out });
            } else {
                Write-Host "Command skipped." -ForegroundColor DarkYellow;
                $History.Add(@{ role = "user"; content = "User declined command." });
                $loop =$false;
            }
        } else {
            $loop =$false;
        }
    }
}




# --- SESSION CONTEXT HYDRATION HOOK ---
$sessionContextPath = Join-Path $PSScriptRoot "SESSION_CONTEXT.md"
if (Test-Path $sessionContextPath) {
    $sessionContext = Get-Content $sessionContextPath -Raw
    $Global:SystemInstruction += "`n`n[ACTIVE HISTORICAL SESSION MEMORY]:`n$sessionContext"
    Write-Host "[Hydrated]: Session memory and protocols loaded successfully." -ForegroundColor Green
}
# ---------------------------------------

# --- SESSION CONTEXT HYDRATION HOOK ---
$sessionContextPath = Join-Path $PSScriptRoot "SESSION_CONTEXT.md"
if (Test-Path $sessionContextPath) {
    $sessionContext = Get-Content $sessionContextPath -Raw
    $Global:SystemInstruction += "`n`n[ACTIVE HISTORICAL SESSION MEMORY]:`n$sessionContext"
    Write-Host "[Hydrated]: Session memory and protocols loaded successfully." -ForegroundColor Green
}
# ---------------------------------------

