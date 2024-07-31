<#
.SYNOPSIS
    Check if the required resource has a newer version.
.DESCRIPTION
    This script will check if the required resource has a newer version.
    If a newer version is available, it will create an issue in the repository.
.PARAMETER ConfigFile
    The path to the devcontainer.json file.
#>

#Requires -Version 7.2

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    $ConfigFile = './.devcontainer/src/devcontainer.json'
)

function ConvertTo-SemVer {
    param (
        [string]$version,
        [string]$prerelease
    )

    # Split the version into components
    $versionComponents = $version -split '\.'

    # Keep only the first three components (major, minor, patch)
    $semverVersion = -join ($versionComponents[0..2] -join '.')

    # Append the prerelease if it exists
    if ($prerelease) {
        $semverVersion += "-$prerelease"
    }

    # Return the semver-compatible version
    return [semver]$semverVersion
}

try {
    Push-Location -Path (Split-Path -Path $PSScriptRoot -Parent)
    $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    (($config.features.PSObject.Properties | Where-Object { $_.Name -like "*powershell-extended*" } | Select-Object -ExpandProperty Value).resources -split ';').Trim() | ForEach-Object {
        if ($_ -match '^(?:(?<repository>.+?)=)?(?<name>.+?)(?:@(?<version>.+?))?$') {
            Write-Debug "Checking the version of required resource: - $_"
            $repository = $Matches.repository
            $name = $Matches.name
            $version = $Matches.version

            if (-not [string]::IsNullOrEmpty($repository) -and $repository -ne 'PSGallery') { return }
            if ([string]::IsNullOrEmpty($version)) { return }

            $params = @{
                Name        = $name
                Repository  = if ($repository) { $repository } else { 'PSGallery' }
                Prerelease  = if ($version -like '*-*') { $true } else { $false }
                Verbose     = if ($PSBoundParameters.ContainsKey('Verbose')) { $true } else { $false }
                Debug       = $false
                ErrorAction = if ($PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorAction } else { 'Stop' }
            }
            Write-Debug "- Find latest version"
            $latestSemVer = @(Find-PSResource @params) | ForEach-Object {
                ConvertTo-SemVer -version $_.Version -prerelease $_.Prerelease
            } | Sort-Object -Descending | Select-Object -First 1

            $params.Version = $version
            Write-Debug "- Find current version"
            $currentSemVer = @(Find-PSResource @params) | ForEach-Object {
                ConvertTo-SemVer -version $_.Version -prerelease $_.Prerelease
            } | Sort-Object -Descending | Select-Object -First 1

            if ($latestSemVer -gt $currentSemVer) {
                Write-Verbose "A newer version of $name is available: - $($latestSemVer.Major).$($latestSemVer.Minor).x$( if ($latestSemVer.Prerelease) { "-$($latestSemVer.Prerelease)" } )"

                $issueTitle = "Update PowerShell resource ``$name`` to version ``$($latestSemVer.Major).$($latestSemVer.Minor).x$( if ($latestSemVer.Prerelease) { "-$($latestSemVer.Prerelease)" } )``"
                Write-Debug "GitHub issue title: - $issueTitle"

                $issueBody = "Currently defined version: ``$($currentSemVer.Major).$($currentSemVer.Minor).x```nLatest available version: ``$($latestSemVer.Major).$($latestSemVer.Minor).x``"
                Write-Debug "GitHub issue body: - $issueBody"

                $existingIssues = @((gh issue list --search "$issueTitle" --state open --json title | ConvertFrom-Json).title)
                if (-not $?) {
                    Throw "Failed to list GitHub issues."
                }

                if ($existingIssues.Contains($issueTitle)) {
                    Write-Verbose "GitHub issue already existing for: - $issueTitle"
                }
                else {
                    if ($PSCmdlet.ShouldProcess($issueTitle, "Create a new GitHub issue")) {
                        $labelName = "upstream-update"
                        $labelExists = gh label list --json name | ConvertFrom-Json | Where-Object { $_.name -eq $labelName }
                        if (-not $?) {
                            Throw "Failed to list GitHub labels."
                        }

                        # Create the label if it does not exist
                        if (-not $labelExists) {
                            $labelColor = "f29513"
                            $labelDescription = "Label for upstream updates"
                            gh label create $labelName --color $labelColor --description "$labelDescription" 2>&1 | Out-Null
                            if (-not $?) {
                                Throw "Failed to create GitHub label."
                            }
                        }

                        # Create the issue with the label
                        gh issue create --label $labelName --title "$issueTitle" --body "$issueBody" 2>&1 | Out-Null
                        if (-not $?) {
                            Throw "Failed to create a new GitHub issue: - $issueTitle"
                        }
                        else {
                            Write-Host -ForegroundColor Green "Created a new GitHub issue: - $issueTitle"
                        }
                    }
                }
            }
            else {
                Write-Verbose "The current version of $name is up-to-date."
            }
        }
        else {
            Write-Error "Failed to parse the required resource: - $_"
        }
    }
}
catch {
    Write-Error "Failed to confirm version of required resources. $($_.Exception.Message)"
    exit 1
}
finally {
    Pop-Location
}
