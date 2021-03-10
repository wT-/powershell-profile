function Copy-Times {
    <#
    .SYNOPSIS
        Copy file created/modified dates over from Source to Target
    #>

    [CmdletBinding()]
    Param (
        # What to process. File/dir
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" \t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Source,
        [Parameter(Position=1, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" \t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Target,
        [Parameter(Mandatory=$false)]
        [switch]$Silent = $false
    )

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

Export-ModuleMember -Function Copy-Times

function Move-ItemWithCreationTime {
    <#
    .SYNOPSIS
        Move-Item but preserve .CreationTime when moving between drives.
        Will most likely blow up on anything but file -> file
    #>

    [CmdletBinding()]
    Param (
        # What to process. File/dir
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" \t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Path,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$Destination
    )

    $Item = Get-Item $Path
    $OriginalCreationTime = $Item.CreationTime

    $MovedItem = Move-Item -Path $Path -Destination $Destination -PassThru

    if (Test-Path -Path $MovedItem.FullName -PathType Leaf) {
        $MovedItem.CreationTime = $OriginalCreationTime
    } else {
        Write-Host "Didn't modify CreationTime: Destination not a file."
    }

}

Export-ModuleMember -Function Move-ItemWithCreationTime
