<#
.SYNOPSIS
Backup / Restore of git submodules with sparse-checkout support

.DESCRIPTION
Handles git submodules based on the information in the .gitmodules file with support of partial checkouts,
if the submodule is configured in file .gitmodules with a property "sparse-checkout", e.g.:

[submodule "external/app1"]
    path = external/app1
    url = ../../apps/app1.git
    sparse-checkout = docs/adr 'path with spaces' scripts

.PARAMETER Command
Specifies subcommand to be executed. Possible values are "backup" and "restore".

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
cmd> powershell -ExecutionPolicy Bypass -NoLogo -Command ".\gitmodule-sparse-checkout.ps1 restore"
Restores / updates git submodules based on the information in the .gitmodules file. It can handle partial checkouts, if the submodule is configured in file .gitmodules with a property "sparse-checkout".

.EXAMPLE
PS> .\gitmodule-sparse-checkout.ps1 restore
Restores / updates git submodules based on the information in the .gitmodules file. It can handle partial checkouts, if the submodule is configured in file .gitmodules with a property "sparse-checkout".

.EXAMPLE
cmd> powershell -ExecutionPolicy Bypass -NoLogo -Command ".\gitmodule-sparse-checkout.ps1 backup"
Backups sparse-checkout filters of git submodules into .gitmodules file (see property "sparse-checkout").

.EXAMPLE
PS> .\gitmodule-sparse-checkout.ps1 backup
Backups sparse-checkout filters of git submodules into .gitmodules file (see property "sparse-checkout").


.LINK
The behavior is based on a python script located here: 
https://github.com/Reedbeta/git-partial-submodule/blob/main/git-partial-submodule.py

.LINK
See also: https://git-scm.com/docs/git-sparse-checkout

.NOTES
Version: 1.0.0

Copyright (c) 2023 Marco Stolze alias mcpride
The source code of this repository is under MIT license. See the LICENSE file for details. 
#>



[CmdletBinding()]
param( [ValidateSet('restore', 'backup')] [string]$Command = "restore" )


#-----------------------------------------------------------------------------


function Restore-GitModule {
    param (
        [string] $ModuleName,
        [string] $GitConfigModulesDir
    )
    Write-Host Restoring $ModuleName ...
    $moduleDir = git config -f .gitmodules --get submodule.$ModuleName.path
    $moduleBranch = git config -f .gitmodules --get submodule.$ModuleName.branch
    $sparseCheckout = git config -f .gitmodules --get submodule.$ModuleName.sparse-checkout
    # if the local module path was found:
    if ($moduleDir) {
        $moduleConfigDir = (Join-Path -Path "$GitConfigModulesDir" -ChildPath "$ModuleName").Replace("\", "/")
        $moduleConfigDirExists = Test-Path "$moduleConfigDir"
        # check, if the module metadata path not initialized:
        if ($moduleConfigDirExists -eq $false) {
            write-host "git submodule init -- ""$moduleDir"""
            # write submodule to git configuration
            git submodule init -- "$moduleDir"
            # add the git metadata modules parent path, if not exists
            $moduleConfigParentDir = (Split-Path "$moduleConfigDir" -Parent).Replace("\", "/")
            if (!(Test-Path -PathType container "$moduleConfigParentDir")) {
                New-Item -ItemType Directory -Path "$moduleConfigParentDir"
            }
            # get the module's git url from git configuration
            $moduleUrl = git config --get submodule.$ModuleName.url
            # clone the module with filter and no checkout, to initialize the  module's git metadata
            $gitArgs = @(
                    "clone", 
                    "--filter=blob:none", "--no-checkout",
                    "--separate-git-dir", """$moduleConfigDir"""
                )
            # Is a module branch configured?
            if ($moduleBranch) {
                $gitArgs += @(
                    "--branch", "$moduleBranch"
                )
            }
            # Is sparse-checkout configured?
            if ($sparsecheckout) {
                $gitArgs += @(
                    "--sparse"
                )
            }
            $gitArgs += @(
                "--",
                $moduleUrl,
                """$moduleDir"""
            )
            write-host "git" $gitArgs
            & "git" $gitArgs
        }
        # configure optional partial checkout settings stored in .gitmodules
        if ($sparsecheckout) {
            # initialize sparse-checkout
            $gitArgs = @(
                    "-C", """$moduleDir""",
                    "sparse-checkout",
                    "init",
                    "--cone",
                    "--sparse-index"
                )
            write-host "git" $gitArgs
            & "git" $gitArgs
            # add directory filters
            [regex]::Split( $sparsecheckout, "'? (?=(?:[^']|'[^']*')*$)'?" ) | ForEach-Object { 
                $gitArgs = @(
                    "-C", """$moduleDir""",
                    "sparse-checkout",
                    "add"
                )
                $gitArgs += @( $_.Trim("'") )
                write-host "git" $gitArgs
                & "git" $gitArgs
            }
        }
        # update submodule, if active
        $isModuleActive = [boolean](git config --get submodule.$ModuleName.active)
        if ($isModuleActive -eq $true) {
            write-host "git submodule update --force --no-fetch --remote -- ""$moduleDir"""
            git submodule update --force --no-fetch --remote -- "$moduleDir"
        }
    }
}


#-----------------------------------------------------------------------------


function Backup-GitModule {
    param (
        [string] $ModuleName,
        [string] $GitConfigModulesDir
    )
    Write-Host Backup $ModuleName ...
    $moduleDir = git config -f .gitmodules --get submodule.$ModuleName.path
    if ($moduleDir) {
        $moduleConfigDir = (Join-Path -Path "$GitConfigModulesDir" -ChildPath "$ModuleName").Replace("\", "/")
        if (Test-Path -Path "$moduleConfigDir") {
            $moduleConfigInfoDir = (Join-Path -Path "$moduleConfigDir" -ChildPath "info").Replace("\", "/")
            if (Test-Path -Path "$moduleConfigInfoDir") {
                $sparseCheckout = (Join-Path -Path "$moduleConfigInfoDir" -ChildPath "sparse-checkout").Replace("\", "/")
                # check, if "sparse-checkout" file exists in module metadata:
                if (Test-Path -Path "$sparseCheckout" -PathType Leaf) {
                    [string[]] $readItems = git -C "$moduleDir" sparse-checkout list
                    $sparseItems = @()
                    $readItems | ForEach-Object {
                        if ($_.Contains(' ')) {
                            $sparseItems += "'$_'"
                        } else {
                            $sparseItems += $_
                        }
                    }
                    # configure sparse-checkout in .gitmodules
                    Write-Host "git config -f .gitmodules submodule.$ModuleName.sparse-checkout $sparseItems"
                    git config -f .gitmodules submodule.$ModuleName.sparse-checkout  "$sparseItems"
                } else {
                    # remove sparse-checkout in .gitmodules
                    Write-Host "git config -f .gitmodules --unset submodule.$ModuleName.sparse-checkout"
                    git config -f .gitmodules --unset submodule.$ModuleName.sparse-checkout
                }
            }
        }
    }
}


#-----------------------------------------------------------------------------


$gitRootDir = git rev-parse --show-toplevel
$origCurrentDir = Get-Location
try {
    Set-Location $gitRootDir

    $gitConfigDir = git rev-parse --git-dir
    $gitConfigModulesDir = (Join-Path -Path $gitConfigDir -ChildPath "modules").Replace("\", "/")

    # Get all submodule names from .gitmodules file:
    $submodules = Select-String -Path .gitmodules '^\[submodule \"(.*)\"]$' -AllMatches | Foreach-Object {
            $_.Matches
        } | Foreach-Object {
            $_.Groups[1].Value
        }

    # for each found submodule do:
    $submodules | ForEach-Object {
        if ($Command -eq "backup") {
            Backup-GitModule -ModuleName $_ -GitConfigModulesDir $gitConfigModulesDir
        } elseif ($Command -eq "restore") {
            Restore-GitModule -ModuleName $_ -GitConfigModulesDir $gitConfigModulesDir
        }
    }
} finally {
    Set-Location $origCurrentDir
}