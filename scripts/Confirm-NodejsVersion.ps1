<#
.SYNOPSIS
    Check if Node.js has a new LTS version.
.DESCRIPTION
    This script will check if Node.js has a new LTS.
    If a newer version is available, it will create an issue in the repository.
#>

#Requires -Version 7.2

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    $ConfigFile = './.devcontainer/src/devcontainer.json'
)

try {
    Push-Location -Path (Split-Path -Path $PSScriptRoot -Parent)
    $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    [semver]$currentVersion = ($config.features.PSObject.Properties | Where-Object { $_.Name -like "*node*" } | Select-Object -ExpandProperty Value).version

    if (-not $currentVersion) {
        Write-Verbose "Node.js is not defined in the devcontainer.json file."
        exit 0
    }

    $index = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -Verbose:$false -ErrorAction Stop
    [semver]$latestLTSVersion = ($index | Where-Object { $_.lts -ne $false } | Sort-Object { [semver]$_.version.TrimStart('v') } -Descending | Select-Object -First 1).version.TrimStart('v')

    if ($latestLTSVersion.Major -gt $currentVersion.Major) {
        $issueTitle = "Update Node.js to LTS version ``$($latestLTSVersion.Major).x.x``"
        $issueBody = "Currently defined LTS version: ``$($currentVersion.Major).x.x```nLatest available LTS version: ``$($latestLTSVersion.Major).x.x``"

        $existingIssues = @((gh issue list --search "$issueTitle" --state open --json title | ConvertFrom-Json).title)
        if ($existingIssues.Contains($issueTitle)) {
            Write-Verbose "Issue already existing for: - $issueTitle"
        }
        else {
            if ($PSCmdlet.ShouldProcess($issueTitle, "Create a new GitHub issue")) {
                gh issue create --label "upstream-update" --title "$issueTitle" --body "$issueBody"
                Write-Host -ForegroundColor Green "Created a new GitHub issue: - $issueTitle"
            }
        }
    }
    else {
        Write-Verbose "The current version of Node.js is up-to-date."
    }
}
catch {
    Write-Error "Failed to confirm current Node.js version. $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location
}
