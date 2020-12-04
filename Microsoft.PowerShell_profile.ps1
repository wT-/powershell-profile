# Chocolatey profile stuff (?)
. $PSScriptRoot\choco.ps1

# PSReadLine stuff
. $PSScriptRoot\psreadline.ps1

# Encode-Video cmdlet to... encode videos!
. $PSScriptRoot\encode-video.ps1

# Rustup completions
# Update by running:
#   rm ${env:USERPROFILE}\Documents\WindowsPowerShell\rustup_completions.ps1
#   rustup completions powershell >> ${env:USERPROFILE}\Documents\WindowsPowerShell\rustup_completions.ps1
. $PSScriptRoot\rustup_completions.ps1

$ENV:STARSHIP_CONFIG = "$HOME\starship.toml"
Invoke-Expression (&starship init powershell)
