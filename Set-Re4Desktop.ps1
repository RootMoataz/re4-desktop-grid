<#
.SYNOPSIS
  Sets the RE4 inventory wallpaper and snaps desktop icons into its grid cells.
.PARAMETER Preview
  Print the planned icon positions and change nothing.
.NOTES
  Targets the primary monitor. Grid coordinates are measured from the 1672x941
  source image and scaled to the primary monitor (assumes a 16:9 screen, wallpaper
  style Fill). Icons fill column by column (top to bottom), like Explorer's default.
  Icons beyond the 128 grid cells overflow into the "TMP" bar, then a block
  down the right edge, so everything stays on the primary monitor.
#>
param([switch]$Preview)

$ImgW = 1672.0; $ImgH = 941.0
$Cells = @(@(107.3,234.2),@(101.6,295.4),@(95.8,357.9),@(89.9,421.2),@(84.0,484.8),@(78.1,548.1),@(72.2,611.8),@(66.1,677.6),@(173.8,234.2),@(168.8,295.4),@(163.7,357.9),@(158.6,421.2),@(153.4,484.8),@(148.2,548.1),@(143.0,611.8),@(137.6,677.6),@(240.1,234.2),@(235.7,295.4),@(231.1,357.9),@(226.5,421.2),@(221.8,484.8),@(217.2,548.1),@(212.5,611.8),@(207.7,677.6),@(306.8,234.2),@(302.8,295.4),@(298.7,357.9),@(294.6,421.2),@(290.4,484.8),@(286.3,548.1),@(282.1,611.8),@(277.8,677.6),@(373.8,234.2),@(370.2,295.4),@(366.5,357.9),@(362.8,421.2),@(359.1,484.8),@(355.4,548.1),@(351.7,611.8),@(347.8,677.6),@(440.5,234.2),@(437.4,295.4),@(434.3,357.9),@(431.1,421.2),@(427.9,484.8),@(424.7,548.1),@(421.5,611.8),@(418.1,677.6),@(507.0,234.2),@(504.4,295.4),@(501.8,357.9),@(499.2,421.2),@(496.5,484.8),@(493.9,548.1),@(491.2,611.8),@(488.5,677.6),@(573.2,234.2),@(571.2,295.4),@(569.1,357.9),@(567.0,421.2),@(564.9,484.8),@(562.9,548.1),@(560.8,611.8),@(558.6,677.6),@(639.3,234.2),@(637.9,295.4),@(636.4,357.9),@(634.8,421.2),@(633.3,484.8),@(631.8,548.1),@(630.2,611.8),@(628.7,677.6),@(706.0,234.2),@(705.0,295.4),@(703.9,357.9),@(702.8,421.2),@(701.8,484.8),@(700.7,548.1),@(699.6,611.8),@(698.5,677.6),@(773.2,234.2),@(772.6,295.4),@(771.9,357.9),@(771.2,421.2),@(770.5,484.8),@(769.9,548.1),@(769.2,611.8),@(768.5,677.6),@(840.6,234.2),@(840.3,295.4),@(840.1,357.9),@(839.9,421.2),@(839.6,484.8),@(839.4,548.1),@(839.1,611.8),@(838.9,677.6),@(907.9,234.2),@(908.1,295.4),@(908.3,357.9),@(908.5,421.2),@(908.7,484.8),@(908.9,548.1),@(909.2,611.8),@(909.4,677.6),@(974.8,234.2),@(975.5,295.4),@(976.2,357.9),@(976.9,421.2),@(977.6,484.8),@(978.2,548.1),@(978.9,611.8),@(979.7,677.6),@(1041.6,234.2),@(1042.7,295.4),@(1043.9,357.9),@(1045.2,421.2),@(1046.4,484.8),@(1047.6,548.1),@(1048.8,611.8),@(1050.1,677.6),@(1107.9,234.2),@(1109.8,295.4),@(1111.8,357.9),@(1113.7,421.2),@(1115.7,484.8),@(1117.7,548.1),@(1119.7,611.8),@(1121.8,677.6))
$Strip = @(@(270.0,842.0),@(336.5,842.0),@(403.0,842.0),@(469.5,842.0),@(536.0,842.0),@(602.5,842.0),@(669.0,842.0),@(735.5,842.0),@(802.0,842.0),@(868.5,842.0),@(935.0,842.0),@(1001.5,842.0))

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int a, int b, string c, int d);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
}
'@
[void][Native]::SetProcessDPIAware()
$sw = [Native]::GetSystemMetrics(0); $sh = [Native]::GetSystemMetrics(1)   # primary monitor px
$sx = $sw / $ImgW; $sy = $sh / $ImgH

# --- locate the desktop icon list view (under Progman or a WorkerW) ---
$lv = [IntPtr]::Zero
$prog = [Native]::FindWindow('Progman', [NullString]::Value)
$view = [Native]::FindWindowEx($prog, [IntPtr]::Zero, 'SHELLDLL_DefView', [NullString]::Value)
if ($view -eq [IntPtr]::Zero) {
  $w = [IntPtr]::Zero
  do {
    $w = [Native]::FindWindowEx([IntPtr]::Zero, $w, 'WorkerW', [NullString]::Value)
    if ($w -ne [IntPtr]::Zero) { $view = [Native]::FindWindowEx($w, [IntPtr]::Zero, 'SHELLDLL_DefView', [NullString]::Value) }
  } while ($w -ne [IntPtr]::Zero -and $view -eq [IntPtr]::Zero)
}
if ($view -ne [IntPtr]::Zero) { $lv = [Native]::FindWindowEx($view, [IntPtr]::Zero, 'SysListView32', [NullString]::Value) }
if ($lv -eq [IntPtr]::Zero) { throw 'Could not find the desktop icon list view.' }

$LVM_GETITEMCOUNT = 0x1004; $LVM_GETITEMSPACING = 0x1033; $LVM_SETITEMPOSITION = 0x100F
$LVM_SETEXTENDEDLISTVIEWSTYLE = 0x1036; $LVS_EX_SNAPTOGRID = 0x80000; $LVS_AUTOARRANGE = 0x100; $GWL_STYLE = -16

$count = [int][Native]::SendMessage($lv, $LVM_GETITEMCOUNT, [IntPtr]::Zero, [IntPtr]::Zero)
$sp = [int64][Native]::SendMessage($lv, $LVM_GETITEMSPACING, [IntPtr]::Zero, [IntPtr]::Zero)
$cellW = [int]($sp -band 0xFFFF); $cellH = [int](($sp -shr 16) -band 0xFFFF)
# screen-space centers: grid cells, then the TMP bar, then a block down the right panel
$slots = @(); foreach ($c in ($Cells + $Strip)) { $slots += ,@(($c[0] * $sx), ($c[1] * $sy)) }
$extra = 0; $col = 0
while ($slots.Count -lt $count) {
  for ($row = 0; $row -lt 10 -and $slots.Count -lt $count; $row++) {
    $slots += ,@(($sw - 10 - $cellW * ($col + 0.5)), (330 + $cellH * ($row + 0.5))); $extra++
  }
  $col++
}
Write-Host "Screen ${sw}x${sh}, $count icons, icon cell ${cellW}x${cellH}; $($Cells.Count) grid + $($Strip.Count) TMP bar + $extra right-panel slots"

if (-not $Preview) {
  # wallpaper: Fill, copied-in image path
  $img = Join-Path $PSScriptRoot 'wallpaper.jpg'
  Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'
  Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
  [void][Native]::SystemParametersInfo(0x14, 0, $img, 3)

  # free placement: auto-arrange off, snap-to-grid off
  $st = [Native]::GetWindowLong($lv, $GWL_STYLE)
  [void][Native]::SetWindowLong($lv, $GWL_STYLE, ($st -band (-bnot $LVS_AUTOARRANGE)))
  [void][Native]::SendMessage($lv, $LVM_SETEXTENDEDLISTVIEWSTYLE, [IntPtr]$LVS_EX_SNAPTOGRID, [IntPtr]0)
}

for ($i = 0; $i -lt $count; $i++) {
  $x = [int]([Math]::Round($slots[$i][0] - $cellW / 2))
  $y = [int]([Math]::Round($slots[$i][1] - $cellH / 2))
  if ($Preview) { Write-Host ("icon {0,3} -> ({1},{2})" -f $i, $x, $y); continue }
  [void][Native]::SendMessage($lv, $LVM_SETITEMPOSITION, [IntPtr]$i, [IntPtr]((($y -band 0xFFFF) -shl 16) -bor ($x -band 0xFFFF)))
}
if (-not $Preview) { Write-Host 'Done.' }
