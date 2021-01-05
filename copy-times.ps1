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
        Write-Host "Old:" -NoNewline -ForegroundColor Black -BackgroundColor DarkRed
        Write-Host " $($To.CreationTime)"
        Write-Host "New:" -NoNewline -ForegroundColor Black -BackgroundColor DarkGreen
        Write-Host " $($From.CreationTime)"
    }
    $To.CreationTime = $From.CreationTime
    if (!($Silent)) {
        Write-Host "($Target).LastWriteTime:"
        Write-Host "Old:" -NoNewline -ForegroundColor Black -BackgroundColor DarkRed
        Write-Host " $($To.LastWriteTime)"
        Write-Host "New:" -NoNewline -ForegroundColor Black -BackgroundColor DarkGreen
        Write-Host " $($From.LastWriteTime)"
    }
    $To.LastWriteTime = $From.LastWriteTime
}
