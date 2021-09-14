function Copy-Times {
    <#
    .SYNOPSIS
        Copy file created/modified dates over from Source to Target
    #>

    [CmdletBinding()]
    Param (
        # What to process. File/dir
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" `t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Source,
        [Parameter(Position=1, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" `t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
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
    # TODO: How do you pass all other arguments to Move-Item?
    # Like in Python you'd have *args and **args to trap everything not mentioned

    [CmdletBinding()]
    Param (
        # What to process. File/dir
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" `t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Path,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$Destination
    )
    $Path = [WildcardPattern]::Escape($Path.Trim(" `t"))
    # FIXME: This escapes []'s but they actually should not be escaped. I wonder if anything needs escaping?
    # The last Test-Path fails otherwise. It seems to fail even without escaping. Investigate
    $Destination = [WildcardPattern]::Escape($Destination.Trim(" `t"))
    # $Destination = $Destination.Trim(" `t")

    $Item = Get-Item $Path
    $OriginalCreationTime = $Item.CreationTime

    # Stop if file already exists
    if (Test-Path -Path $Destination) {
        Write-Error "$Destination already exists." -ErrorAction Stop
        # Maybe redundant, but I think ErrorAction could be overridden, which would be bad
        return
    }

    Write-Host "Moving '$Path' to '$Destination'... " -NoNewline

    # Create empty file with -Force to create all intermediate directories
    New-Item $Destination -ItemType File -Force > $null
    # -Force overwrites the previously created empty file
    $MovedItem = Move-Item -Path $Path -Destination $Destination -PassThru -Force

    # Check if move succeeded  to end the line
    if ($?) {
        Write-Host "Done."
    } else {
        # Maybe this is unnecessary because an error has already been printed anyway at this point?
        Write-Host ''
    }

    # Why did I do this? What caused the error before?
    if (Test-Path -Path $MovedItem.FullName -PathType Leaf) {
        $MovedItem.CreationTime = $OriginalCreationTime
    } else {
        Write-Host "Didn't modify CreationTime: Destination not a file."
    }

}

Export-ModuleMember -Function Move-ItemWithCreationTime

function Move-ItemBetter {
    <#
    .SYNOPSIS
        Move-Item but use Robocopy to get a progress bar and preserve .CreationTime when moving between drives.
    #>

    [CmdletBinding()]
    Param (
        # What to process. File/dir
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" `t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Path,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$Destination
    )

    # $Path = Resolve-Path -Path ([WildcardPattern]::Escape($Path.Trim(" `t")))
    # $Destination = [System.IO.FileInfo]([WildcardPattern]::Escape($Destination.Trim(" `t")))
    $Path = [System.IO.FileInfo]$Path
    $Destination = [System.IO.FileInfo]$Destination

    # WTF, why is this all messed up?
    # Go to console, type
    # $Path = [System.IO.FileInfo]"F:\asd\qwer"
    # $Path.DirectoryName
    # Prints F:\asd
    # And this prints nothing:
    Write-Host $Path.DirectoryName
    Write-Host $Destination
    Write-Host $Destination.DirectoryName

    if (Test-Path -Path $Destination) {
        Write-Error "$Destination already exists." -ErrorAction Stop
        # Maybe redundant, but I think ErrorAction could be overridden, which would be bad
        return
    }

    # /DCOPY:DAT copies everything for dirs (Data, Attributes, Timestamps. Default is DA). Sort of irrelevant here
    # /R:0: do not retry on fail (the number of retries on failed copies default value is 1 million),
    Robocopy $Path.DirectoryName $Destination.DirectoryName $Path.Name /DCOPY:DAT /R:0
    if ($?) {
        Move-Item (Join-Path $Destination.DirectoryName $Path.Name) (Join-Path $Destination.DirectoryName $Destination.Name)
    }

    # 1. Copy file from source to destination using Robocopy, preserving dates (what flag?) and showing a progress bar
    #    See: https://superuser.com/a/1326224


    # TODO:
    # 2. Rename moved file in destination to desired final name with Move-Item because Robocopy doesn't do renames
}

# Export-ModuleMember -Function Move-ItemBetter
