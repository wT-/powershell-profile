# Prints a fancy color chart using the available shell color values
# From https://stackoverflow.com/a/41954792

function Print-Shell-Colors {
    $colors = [enum]::GetValues([System.ConsoleColor])

    Foreach ($bgcolor in $colors){
        Foreach ($fgcolor in $colors) { Write-Host "$fgcolor|" -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine }
        Write-Host " on $bgcolor"
    }
}
