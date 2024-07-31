<#
.SYNOPSIS
    Check if PowerShell has a new version.
.DESCRIPTION
    This script will check if PowerShell has a new major or minor version.
    If a newer version is available, it will create an issue in the repository.
.PARAMETER ConfigFile
    The path to the devcontainer.json file.
#>

#Requires -Version 7.2

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    $ConfigFile = './.devcontainer/src/devcontainer.json'
)

try {
    Push-Location -Path (Split-Path -Path $PSScriptRoot -Parent)
    $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    [semver]$currentVersion = ($config.features.PSObject.Properties | Where-Object { $_.Name -like "*powershell-extended*" } | Select-Object -ExpandProperty Value).version

    if (-not $currentVersion) {
        Write-Verbose "PowerShell Extended is not defined in the devcontainer.json file."
        exit 0
    }

    [semver]$latestRelease = (gh release view --repo PowerShell/PowerShell --json tagName -q ".tagName").TrimStart('v')
    if (
        $latestRelease.Major -gt $currentVersion.Major -or
        $latestRelease.Minor -gt $currentVersion.Minor
    ) {
        $issueTitle = "Update PowerShell to version ``$($latestRelease.Major).$($latestRelease.Minor).x``"
        $issueBody = "Currently defined version: ``$($currentVersion.Major).$($currentVersion.Minor).x```nLatest available version: ``$($latestRelease.Major).$($latestRelease.Minor).x``"

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
        Write-Verbose "The current version of PowerShell is up-to-date."
    }
}
catch {
    Write-Error "Failed to confirm current PowerShell version. $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location
}
