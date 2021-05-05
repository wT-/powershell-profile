# TODO: Support symlinks:
#     At least file-size checking is broken as symlinks show up as 0 bytes
#     What else?
# TODO: Select preset with a flag like -slow or -slower
#     Needs to be mutually exclusive
#     Having ParameterSets for h264 and h265 complicates things. Can a parameter be in two sets at the same time?
#     Need to have mutually exclusive sets for both profiles and h264/h265
# TODO: Handle ctrl+c during encoding messing up the log a bit by leaving no newline in it
#     Wrap everything in a try/finally block:
#      - Finally block gets called always, even if ctrl+c:
#        -> Set a $Done var in try if we reached the end without issues.
#        -> Check for $Done in finally and:
#           - Make sure there's a newline printed so logs don't get messed up
#           - What else?
#      - Apparently you can't output anything in the finally block?

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
        Encode video(s in) $Target with FFMPEG to $Scale at CRF of $CRF with 96k AAC audio using either -x264 or -x265 (default) at $Preset encoding preset
    #>

    [CmdletBinding(DefaultParameterSetName="h265")]
    Param (
        # What to process. Video file or directory with video files
        [Parameter(Position=0, ValueFromPipeline)]
        [ValidateScript({ Test-Path ([WildcardPattern]::Escape($_.Trim(" `t`""))) }, ErrorMessage = "File/folder '{0}' doesn't exist.")]
        [string]$Target = ".",
        # Where to dump the processed files. Will be a subdir next to the processed file
        [string]$OutputDirName = "encode-output",
        # The CRF quality value. Lower is better. 23 is the x264 default. 28 for x265
        [int64]$CRF,
        # Don't process files below this in gigabytes
        [double]$MinSize = 0.0,
        # Downscale video to maximum of this many vertical pixels, for example "1080"
        [int64]$Scale,
        # Whether to recurse in to subdirs
        [switch]$Recurse = $false,
        # Mutually exclusive switches to pick the encoder
        [Parameter(ParameterSetName="x264")]
        [switch]$x264,
        [Parameter(ParameterSetName="x265")]
        [switch]$x265,
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

        $ValidExtensions = @(".mp4", ".avi", ".wmv", ".flv")

        $Videos = @()

        if ($Scale) {
            Log-Message "Started job using ${lib} @ CRF ${CRF} (Re-scaling to ${Scale}p)."
        } else {
            Log-Message "Started job using ${lib} @ CRF ${CRF}."
        }
    }

    Process {
        # Build the list of videos to process.

        # Example problematic path that requires escaping: "F:\Dir1\File1 [TextInsideBrackets] MoreText.ext"
        $Target = [WildcardPattern]::Escape($Target.Trim(" `t`""))

        # This seems to work correctly for single files too
        $AllFiles = Get-ChildItem $Target -Attributes !Directory -Recurse:$Recurse
        # Filter by extension, and make sure to not process any files inside $OutputDirName
        $Videos += $AllFiles.Where{ $ValidExtensions.Contains($_.Extension) }.Where{ -Not $_.FullName.Contains($OutputDirName) }
    }

    End {
        # Actually process the videos

        $Videos = $Videos | Sort-Object Length -Descending

        foreach($Video in $Videos) {
            $OutputDir = [IO.Path]::Combine($Video.DirectoryName, $OutputDirName)
            # Try creating the output directory and ignore errors
            New-Item -ItemType "Directory" -Path $OutputDir -Force > $null

            $NewFilePath = [IO.Path]::Combine($OutputDir, "$($Video.BaseName).mkv")
            # Path with Powershell special chars escaped so Test-Path and Get-Item for example work.
            # The unescaped path somehow works just fine for FFMPEG though ¯\_(ツ)_/¯
            $NewFilePathEscaped = [WildcardPattern]::Escape($NewFilePath)

            if (Test-Path $NewFilePathEscaped) {
                Log-Message "Already exists: ${NewFilePath}. Skipping... "
                continue
            }

            $SizeInGB = $Video.Length / 1GB
            if ($SizeInGB -gt $MinSize) {
                Log-Message "Re-encoding ${Video}... " -NoNewLine

                # ffmpeg -report "Dump full command line and log output to a file named program-YYYYMMDD-HHMMSS.log in the current directory"
                # For debugging the input args
                if ($Scale) {
                    ffmpeg -n -i "${Video}" -vf "scale=-1:'min(${Scale},ih)':flags=lanczos" "-c:v" $lib -preset $Preset -crf $CRF "-c:a" aac "-b:a" 96k "${NewFilePath}"
                } else {
                    ffmpeg -n -i "${Video}" "-c:v" $lib -preset $Preset -crf $CRF "-c:a" aac "-b:a" 96k "${NewFilePath}"
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
                Log-Message "Skipping ${Video}: smaller than $(Format-FileSize($MinSize * 1GB))."
            }
        }

        Log-Message "Done."
    }
}

Export-ModuleMember -Function Compress-Video
