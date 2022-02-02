# Chocolatey profile stuff (?)
. $PSScriptRoot\choco.ps1

# PSReadLine stuff
. $PSScriptRoot\psreadline.ps1

# Cmdlet to preview the available shell colors
. $PSScriptRoot\print-shell-colors.ps1

# Encode-Video cmdlet to... encode videos!
# . $PSScriptRoot\encode-video.ps1
Import-Module Compress-Video

# Random cmdlets I've made
Import-Module MyRandomModules

# Rustup completions
# TODO: Check that Rustup is installed
rustup completions powershell | Out-String | Invoke-Expression

# dotnet CLI completions
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
  param($commandName, $wordToComplete, $cursorPosition)
  dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}

# Starship is the fancy prompt made in Rust
Invoke-Expression (&starship init powershell)
starship completions | Out-String | Invoke-Expression

# This sets the Window title to the current location when the Starship prompt is called
# TODO: Check that Starship is installed
$promptScript = (Get-Item function:prompt).ScriptBlock
function Prompt {
    $path = Get-Location
    $host.ui.RawUI.WindowTitle = $path
    & $promptScript
}

# Pshazz has mostly prompt stuff but also few other things.
# Configured by the Pshazz theme files.
# See https://github.com/lukesampson/pshazz
try { $null = gcm pshazz -ea stop; pshazz init } catch { }

# I feel like this could break stuff
set-alias .. cd..

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
