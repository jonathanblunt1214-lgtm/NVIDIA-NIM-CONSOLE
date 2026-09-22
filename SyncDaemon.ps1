$repo = $PSScriptRoot
while ($true) {
    try {
        git -C $repo fetch origin main --quiet 2>$null
        $local = (git -C $repo rev-parse HEAD 2>$null)
        $remote = (git -C $repo rev-parse origin/main 2>$null)
        if ($local -and $remote -and ($local -ne $remote)) {
            $dirty = (git -C $repo status --porcelain 2>$null)
            if ($dirty) {
                git -C $repo stash push -m "auto-sync-stash" --quiet 2>$null
                git -C $repo pull --rebase origin main --quiet 2>$null
                git -C $repo stash pop --quiet 2>$null
            } else {
                git -C $repo pull --rebase origin main --quiet 2>$null
            }
        }
    } catch {}
    Start-Sleep -Seconds 900
}