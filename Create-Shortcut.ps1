# Creates the "RE4 Desktop Arranger" shortcut (with the RE4 icon) pointing at this folder's launcher.
# Run it once after downloading; the shortcut needs absolute paths, so it can't be shipped pre-made.
param([string]$Folder = [Environment]::GetFolderPath('Desktop'))
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $Folder 'RE4 Desktop Arranger.lnk'))
$lnk.TargetPath = Join-Path $PSScriptRoot 'Re4-IconArranger.cmd'
$lnk.WorkingDirectory = $PSScriptRoot
$lnk.IconLocation = (Join-Path $PSScriptRoot 'Re4-IconArranger.ico') + ',0'
$lnk.WindowStyle = 7   # minimized: no console flash
$lnk.Save()
Write-Host "Created: $($lnk.FullName)"
