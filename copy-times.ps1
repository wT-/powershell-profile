function Copy-Times {
    <#
    .SYNOPSIS
        Copy file created/modified dates over from A to B
    #>

    [CmdletBinding()]
    Param (
        # What to process. File/dir
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Source,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$Target,
        [Parameter(Mandatory=$false)]
        [switch]$Silent = $false
    )

    if (!(Test-Path $Source)) {
        Write-Error "Invalid source: $Source" -Category ObjectNotFound
        return
    } elseif (!(Test-Path $Target)) {
        Write-Error "Invalid target: $Target" -Category ObjectNotFound
        return
    }
    $From = Get-Item $Source
    $To = Get-Item $Target
    if (!($Silent)) {
        Write-Host "($Target).CreationTime:"
        Write-Host "$($From.CreationTime) ->"
        Write-Host "$($To.CreationTime)"
    }
    $To.CreationTime = $From.CreationTime
    if (!($Silent)) {
        Write-Host "($Target).LastWriteTime:"
        Write-Host "$($From.LastWriteTime) ->"
        Write-Host "$($To.LastWriteTime)"
    }
    $To.LastWriteTime = $From.LastWriteTime
}
