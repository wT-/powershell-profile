# Chocolatey profile stuff (?)
. $PSScriptRoot\choco.ps1

# PSReadLine stuff
. $PSScriptRoot\psreadline.ps1

# Cmdlet to preview the available shell colors
. $PSScriptRoot\print-shell-colors.ps1

# Encode-Video cmdlet to... encode videos!
# . $PSScriptRoot\encode-video.ps1
Import-Module Compress-Video

# Cmdlet to copy file created/modified dates over from $source to $target
. $PSScriptRoot\copy-times.ps1

# Rustup completions
# TODO: Check that Rustup is installed
rustup completions powershell | Out-String | Invoke-Expression

# This is for messing with the console color scheme
# https://github.com/mmims/PSConsoleTheme
# Seems obsolete if using the new Windows Terminal, but also hopelessly broken in the old conhost.
# Import-Module PSConsoleTheme

# Starship is the fancy prompt made in Rust
$ENV:STARSHIP_CONFIG = "$HOME\starship.toml"
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
try { $null = gcm pshazz -ea stop; pshazz init 'default' } catch { }
