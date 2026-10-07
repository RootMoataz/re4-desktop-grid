# UI for arranging desktop icons into categories on the RE4 wallpaper grid.
# Run via Re4-IconArranger.cmd (needs STA). Layout is saved next to this script in layout.json.
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  Start-Process powershell.exe -ArgumentList '-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
  return
}
. (Join-Path $PSScriptRoot 'Re4Core.ps1')
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:LayoutFile = Join-Path $PSScriptRoot 'layout.json'
$script:Cats = New-Object System.Collections.ArrayList   # each: @{ Name; Icons (ArrayList); Columns (ArrayList of 0-based ints) }
$script:Names = [string[]]@()
$script:Palette = @('#4F8EF7','#E8A33D','#58B368','#C46BD6','#E5605A','#3DB8B8','#B5B14A','#8C7BE0','#E07BA8','#7BC8E0','#A8D060','#D98C5F')
$script:Drag = $null   # 'add' | 'remove' while painting columns in the preview
$script:Mon = 0          # display shown in the preview
$script:Monitors = @()
$script:FreeAllowed = [bool[]]@($true)   # per display: may unassigned icons use its free columns?
$script:ApplyOn = [bool[]]@($true)       # per display: does Apply move its icons?
$script:Busy = $false
$script:GX = 0; $script:GY = 0   # global nudge in px
$script:Applied = $false
$script:SortUn = $false   # unassigned icons placed A-Z (set by 'Sort icons A-Z')
$script:Note = ''   # one-off status message, shown in front of the summary until the next change

function New-Cat($name) { [pscustomobject]@{ Name = $name; Icons = (New-Object System.Collections.ArrayList); Columns = (New-Object System.Collections.ArrayList); OffX = 0; OffY = 0 } }
function Cat-Copy { $script:Cats | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Icons = @($_.Icons); Columns = @($_.Columns); OffX = $_.OffX; OffY = $_.OffY } } }
function Save-State {
  $script:Note = ''
  $o = [ordered]@{ wallpaper = [bool]$chkWall.Checked; free = @($script:FreeAllowed); applyOn = @($script:ApplyOn); nudge = [ordered]@{ x = $script:GX; y = $script:GY }; sortUnassigned = [bool]$script:SortUn; categories = @($script:Cats | ForEach-Object {
    [ordered]@{ name = $_.Name; icons = @($_.Icons); columns = @($_.Columns); offx = $_.OffX; offy = $_.OffY } }) }
  ConvertTo-Json -InputObject $o -Depth 6 | Set-Content -Path $script:LayoutFile -Encoding UTF8
}
function Load-State {
  if (-not (Test-Path $script:LayoutFile)) { return }
  try {
    $o = Get-Content $script:LayoutFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $chkWall.Checked = [bool]$o.wallpaper
    if ($o.sortUnassigned) { $script:SortUn = $true }
    if ($o.nudge) { $script:GX = [int]$o.nudge.x; $script:GY = [int]$o.nudge.y }
    if ($null -ne $o.free) { $script:FreeAllowed = [bool[]]@($o.free) }
    if ($null -ne $o.applyOn) { $script:ApplyOn = [bool[]]@($o.applyOn) }
    foreach ($c in @($o.categories)) {
      $cat = New-Cat ([string]$c.name); $cat.OffX = [int]$c.offx; $cat.OffY = [int]$c.offy
      foreach ($i in @($c.icons)) { [void]$cat.Icons.Add([string]$i) }
      foreach ($i in @($c.columns)) { [void]$cat.Columns.Add([int]$i) }
      [void]$script:Cats.Add($cat)
    }
  } catch { [System.Windows.Forms.MessageBox]::Show("Could not read layout.json: $_") | Out-Null }
}
function Get-Sel { if ($cmbCat.SelectedIndex -ge 0) { $script:Cats[$cmbCat.SelectedIndex] } }
function Get-CatColor($k) { [System.Drawing.ColorTranslator]::FromHtml($script:Palette[$k % $script:Palette.Count]) }

function Scan-Monitors {
  $script:Monitors = @(Get-Monitors)
  $fa = New-Object 'System.Collections.Generic.List[bool]'
  for ($i = 0; $i -lt $script:Monitors.Count; $i++) { $fa.Add($(if ($i -lt $script:FreeAllowed.Count) { $script:FreeAllowed[$i] } else { $script:Monitors[$i].Primary })) }
  $script:FreeAllowed = $fa.ToArray()
  $ap = New-Object 'System.Collections.Generic.List[bool]'
  for ($i = 0; $i -lt $script:Monitors.Count; $i++) { $ap.Add($(if ($i -lt $script:ApplyOn.Count) { $script:ApplyOn[$i] } else { $true })) }
  $script:ApplyOn = $ap.ToArray()
  if ($script:Mon -ge $script:Monitors.Count) { $script:Mon = 0 }
  $script:Busy = $true
  $cmbMon.Items.Clear(); foreach ($m in $script:Monitors) { [void]$cmbMon.Items.Add($m.Label) }
  $cmbMon.SelectedIndex = $script:Mon; $chkFree.Checked = $script:FreeAllowed[$script:Mon]; $chkApplyMon.Checked = $script:ApplyOn[$script:Mon]
  $script:Busy = $false
}
function Scan-Desktop {
  Scan-Monitors
  try { $script:Names = Get-DesktopIconNames } catch { [System.Windows.Forms.MessageBox]::Show("Scan failed: $_") | Out-Null; $script:Names = [string[]]@() }
}

function Refresh-All {
  $sel = $cmbCat.SelectedIndex
  $script:Busy = $true
  $cmbCat.Items.Clear(); foreach ($c in $script:Cats) { [void]$cmbCat.Items.Add($c.Name) }
  if ($script:Cats.Count -gt 0) { $cmbCat.SelectedIndex = [math]::Min([math]::Max($sel, 0), $script:Cats.Count - 1) }
  $script:Busy = $false
  $assigned = @{}; foreach ($c in $script:Cats) { foreach ($i in $c.Icons) { $assigned[$i] = $true } }
  $lstFree.BeginUpdate(); $lstFree.Items.Clear()
  foreach ($n in ($script:Names | Sort-Object -Unique)) { if (-not $assigned.ContainsKey($n)) { [void]$lstFree.Items.Add($n) } }
  $lstFree.EndUpdate()
  $lstCat.Items.Clear(); $c = Get-Sel
  if ($c) { $present = @{}; foreach ($n in $script:Names) { $present[$n] = $true }
    foreach ($i in $c.Icons) { [void]$lstCat.Items.Add($(if ($present.ContainsKey($i)) { $i } else { "$i  (not on desktop)" })) } }
  $grpFree.Text = "Unassigned icons ($($lstFree.Items.Count))"
  $grpCat.Text = if ($c) { "'$($c.Name)' icons ($($c.Icons.Count))" } else { 'Category icons' }
  foreach ($b in $btnAdd, $btnRem, $btnRename, $btnDel) { $b.Enabled = [bool]$c }
  Sync-Sliders
  $pnl.Invalidate()
}

# ---------- form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'RE4 Desktop Arranger'; $form.StartPosition = 'CenterScreen'; $form.ClientSize = New-Object System.Drawing.Size(1330, 814)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9); $form.MinimumSize = $form.Size

$grpFree = New-Object System.Windows.Forms.GroupBox; $grpFree.Location = '10,10'; $grpFree.Size = '250,764'
$lstFree = New-Object System.Windows.Forms.ListBox; $lstFree.SelectionMode = 'MultiExtended'; $lstFree.Dock = 'Fill'; $lstFree.IntegralHeight = $false
$btnScan = New-Object System.Windows.Forms.Button; $btnScan.Text = 'Rescan desktop'; $btnScan.Dock = 'Bottom'; $btnScan.Height = 30
$btnAuto = New-Object System.Windows.Forms.Button; $btnAuto.Text = 'Auto-categorize unassigned'; $btnAuto.Dock = 'Bottom'; $btnAuto.Height = 30
$btnSuggest = New-Object System.Windows.Forms.Button; $btnSuggest.Text = 'Suggest columns for new categories'; $btnSuggest.Dock = 'Bottom'; $btnSuggest.Height = 30
$grpFree.Controls.AddRange(@($lstFree, $btnSuggest, $btnAuto, $btnScan))

$btnAdd = New-Object System.Windows.Forms.Button; $btnAdd.Text = 'Add >>'; $btnAdd.Location = '266,250'; $btnAdd.Size = '70,34'
$btnRem = New-Object System.Windows.Forms.Button; $btnRem.Text = '<< Remove'; $btnRem.Location = '266,296'; $btnRem.Size = '70,34'

$cmbCat = New-Object System.Windows.Forms.ComboBox; $cmbCat.DropDownStyle = 'DropDownList'; $cmbCat.Location = '342,12'; $cmbCat.Size = '260,24'
$btnNew = New-Object System.Windows.Forms.Button; $btnNew.Text = 'New'; $btnNew.Location = '342,42'; $btnNew.Size = '82,28'
$btnRename = New-Object System.Windows.Forms.Button; $btnRename.Text = 'Rename'; $btnRename.Location = '430,42'; $btnRename.Size = '82,28'
$btnDel = New-Object System.Windows.Forms.Button; $btnDel.Text = 'Delete'; $btnDel.Location = '518,42'; $btnDel.Size = '84,28'
$grpCat = New-Object System.Windows.Forms.GroupBox; $grpCat.Location = '342,78'; $grpCat.Size = '260,696'
$lstCat = New-Object System.Windows.Forms.ListBox; $lstCat.SelectionMode = 'MultiExtended'; $lstCat.Dock = 'Fill'; $lstCat.IntegralHeight = $false
$grpCat.Controls.Add($lstCat)

$lblHelp = New-Object System.Windows.Forms.Label; $lblHelp.Location = '620,12'; $lblHelp.Size = '700,34'
$lblHelp.Text = "Pick a category and a display, then click/drag columns (or the TMP bar) below to give them to it.`r`nOne category per column. Icons fill row by row, left to right; the TMP bar fills left to right."
$pnl = New-Object System.Windows.Forms.Panel; $pnl.Location = '620,86'; $pnl.Size = '700,556'; $pnl.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
$pnl.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($pnl, $true)

$cmbMon = New-Object System.Windows.Forms.ComboBox; $cmbMon.DropDownStyle = 'DropDownList'; $cmbMon.Location = '620,52'; $cmbMon.Size = '280,24'
$chkFree = New-Object System.Windows.Forms.CheckBox; $chkFree.Text = 'Unassigned may use free columns'; $chkFree.Location = '1090,54'; $chkFree.AutoSize = $true
$chkApplyMon = New-Object System.Windows.Forms.CheckBox; $chkApplyMon.Text = 'Apply to this display'; $chkApplyMon.Checked = $true; $chkApplyMon.Location = '912,54'; $chkApplyMon.AutoSize = $true
function New-Lbl($t, $x, $y, $w) { $l = New-Object System.Windows.Forms.Label; $l.Text = $t; $l.Location = "$x,$y"; $l.Size = "$w,20"; $l }
function New-Trk($x, $y) { $t = New-Object System.Windows.Forms.TrackBar; $t.Minimum = -60; $t.Maximum = 60; $t.TickFrequency = 10; $t.LargeChange = 5; $t.Location = "$x,$y"; $t.Size = '330,40'; $t }
$lblNX = New-Lbl 'Horizontal' 620 656 74; $trkX = New-Trk 696 650; $valX = New-Lbl '0 px' 1030 656 60
$lblNY = New-Lbl 'Vertical' 620 692 74;   $trkY = New-Trk 696 686; $valY = New-Lbl '0 px' 1030 692 60
$chkOnly = New-Object System.Windows.Forms.CheckBox; $chkOnly.Text = 'Only the selected category'; $chkOnly.Location = '1100,654'; $chkOnly.AutoSize = $true
$chkLive = New-Object System.Windows.Forms.CheckBox; $chkLive.Text = 'Live on desktop (after Apply)'; $chkLive.Checked = $true; $chkLive.Location = '1100,680'; $chkLive.AutoSize = $true
$btnReset = New-Object System.Windows.Forms.Button; $btnReset.Text = 'Reset nudge'; $btnReset.Location = '1100,704'; $btnReset.Size = '110,26'
$tmrLive = New-Object System.Windows.Forms.Timer; $tmrLive.Interval = 150
$chkWall = New-Object System.Windows.Forms.CheckBox; $chkWall.Text = 'Also set the RE4 wallpaper'; $chkWall.Checked = $true; $chkWall.Location = '620,748'; $chkWall.AutoSize = $true
$btnSort = New-Object System.Windows.Forms.Button; $btnSort.Text = 'Sort icons A-Z'; $btnSort.Location = '890,740'; $btnSort.Size = '230,36'
$btnSort.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$btnApply = New-Object System.Windows.Forms.Button; $btnApply.Text = 'Apply to desktop'; $btnApply.Location = '1130,740'; $btnApply.Size = '190,36'
$btnApply.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$lblStatus = New-Object System.Windows.Forms.Label; $lblStatus.Location = '10,786'; $lblStatus.Size = '1300,24'; $lblStatus.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.AddRange(@($grpFree, $btnAdd, $btnRem, $cmbCat, $btnNew, $btnRename, $btnDel, $grpCat, $lblNX, $trkX, $valX, $lblNY, $trkY, $valY, $chkOnly, $chkLive, $btnReset, $btnSort, $lblHelp, $cmbMon, $chkApplyMon, $chkFree, $pnl, $chkWall, $btnApply, $lblStatus))


# ---------- preview / column picker ----------
$OX = 6; $OY = 26; $CW = 43; $CH = 48
$pnl.Add_Paint({
  param($s, $e)
  $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
  $cats = @(Cat-Copy)
  $mc = [math]::Max(1, $script:Monitors.Count); $mon = $script:Mon
  $layout = @(New-Layout -Names $script:Names -Categories $cats -MonitorCount $mc -FreeAllowed $script:FreeAllowed -SortUnassigned $script:SortUn)
  $owner = @{}; for ($k = 0; $k -lt $cats.Count; $k++) { foreach ($c in $cats[$k].Columns) { if (-not $owner.ContainsKey([int]$c)) { $owner[[int]$c] = $k } } }
  $cell = @{}; $tmpCell = @{}
  foreach ($p in $layout) { if ($p.Mon -ne $mon) { continue }; if ($p.Kind -eq 'grid') { $cell["$($p.Col),$($p.Row)"] = $p } elseif ($p.Kind -eq 'tmp') { $tmpCell[[int]$p.Col] = $p } }
  $small = New-Object System.Drawing.Font('Segoe UI', 6.5); $hdr = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
  $selK = $cmbCat.SelectedIndex
  $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.Trimming = 'Character'
  for ($c = 0; $c -lt 16; $c++) {
    $x = $OX + $c * $CW
    $key = $mon * 100 + $c; $has = $owner.ContainsKey($key)
    $hc = if ($has) { Get-CatColor $owner[$key] } else { [System.Drawing.Color]::FromArgb(70,70,70) }
    $b = New-Object System.Drawing.SolidBrush $hc
    $g.FillRectangle($b, $x + 1, 2, $CW - 2, 20); $b.Dispose()
    $g.DrawString([string]($c + 1), $hdr, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new($x, 4, $CW, 16), $sf)
    for ($r = 0; $r -lt 8; $r++) {
      $rect = [System.Drawing.Rectangle]::new($x + 1, $OY + $r * $CH + 1, $CW - 2, $CH - 2)
      $base = if ($has) { [System.Drawing.Color]::FromArgb(60, $hc) } else { [System.Drawing.Color]::FromArgb(38,38,38) }
      $b = New-Object System.Drawing.SolidBrush $base; $g.FillRectangle($b, $rect); $b.Dispose()
      $p = $cell["$c,$r"]
      if ($p) {
        $fc = if ($p.Cat -ge 0) { Get-CatColor $p.Cat } else { [System.Drawing.Color]::Gray }
        $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, $fc)); $g.FillRectangle($b, [System.Drawing.Rectangle]::new($rect.X + 12, $rect.Y + 4, 18, 18)); $b.Dispose()
        $g.DrawString($p.Name, $small, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new($rect.X, $rect.Y + 24, $rect.Width, 24), $sf)
      }
    }
  }
  # TMP bar of the shown display (12 slots), claimable like a column
  $ty = $OY + 8 * $CH + 4; $tw = 16 * $CW; $tkey = $mon * 100 + 16; $thas = $owner.ContainsKey($tkey)
  $tc = if ($thas) { Get-CatColor $owner[$tkey] } else { [System.Drawing.Color]::FromArgb(70,70,70) }
  $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, $tc)); $g.FillRectangle($b, $OX + 1, $ty, $tw - 2, 30); $b.Dispose()
  $b = New-Object System.Drawing.SolidBrush $tc; $g.FillRectangle($b, $OX + 1, $ty, 36, 30); $b.Dispose()
  $g.DrawString('TMP', $hdr, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new($OX + 1, $ty + 8, 36, 16), $sf)
  $sw = ($tw - 42) / 12
  for ($t = 0; $t -lt 12; $t++) {
    $sx = $OX + 40 + $t * $sw
    $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40,40,40)); $g.FillRectangle($b, [System.Drawing.RectangleF]::new($sx, $ty + 1, $sw - 2, 28)); $b.Dispose()
    $q = $tmpCell[$t]
    if ($q) {
      $fc = if ($q.Cat -ge 0) { Get-CatColor $q.Cat } else { [System.Drawing.Color]::Gray }
      $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, $fc)); $g.FillRectangle($b, [System.Drawing.RectangleF]::new($sx + 2, $ty + 3, 8, 8)); $b.Dispose()
      $g.DrawString($q.Name, $small, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new($sx, $ty + 12, $sw - 2, 16), $sf)
    }
  }
  if ($selK -ge 0) {
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2
    foreach ($key in $script:Cats[$selK].Columns) { if ([math]::Floor($key / 100) -ne $mon) { continue }; $c = $key % 100; if ($c -eq 16) { $g.DrawRectangle($pen, $OX, $ty - 1, $tw, 32) } else { $g.DrawRectangle($pen, $OX + $c * $CW + 1, 1, $CW - 2, $OY + 8 * $CH - 1) } }
    $pen.Dispose()
  }
  # legend
  $ly = $ty + 30 + 8
  $free = 0; for ($m = 0; $m -lt $mc; $m++) { if ($script:FreeAllowed[$m]) { for ($c = 0; $c -lt 16; $c++) { if (-not $owner.ContainsKey($m * 100 + $c)) { $free++ } } } }
  for ($k = 0; $k -lt $cats.Count; $k++) {
    $kc = @($cats[$k].Columns | Where-Object { [math]::Floor($_ / 100) -lt $mc }); $ncol = @($kc | Where-Object { ($_ % 100) -lt 16 }).Count; $ntmp = @($kc | Where-Object { ($_ % 100) -eq 16 }).Count; $cap = $ncol * 8 + $ntmp * 12; $n = @($layout | Where-Object { $_.Cat -eq $k }).Count
    $over = [math]::Max(0, $n - $cap)
    $txt = "$($cats[$k].Name): $n icons, $ncol col" + $(if ($ntmp) { " + $ntmp TMP row" } else { "" }) + " = $cap slots" + $(if ($over) { "  - $over overflow" } else { '' })
    $b = New-Object System.Drawing.SolidBrush (Get-CatColor $k); $g.FillRectangle($b, 6 + 340 * ($k % 2), $ly + 16 * [math]::Floor($k / 2) + 3, 10, 10); $b.Dispose()
    $tb = if ($over) { [System.Drawing.Brushes]::Tomato } else { [System.Drawing.Brushes]::Gainsboro }
    $g.DrawString($txt, $small, $tb, 20 + 340 * ($k % 2), $ly + 16 * [math]::Floor($k / 2) + 2)
  }
  $un = @($layout | Where-Object { $_.Cat -eq -1 }).Count; $tmp = @($layout | Where-Object { $_.Kind -eq 'tmp' }).Count; $rt = @($layout | Where-Object { $_.Kind -eq 'right' }).Count
  $lblStatus.Text = $(if ($script:Note) { "$($script:Note)   ||   " } else { "" }) + "$($script:Names.Count) icons on desktop | $un unassigned -> $free free columns (on displays that allow it) | $tmp icons in TMP rows, $rt down the right edge"
})
# 0-15 = grid column, 16 = the TMP bar, -1 = nothing
function Column-At($x, $y) {
  $ty = $OY + 8 * $CH + 4
  if ($x -lt $OX -or $x -gt $OX + 16 * $CW) { return -1 }
  if ($y -ge $ty -and $y -le $ty + 30) { return 16 }
  if ($y -ge $ty) { return -1 }
  $c = [math]::Floor(($x - $OX) / $CW); if ($c -ge 0 -and $c -lt 16) { [int]$c } else { -1 }
}
function Paint-Column($col) {
  $sel = Get-Sel; if (-not $sel -or $col -lt 0) { return }
  $c = $script:Mon * 100 + $col
  $other = $false; foreach ($k in 0..($script:Cats.Count - 1)) { if ($script:Cats[$k] -ne $sel -and $script:Cats[$k].Columns.Contains($c)) { $other = $script:Cats[$k].Name } }
  if ($other) { $script:Note = "$(if ($col -eq 16) { 'The TMP row' } else { "Column $($col + 1)" }) on this display already belongs to '$other'."; $pnl.Invalidate(); return }
  if ($script:Drag -eq 'add' -and -not $sel.Columns.Contains($c)) { [void]$sel.Columns.Add($c) }
  if ($script:Drag -eq 'remove' -and $sel.Columns.Contains($c)) { $sel.Columns.Remove($c) }
  $pnl.Invalidate()
}
$pnl.Add_MouseDown({ param($s, $e)
  $sel = Get-Sel; if (-not $sel) { $lblStatus.Text = 'Create a category first (New).'; return }
  $c = Column-At $e.X $e.Y; if ($c -lt 0) { return }
  $script:Drag = if ($sel.Columns.Contains($script:Mon * 100 + $c)) { 'remove' } else { 'add' }; Paint-Column $c })
$pnl.Add_MouseMove({ param($s, $e) if ($script:Drag) { Paint-Column (Column-At $e.X $e.Y) } })
$pnl.Add_MouseUp({ if ($script:Drag) { $script:Drag = $null; Save-State; Refresh-All } })

# ---------- actions ----------
$btnScan.Add_Click({ Scan-Desktop; Refresh-All })
# --- sort: each category's icons A-Z (that order is the placement order) and unassigned icons A-Z ---
$btnSort.Add_Click({
  foreach ($c in $script:Cats) {
    $sorted = @($c.Icons | Sort-Object { $_.ToLower() })
    $c.Icons.Clear(); foreach ($i in $sorted) { [void]$c.Icons.Add($i) }
  }
  $script:SortUn = $true
  Save-State; Refresh-All
  $script:Note = "Sorted A-Z: $($script:Cats.Count) categories + unassigned icons. Press Apply to put them on the desktop."; $pnl.Invalidate()
})
# --- auto-categorize: rules live in categories.rules.json; only touches icons that are still unassigned ---
$btnAuto.Add_Click({
  try {
    $rules = Get-CategoryRules (Join-Path $PSScriptRoot 'categories.rules.json')
    $info = Get-DesktopItemInfo
  } catch { [System.Windows.Forms.MessageBox]::Show("Auto-categorize failed: $_") | Out-Null; return }
  $assigned = @{}; foreach ($c in $script:Cats) { foreach ($i in $c.Icons) { $assigned[$i] = $true } }
  $sorted = 0; $left = 0; $made = @{}
  foreach ($n in ($script:Names | Sort-Object -Unique)) {
    if ($assigned.ContainsKey($n)) { continue }
    $catName = Get-AutoCategory -Name $n -Info $info[$n] -Rules $rules
    if (-not $catName) { $left++; continue }
    $cat = $script:Cats | Where-Object { $_.Name -eq $catName } | Select-Object -First 1
    if (-not $cat) { $cat = New-Cat $catName; [void]$script:Cats.Add($cat) }
    [void]$cat.Icons.Add($n); $sorted++; $made[$catName] = $true
  }
  Save-State; Refresh-All
  $script:Note = "Auto-categorize: sorted $sorted icons into $($made.Count) categories, $left left unassigned. Edit categories.rules.json to tune the rules."; $pnl.Invalidate()
})
# --- suggest columns: biggest categories first (8 icons per column), starting on the shown display;
# a category stays on one display when it fits, otherwise it is split across displays ---
$btnSuggest.Add_Click({
  $owned = @{}; foreach ($c in $script:Cats) { foreach ($k in $c.Columns) { $owned[[int]$k] = $true } }
  $present = @{}; foreach ($n in $script:Names) { $present[$n] = $true }
  $order = @($script:Mon) + @(0..([math]::Max(0, $script:Monitors.Count - 1)) | Where-Object { $_ -ne $script:Mon })
  $freeBy = @{}
  foreach ($m in $order) { $freeBy[$m] = New-Object System.Collections.ArrayList; for ($c = 0; $c -lt 16; $c++) { if (-not $owned.ContainsKey($m * 100 + $c)) { [void]$freeBy[$m].Add($c) } } }
  $todo = @($script:Cats | Where-Object { $_.Columns.Count -eq 0 } | ForEach-Object { [pscustomobject]@{ Cat = $_; N = @($_.Icons | Where-Object { $present.ContainsKey($_) }).Count } } | Where-Object { $_.N -gt 0 } | Sort-Object N -Descending)
  $done = 0; $split = 0; $short = @()
  foreach ($t in $todo) {
    $need = [int][math]::Ceiling($t.N / 8)
    $dest = $order | Where-Object { $freeBy[$_].Count -ge $need } | Select-Object -First 1
    if ($null -ne $dest) { $plan = @(, @($dest, $need)) }
    else {   # no single display fits: split across displays if the total is enough
      $left = $need; $plan = @()
      foreach ($m in $order) { $take = [math]::Min($left, $freeBy[$m].Count); if ($take -gt 0) { $plan += , @($m, $take); $left -= $take } }
      if ($left -gt 0) { $short += $t.Cat.Name; continue }
      $split++
    }
    foreach ($pl in $plan) { for ($i = 0; $i -lt $pl[1]; $i++) { [void]$t.Cat.Columns.Add($pl[0] * 100 + $freeBy[$pl[0]][0]); $freeBy[$pl[0]].RemoveAt(0) } }
    $done++
  }
  Save-State; Refresh-All
  $script:Note = "Suggest columns: placed $done categories" + $(if ($split) { " ($split split across displays)" } else { '' }) + '.' + $(if ($short.Count) { " No room left for: $($short -join ', ')." } else { '' }); $pnl.Invalidate()
})
# --- nudge sliders: edit the selected category's offset, or the global one ---
function Nudge-Target { if ($chkOnly.Checked -and (Get-Sel)) { Get-Sel } else { $null } }
function Sync-Sliders {
  $t = Nudge-Target; $script:Busy = $true
  $trkX.Value = [math]::Max(-60, [math]::Min(60, $(if ($t) { $t.OffX } else { $script:GX })))
  $trkY.Value = [math]::Max(-60, [math]::Min(60, $(if ($t) { $t.OffY } else { $script:GY })))
  $script:Busy = $false; $valX.Text = "$($trkX.Value) px"; $valY.Text = "$($trkY.Value) px"
}
$onNudge = { if ($script:Busy) { return }
  $t = Nudge-Target
  if ($t) { $t.OffX = $trkX.Value; $t.OffY = $trkY.Value } else { $script:GX = $trkX.Value; $script:GY = $trkY.Value }
  $valX.Text = "$($trkX.Value) px"; $valY.Text = "$($trkY.Value) px"; $pnl.Invalidate()
  if ($chkLive.Checked -and $script:Applied) { $tmrLive.Stop(); $tmrLive.Start() }
  elseif ($chkLive.Checked) { $script:Note = 'Nudge shows on the desktop after you press Apply to desktop once.' } }
$trkX.Add_ValueChanged($onNudge); $trkY.Add_ValueChanged($onNudge)
$trkX.Add_MouseUp({ Save-State }); $trkY.Add_MouseUp({ Save-State })
$chkOnly.Add_CheckedChanged({ Sync-Sliders })
$btnReset.Add_Click({ $t = Nudge-Target; if ($t) { $t.OffX = 0; $t.OffY = 0 } else { $script:GX = 0; $script:GY = 0 }; Sync-Sliders; Save-State; $pnl.Invalidate(); $tmrLive.Stop(); $tmrLive.Start() })
$tmrLive.Add_Tick({ $tmrLive.Stop()
  if (-not ($chkLive.Checked -and $script:Applied)) { return }
  try { [void](Invoke-DesktopArrange -Categories (Cat-Copy) -FreeAllowed $script:FreeAllowed -ApplyOn $script:ApplyOn -GlobalX $script:GX -GlobalY $script:GY -SortUnassigned $script:SortUn) } catch { $script:Note = "Live update failed: $_"; $pnl.Invalidate() } })
$cmbMon.Add_SelectedIndexChanged({ if ($script:Busy -or $cmbMon.SelectedIndex -lt 0) { return }
  $script:Mon = $cmbMon.SelectedIndex; $script:Busy = $true; $chkFree.Checked = $script:FreeAllowed[$script:Mon]; $chkApplyMon.Checked = $script:ApplyOn[$script:Mon]; $script:Busy = $false; $pnl.Invalidate() })
$chkApplyMon.Add_CheckedChanged({ if ($script:Busy) { return }
  $script:ApplyOn[$script:Mon] = [bool]$chkApplyMon.Checked; Save-State; $pnl.Invalidate() })
$chkFree.Add_CheckedChanged({ if ($script:Busy) { return }
  $script:FreeAllowed[$script:Mon] = [bool]$chkFree.Checked; Save-State; $pnl.Invalidate() })
$btnNew.Add_Click({
  $n = [Microsoft.VisualBasic.Interaction]::InputBox('Category name:', 'New category', '')
  if ([string]::IsNullOrWhiteSpace($n)) { return }; $n = $n.Trim()
  if (@($script:Cats | Where-Object { $_.Name -eq $n }).Count) { [System.Windows.Forms.MessageBox]::Show('That category already exists.') | Out-Null; return }
  [void]$script:Cats.Add((New-Cat $n))
  $cmbCat.Items.Add($n) | Out-Null; $cmbCat.SelectedIndex = $script:Cats.Count - 1; Save-State; Refresh-All })
$btnRename.Add_Click({
  $c = Get-Sel; if (-not $c) { return }
  $n = [Microsoft.VisualBasic.Interaction]::InputBox('New name:', 'Rename category', $c.Name)
  if ([string]::IsNullOrWhiteSpace($n) -or @($script:Cats | Where-Object { $_.Name -eq $n.Trim() -and $_ -ne $c }).Count) { return }
  $c.Name = $n.Trim(); Save-State; Refresh-All })
$btnDel.Add_Click({
  $c = Get-Sel; if (-not $c) { return }
  if ([System.Windows.Forms.MessageBox]::Show("Delete '$($c.Name)'? Its icons become unassigned and its columns are freed.", 'Delete', 'YesNo') -ne 'Yes') { return }
  $script:Cats.Remove($c); Save-State; Refresh-All })
$cmbCat.Add_SelectedIndexChanged({ if (-not $script:Busy) { Refresh-All } })
$moveIn = { $c = Get-Sel; if (-not $c) { return }
  foreach ($n in @($lstFree.SelectedItems)) { if (-not $c.Icons.Contains($n)) { [void]$c.Icons.Add($n) } }
  Save-State; Refresh-All }
$moveOut = { $c = Get-Sel; if (-not $c) { return }
  foreach ($n in @($lstCat.SelectedItems)) { $c.Icons.Remove(($n -replace '  \(not on desktop\)$', '')) }
  Save-State; Refresh-All }
$btnAdd.Add_Click($moveIn); $lstFree.Add_DoubleClick($moveIn)
$btnRem.Add_Click($moveOut); $lstCat.Add_DoubleClick($moveOut)
$btnApply.Add_Click({
  Save-State
  $cats = @(Cat-Copy)
  try {
    $n = Invoke-DesktopArrange -Categories $cats -FreeAllowed $script:FreeAllowed -ApplyOn $script:ApplyOn -GlobalX $script:GX -GlobalY $script:GY -SortUnassigned $script:SortUn -Wallpaper:([bool]$chkWall.Checked) -WallpaperPath (Join-Path $PSScriptRoot 'wallpaper.jpg')
    $script:Applied = $true; Scan-Desktop; Refresh-All; $script:Note = "Applied: arranged $n icons."; $pnl.Invalidate()
  } catch { [System.Windows.Forms.MessageBox]::Show("Apply failed: $_") | Out-Null }
})

Load-State; Scan-Desktop; Refresh-All
[void]$form.ShowDialog()
