<#
.SYNOPSIS
    WorkHub — AI-Powered Workplace Automation
    Commands: status | daily | weekly | organize | meeting | research | review | setup
#>

[CmdletBinding()]
param(
    [ValidateSet("status","daily","weekly","organize","meeting","research","review","setup")]
    [string]$Command = "status",
    [string]$Extra = ""
)

$HubRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function banner($t) {
    Write-Host "=============================================" -ForegroundColor Magenta
    Write-Host "  WorkHub — $t" -ForegroundColor Magenta
    Write-Host "=============================================" -ForegroundColor Magenta
}

switch ($Command) {
    "status" {
        banner "System Status"
        Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
        $tools = @(
            @{n="gh CLI";c=(Test-Path "C:\Program Files\GitHub CLI\gh.exe")},
            @{n="Plex";c=(Get-Command plex -EA 0)}, @{n="n8n";c=(Get-Command n8n -EA 0)},
            @{n="Node.js";c=(Get-Command node -EA 0)}, @{n="Git";c=(Get-Command git -EA 0)}
        )
        Write-Host "`n--- Tools ---" -ForegroundColor Yellow
        foreach ($t in $tools) {
            Write-Host ("  [{0}] {1}" -f $(if($t.c){"+"}else{"-"}), $t.n) -ForegroundColor $(if($t.c){"Green"}else{"Red"})
        }
        Write-Host "`nCommands: status | daily | weekly | organize | meeting | review | setup" -ForegroundColor Gray
    }
    "daily" {
        banner "Daily Developer Digest"
        & "C:\Program Files\GitHub CLI\gh.exe" search prs "author:@me updated:>=$(Get-Date -Format 'yyyy-MM-dd')" --limit 10 --json number,title,state,url 2>&1 |
            ConvertFrom-Json | ForEach-Object { Write-Host ("  [{0}] {1} — {2}" -f $_.state, $_.number, $_.title) }
    }
    "weekly" {
        banner "Weekly Git Report"
        $top = git rev-parse --show-toplevel 2>$null
        if (-not $top) { Write-Host "Not in a git repo" -ForegroundColor Red; return }
        $since = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
        $count = (git log --since=$since --oneline 2>$null | Measure-Object).Count
        Write-Host ("Repo: {0}" -f (Split-Path $top -Leaf))
        Write-Host ("Commits (7d): {0}" -f $count)
    }
    "review" {
        banner "AI Code Review"
        $plex = Get-Command plex -EA 0
        if (-not $plex) { Write-Host "Plex not installed" -ForegroundColor Red; return }
        Write-Host "Run: plex review" -ForegroundColor Yellow
    }
    default { Write-Host "Use: workhub status|daily|weekly|review" -ForegroundColor Yellow }
}
