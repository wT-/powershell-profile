# TODO: Let me input a file that has paths to everything I wanna re-encode:
#     Check https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content?view=powershell-7
#      -> Reads file contents and spits it out line-by-line
#     Maybe use "Begin{}"/"Process{}"/"End{}" blocks.
#      -> Figure out files to process in Begin
#       Either from file or from Get-ChildItem
#      -> Process the list of files Process
# TODO: Support symlinks:
#     At least file-size checking is broken as symlinks show up as 0 bytes
#     What else?
# TODO: Select preset with a flag like -slow or -slower
#     Needs to be mutually exclusive
#     Having ParameterSets for h264 and h265 complicates things. Can a parameter be in two sets at the same time?
#     Need to have mutually exclusive sets for both profiles and h264/h265
# FIXME: Recurse doesn't work. The output dir is determined at the start instead of in each directory
#     Maybe that doesn't make sense either... in any case, it doesn't work right now.
# TODO: Add support for pipelining


function Log-Message {
    Param
    (
        [Parameter(Mandatory, Position=0)]
        [string]$Message,

        [Parameter()]
        [string]$ToFile = "$Env:Home\Compress-Video.log",

        [Parameter()]
        [switch]$NoNewLine,

        [Parameter()]
        [switch]$NoTimestamp
    )

    if ($NoNewLine) {
        if ($NoTimestamp) {
            Add-Content -Path $ToFile -Value $Message -NoNewLine
            Write-Host $Message -NoNewLine
        } else {
            $msg = "{0} - {1}" -f (Get-Date -Format u), $Message
            Add-Content -Path $ToFile -Value $msg -NoNewLine
            Write-Host $msg -NoNewLine
        }
    } else {
        if ($NoTimestamp) {
            Add-Content -Path $ToFile -Value $Message
            Write-Host $Message
        } else {
            $msg = "{0} - {1}" -f (Get-Date -Format u), $Message
            Add-Content -Path $ToFile -Value $msg
            Write-Host $msg
        }
    }
}

Function Format-FileSize {
    Param (
        [Parameter(Mandatory)]
        [int64]$Size
    )
    If ($Size -gt 1TB) {
        [string]::Format("{0:0.00} TB", $Size / 1TB)
    }
    ElseIf ($Size -gt 1GB) {
        [string]::Format("{0:0.00} GB", $Size / 1GB)
    }
    ElseIf ($Size -gt 1MB) {
        [string]::Format("{0:0.00} MB", $Size / 1MB)
    }
    ElseIf ($Size -gt 1KB) {
        [string]::Format("{0:0.00} kB", $Size / 1KB)
    }
    ElseIf ($Size -gt 0) {
        [string]::Format("{0:0.00} B", $Size)
    }
    Else {""}
}

function Compress-Video {
    <#
    .SYNOPSIS
        Encode video(s) in $Target with FFMPEG to $Scale at CRF of $CRF with 96k AAC audio using either -h264 or -h265 (default)
    #>

    [CmdletBinding(DefaultParameterSetName="h265")]
    Param (
        # What to process. File/dir
        [Parameter(Position=0)]
        [ValidateScript({ Test-Path $_ }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Target = ".",
        # Where to dump the processed files. Will be a subdir next to the processed file
        [string]$OutputDirName = "encode-output",
        # The CRF quality value. Lower is better. 23 is the x264 default. 28 for x265
        [int64]$CRF,
        # Don't process files below this in gigabytes
        [double]$MinSize = 0.0,
        # Downscale video to maximum of this many vertical pixels, for example "1080"
        [int64]$Scale,
        # Recurse in to subdirs. Probably unwanted most of the time
        [switch]$Recurse = $false,
        # Mutually exclusive swithes to determine target encoding library
        [Parameter(ParameterSetName="h264")]
        [switch]$h264,
        [Parameter(ParameterSetName="h265")]
        [switch]$h265,
        # Preset to use
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo")]
        [string]$Preset = "slow"
    )
    Begin {
        # Set the correct library and default CRF per library
        if ($h264) {
            $lib = "libx264"
            if (!$CRF) {
                $CRF = 23
            }
        } elseif ($h265) {
            $lib = "libx265"
            if (!$CRF) {
                $CRF = 28
            }
        } else {
            # Default
            $lib = "libx265"
            if (!$CRF) {
                $CRF = 28
            }
        }

         Log-Message "Started job."
    }

    Process {
        [object]$Target = Get-Item $Target

        $Videos = @()
        # Check if target is a file (leaf) or dir (container)
        if (Test-Path $Target -PathType Leaf) {
            $Videos += Get-Item $Target
        } else {
            # Remember to add another repalce in $NewFilePath if adding more file extensions
            $Videos += Get-ChildItem $Target -Attributes !Directory -Recurse:$Recurse -Filter "*.mp4"
            $Videos += Get-ChildItem $Target -Attributes !Directory -Recurse:$Recurse -Filter "*.wmv"
            $Videos = $Videos | Sort-Object Length -Descending
        }

        $i = 0
        foreach($Video in $Videos) {
            $OutputDir = [IO.Path]::Combine($Video.DirectoryName, $OutputDirName)
            # Try creating the output directory and ignore errors
            New-Item -ItemType "Directory" -Path $OutputDir -Force > $null

            $NewFilePath = [IO.Path]::Combine($OutputDir, ($Video.Name -replace ".mp4", ".mkv" -replace ".wmv", ".mkv"))
            # Path with Powershell special chars escaped so Test-Path and Get-Item for example work.
            # The unescaped path somehow works just fine for FFMPEG though ¯\_(ツ)_/¯
            $NewFilePathEscaped = [WildcardPattern]::Escape($NewFilePath)

            # Doesn't work. ffmpeg breaks it maybe
            Write-Progress -Activity "Encoding" -Status "$i/$($Videos.Length) complete" -PercentComplete ($i / $Videos.Count * 100) -CurrentOperation $Video.Name;
            $i = $i + 1

            if (Test-Path $NewFilePathEscaped) {
                Log-Message "$NewFilePath already exists. Skipping... "
                continue
            }

            $SizeInGB = $Video.Length / 1GB
            if ($SizeInGB -gt $MinSize) {
                Log-Message "Re-encoding $Video... " -NoNewLine

                # ffmpeg -report "Dump full command line and log output to a file named program-YYYYMMDD-HHMMSS.log in the current directory"
                # For debugging the input args
                if ($Scale) {
                    ffmpeg -n -i "$Video" -vf "scale=-1:'min($Scale,ih)'" "-c:v" $lib -preset $Preset -crf $CRF "-c:a" aac "-b:a" 96k "$NewFilePath"
                } else {
                    ffmpeg -n -i "$Video" "-c:v" $lib -preset $Preset -crf $CRF "-c:a" aac "-b:a" 96k "$NewFilePath"
                }

                Start-Sleep -s 1

                $NewVideo = Get-Item $NewFilePathEscaped

                # Copy attributes over
                $NewVideo.CreationTime = $Video.CreationTime
                $NewVideo.LastWriteTime = $Video.LastWriteTime
                # $NewVideo.LastAccessTime = $Video.LastAccessTime
                # $NewVideo.Attributes = $Video.Attributes

                Log-Message "Done. $(Format-FileSize($Video.Length)) -> $(Format-FileSize($NewVideo.Length))." -NoTimestamp
            } else {
                Log-Message "$Video smaller than $(Format-FileSize($MinSize * 1GB)). Skipping..."
            }
            # break
        }
    }

    End {
        Log-Message "Done."
    }
}

Export-ModuleMember -Function Compress-Video
