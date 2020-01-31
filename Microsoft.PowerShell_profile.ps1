# Replaced by pshazz (?)
#Import-Module posh-git

# https://github.com/lukesampson/pshazz
try { $null = gcm pshazz -ea stop; pshazz init 'default' } catch { }

# Chocolatey profile stuff (?)
. $PSScriptRoot\choco.ps1

# PSReadLine stuff
. $PSScriptRoot\psreadline.ps1

# Rustup completions
# Update by running:
#   rm ${env:USERPROFILE}\Documents\WindowsPowerShell\rustup_completions.ps1
#   rustup completions powershell >> ${env:USERPROFILE}\Documents\WindowsPowerShell\rustup_completions.ps1
. $PSScriptRoot\rustup_completions.ps1
