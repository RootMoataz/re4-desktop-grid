# Shared logic: desktop icon scan, grid layout, applying positions. Dot-sourced by Re4-IconArranger.ps1.
# Grid coordinates are measured from the 1672x941 wallpaper (16 columns x 8 rows), column-major.
$script:ImgW = 1672.0; $script:ImgH = 941.0
$script:GridCols = 16; $script:GridRows = 8
$script:Cells = @(@(107.3,234.2),@(101.6,295.4),@(95.8,357.9),@(89.9,421.2),@(84.0,484.8),@(78.1,548.1),@(72.2,611.8),@(66.1,677.6),@(173.8,234.2),@(168.8,295.4),@(163.7,357.9),@(158.6,421.2),@(153.4,484.8),@(148.2,548.1),@(143.0,611.8),@(137.6,677.6),@(240.1,234.2),@(235.7,295.4),@(231.1,357.9),@(226.5,421.2),@(221.8,484.8),@(217.2,548.1),@(212.5,611.8),@(207.7,677.6),@(306.8,234.2),@(302.8,295.4),@(298.7,357.9),@(294.6,421.2),@(290.4,484.8),@(286.3,548.1),@(282.1,611.8),@(277.8,677.6),@(373.8,234.2),@(370.2,295.4),@(366.5,357.9),@(362.8,421.2),@(359.1,484.8),@(355.4,548.1),@(351.7,611.8),@(347.8,677.6),@(440.5,234.2),@(437.4,295.4),@(434.3,357.9),@(431.1,421.2),@(427.9,484.8),@(424.7,548.1),@(421.5,611.8),@(418.1,677.6),@(507.0,234.2),@(504.4,295.4),@(501.8,357.9),@(499.2,421.2),@(496.5,484.8),@(493.9,548.1),@(491.2,611.8),@(488.5,677.6),@(573.2,234.2),@(571.2,295.4),@(569.1,357.9),@(567.0,421.2),@(564.9,484.8),@(562.9,548.1),@(560.8,611.8),@(558.6,677.6),@(639.3,234.2),@(637.9,295.4),@(636.4,357.9),@(634.8,421.2),@(633.3,484.8),@(631.8,548.1),@(630.2,611.8),@(628.7,677.6),@(706.0,234.2),@(705.0,295.4),@(703.9,357.9),@(702.8,421.2),@(701.8,484.8),@(700.7,548.1),@(699.6,611.8),@(698.5,677.6),@(773.2,234.2),@(772.6,295.4),@(771.9,357.9),@(771.2,421.2),@(770.5,484.8),@(769.9,548.1),@(769.2,611.8),@(768.5,677.6),@(840.6,234.2),@(840.3,295.4),@(840.1,357.9),@(839.9,421.2),@(839.6,484.8),@(839.4,548.1),@(839.1,611.8),@(838.9,677.6),@(907.9,234.2),@(908.1,295.4),@(908.3,357.9),@(908.5,421.2),@(908.7,484.8),@(908.9,548.1),@(909.2,611.8),@(909.4,677.6),@(974.8,234.2),@(975.5,295.4),@(976.2,357.9),@(976.9,421.2),@(977.6,484.8),@(978.2,548.1),@(978.9,611.8),@(979.7,677.6),@(1041.6,234.2),@(1042.7,295.4),@(1043.9,357.9),@(1045.2,421.2),@(1046.4,484.8),@(1047.6,548.1),@(1048.8,611.8),@(1050.1,677.6),@(1107.9,234.2),@(1109.8,295.4),@(1111.8,357.9),@(1113.7,421.2),@(1115.7,484.8),@(1117.7,548.1),@(1119.7,611.8),@(1121.8,677.6))
$script:Strip = @(@(270.0,842.0),@(336.5,842.0),@(403.0,842.0),@(469.5,842.0),@(536.0,842.0),@(602.5,842.0),@(669.0,842.0),@(735.5,842.0),@(802.0,842.0),@(868.5,842.0),@(935.0,842.0),@(1001.5,842.0))   # 12 slots inside the "TMP" bar

if (-not ('Re4Native' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class Re4Native {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string t);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int a, int b, string c, int d);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
}
'@
}
# Per-monitor aware (v2) so every display's bounds are physical pixels, matching the desktop list view's coordinates even when
# displays use different Windows scaling. Falls back to system-aware on builds without it.
$perMon = $false
try { $perMon = [Re4Native]::SetProcessDpiAwarenessContext([IntPtr]-4) } catch { }
if (-not $perMon) { [void][Re4Native]::SetProcessDPIAware() }

if (-not ('Re4Shell' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class Re4Shell {
  [StructLayout(LayoutKind.Explicit, Size=272)] struct STRRET { [FieldOffset(0)] public uint uType; [FieldOffset(8)] public IntPtr pOleStr; }
  [ComImport, Guid("85CB6900-4D95-11CF-960C-0080C7F4EE85"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
  interface IShellWindows {
    int get_Count();
    [return: MarshalAs(UnmanagedType.IDispatch)] object Item(object index);
    [return: MarshalAs(UnmanagedType.IUnknown)] object _NewEnum();
    int Register([MarshalAs(UnmanagedType.IDispatch)] object d, int hwnd, int type);
    int RegisterPending(int tid, ref object loc, ref object root, int type);
    void Revoke(int cookie);
    void OnNavigate(int cookie, ref object loc);
    void OnActivated(int cookie, [MarshalAs(UnmanagedType.VariantBool)] bool active);
    [return: MarshalAs(UnmanagedType.IDispatch)] object FindWindowSW(ref object loc, ref object root, int swClass, out int hwnd, int options);
  }
  [ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IServiceProv { void QueryService(ref Guid svc, ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv); }
  [ComImport, Guid("000214E2-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IShellBrowser {
    void GetWindow(out IntPtr h); void ContextSensitiveHelp(bool b);
    void InsertMenusSB(IntPtr a, IntPtr b); void SetMenuSB(IntPtr a, IntPtr b, IntPtr c); void RemoveMenusSB(IntPtr a);
    void SetStatusTextSB(IntPtr a); void EnableModelessSB(bool b); void TranslateAcceleratorSB(IntPtr a, ushort b);
    void BrowseObject(IntPtr a, uint b); void GetViewStateStream(uint a, out IntPtr b); void GetControlWindow(uint a, out IntPtr b);
    void SendControlMsg(uint a, uint b, uint c, IntPtr d, out IntPtr e);
    void QueryActiveShellView([MarshalAs(UnmanagedType.IUnknown)] out object v);
  }
  [ComImport, Guid("CDE725B0-CCC9-4519-917E-325D72FAB4CE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IFolderView {
    void GetCurrentViewMode(out uint m); void SetCurrentViewMode(uint m);
    void GetFolder(ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv);
    void Item(int i, out IntPtr pidl); void ItemCount(uint f, out int c);
  }
  [ComImport, Guid("000214E6-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IShellFolder {
    void ParseDisplayName(IntPtr h, IntPtr pbc, [MarshalAs(UnmanagedType.LPWStr)] string n, out uint e, out IntPtr pidl, ref uint a);
    void EnumObjects(IntPtr h, int f, out IntPtr e);
    void BindToObject(IntPtr pidl, IntPtr pbc, ref Guid riid, out IntPtr ppv);
    void BindToStorage(IntPtr pidl, IntPtr pbc, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int CompareIDs(IntPtr l, IntPtr a, IntPtr b);
    void CreateViewObject(IntPtr h, ref Guid riid, out IntPtr ppv);
    void GetAttributesOf(uint c, IntPtr apidl, ref uint a);
    void GetUIObjectOf(IntPtr h, uint c, IntPtr apidl, ref Guid riid, IntPtr r, out IntPtr ppv);
    void GetDisplayNameOf(IntPtr pidl, uint flags, out STRRET s);
  }
  [DllImport("shlwapi.dll", CharSet=CharSet.Unicode)] static extern int StrRetToBuf(ref STRRET s, IntPtr pidl, StringBuilder b, uint cch);
  [DllImport("ole32.dll")] static extern void CoTaskMemFree(IntPtr p);

  // Icon display names in the desktop view's own index order (same index space as the list view).
  public static string[] GetDesktopNames() {
    var sw = (IShellWindows)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("9BA05972-F6A8-11CF-A442-00A0C90A8F39")));
    object loc = 0, root = null; int hwnd;
    object disp = sw.FindWindowSW(ref loc, ref root, 8, out hwnd, 1);
    var sp = (IServiceProv)disp;
    Guid sid = new Guid("4C96BE40-915C-11CF-99D3-00AA004AE837"), ish = new Guid("000214E2-0000-0000-C000-000000000046");
    object bro; sp.QueryService(ref sid, ref ish, out bro);
    object vo; ((IShellBrowser)bro).QueryActiveShellView(out vo);
    var fv = (IFolderView)vo;
    Guid isf = new Guid("000214E6-0000-0000-C000-000000000046");
    object fo; fv.GetFolder(ref isf, out fo);
    var folder = (IShellFolder)fo;
    int count; fv.ItemCount(2, out count);                       // SVGIO_ALLVIEW
    var names = new string[count];
    for (int i = 0; i < count; i++) {
      IntPtr pidl; fv.Item(i, out pidl);
      STRRET s; folder.GetDisplayNameOf(pidl, 0, out s);
      var sb = new StringBuilder(520); StrRetToBuf(ref s, pidl, sb, 520);
      names[i] = sb.ToString(); CoTaskMemFree(pidl);
    }
    return names;
  }
}
'@
}

function Get-DesktopListView {
  $prog = [Re4Native]::FindWindow('Progman', [NullString]::Value)
  $view = [Re4Native]::FindWindowEx($prog, [IntPtr]::Zero, 'SHELLDLL_DefView', [NullString]::Value)
  if ($view -eq [IntPtr]::Zero) {
    $w = [IntPtr]::Zero
    do {
      $w = [Re4Native]::FindWindowEx([IntPtr]::Zero, $w, 'WorkerW', [NullString]::Value)
      if ($w -ne [IntPtr]::Zero) { $view = [Re4Native]::FindWindowEx($w, [IntPtr]::Zero, 'SHELLDLL_DefView', [NullString]::Value) }
    } while ($w -ne [IntPtr]::Zero -and $view -eq [IntPtr]::Zero)
  }
  $lv = [IntPtr]::Zero
  if ($view -ne [IntPtr]::Zero) { $lv = [Re4Native]::FindWindowEx($view, [IntPtr]::Zero, 'SysListView32', [NullString]::Value) }
  if ($lv -eq [IntPtr]::Zero) { throw 'Could not find the desktop icon list view.' }
  $lv
}

# Icon display names in the desktop view's order (index = position in the list view).
function Get-DesktopIconNames { [string[]][Re4Shell]::GetDesktopNames() }

# Displays: primary first, then left to right. Index 0 = primary.
function Get-Monitors {
  Add-Type -AssemblyName System.Windows.Forms
  $all = @([System.Windows.Forms.Screen]::AllScreens | Sort-Object @{ e = { -[int]$_.Primary } }, @{ e = { $_.Bounds.X } })
  for ($i = 0; $i -lt $all.Count; $i++) {
    $s = $all[$i]
    [pscustomobject]@{ Index = $i; X = $s.Bounds.X; Y = $s.Bounds.Y; W = $s.Bounds.Width; H = $s.Bounds.Height; Primary = $s.Primary
      Label = "Display $($i + 1)  -  $($s.Bounds.Width)x$($s.Bounds.Height)" + $(if ($s.Primary) { ' (primary)' } else { '' }) }
  }
}

# Screen-space center of an image-space point when the wallpaper is shown with the Fill style on a display.
function Get-FillPoint($mon, [double]$ix, [double]$iy) {
  $s = [math]::Max($mon.W / $script:ImgW, $mon.H / $script:ImgH)
  @(($mon.X + $ix * $s - ($script:ImgW * $s - $mon.W) / 2), ($mon.Y + $iy * $s - ($script:ImgH * $s - $mon.H) / 2))
}

# A column is identified by one int: display * 100 + column (0-15). Old single-display files (0-15) map to display 1.
# $Categories: objects with .Name, .Icons (names), .Columns (keys).
# Each category fills its columns display by display, row by row, left to right.
# A category can also claim a display's TMP row (key display*100+16): 12 slots, filled left to right after its grid slots.
# Unassigned icons and category overflow go to free columns on displays where $FreeAllowed is true,
# then those displays' unclaimed TMP rows, then a block down the right edge of the primary display.
# Returns one record per icon: Index, Name, Kind (grid|tmp|right), Mon, Col, Row, Cat (-1 = unassigned).
function New-Layout {
  param([string[]]$Names, $Categories, [int]$MonitorCount = 1, [bool[]]$FreeAllowed = @($true), [bool]$SortUnassigned = $false)
  $catOf = @{}; $claimed = @{}
  for ($k = 0; $k -lt @($Categories).Count; $k++) {
    foreach ($n in @($Categories[$k].Icons)) { if (-not $catOf.ContainsKey($n)) { $catOf[$n] = $k } }
    foreach ($c in @($Categories[$k].Columns)) { if (-not $claimed.ContainsKey([int]$c)) { $claimed[[int]$c] = $k } }
  }
  $out = New-Object System.Collections.ArrayList
  $pool = New-Object System.Collections.ArrayList   # icons without a home: unassigned first, then overflow
  $idx = @{}   # name -> list indices (normally one)
  for ($i = 0; $i -lt $Names.Count; $i++) { if (-not $idx.ContainsKey($Names[$i])) { $idx[$Names[$i]] = New-Object System.Collections.ArrayList }; [void]$idx[$Names[$i]].Add($i) }
  $un = @(for ($i = 0; $i -lt $Names.Count; $i++) { if (-not $catOf.ContainsKey($Names[$i])) { $i } })
  if ($SortUnassigned) { $un = @($un | Sort-Object @{ e = { $Names[$_] } }, @{ e = { $_ } }) }
  foreach ($i in $un) { [void]$pool.Add([pscustomobject]@{ Index = $i; Name = $Names[$i]; Cat = -1 }) }
  for ($k = 0; $k -lt @($Categories).Count; $k++) {
    $slots = New-Object System.Collections.ArrayList
    for ($m = 0; $m -lt $MonitorCount; $m++) {
      $cols = @($claimed.Keys | Where-Object { $claimed[$_] -eq $k -and [math]::Floor($_ / 100) -eq $m -and ($_ % 100) -lt 16 } | Sort-Object | ForEach-Object { $_ % 100 })
      for ($r = 0; $r -lt $script:GridRows; $r++) { foreach ($c in $cols) { [void]$slots.Add(@($m, $c, $r, 'grid')) } }
      # key display*100+16 = that display's TMP row (12 slots), after the category's grid slots on that display
      if ($claimed.ContainsKey($m * 100 + 16) -and $claimed[$m * 100 + 16] -eq $k) { for ($t = 0; $t -lt $script:Strip.Count; $t++) { [void]$slots.Add(@($m, $t, 0, 'tmp')) } }
    }
    $s = 0; $seen = @{}
    foreach ($name in @($Categories[$k].Icons)) {   # the category's own icon order decides who gets the first slots
      if ($seen.ContainsKey($name) -or $catOf[$name] -ne $k -or -not $idx.ContainsKey($name)) { continue }
      $seen[$name] = $true
      foreach ($i in $idx[$name]) {
        if ($s -lt $slots.Count) {
          [void]$out.Add([pscustomobject]@{ Index = $i; Name = $Names[$i]; Kind = $slots[$s][3]; Mon = $slots[$s][0]; Col = $slots[$s][1]; Row = $slots[$s][2]; Cat = $k }); $s++
        } else { [void]$pool.Add([pscustomobject]@{ Index = $i; Name = $Names[$i]; Cat = $k }) }
      }
    }
  }
  $free = New-Object System.Collections.ArrayList
  for ($m = 0; $m -lt $MonitorCount; $m++) {
    if ($m -ge $FreeAllowed.Count -or -not $FreeAllowed[$m]) { continue }
    for ($r = 0; $r -lt $script:GridRows; $r++) { for ($c = 0; $c -lt $script:GridCols; $c++) { if (-not $claimed.ContainsKey($m * 100 + $c)) { [void]$free.Add(@($m, $c, $r, 'grid')) } } }
  }
  for ($m = 0; $m -lt $MonitorCount; $m++) {   # then the TMP rows nobody claimed, on displays that allow unassigned icons
    if ($m -ge $FreeAllowed.Count -or -not $FreeAllowed[$m] -or $claimed.ContainsKey($m * 100 + 16)) { continue }
    for ($t = 0; $t -lt $script:Strip.Count; $t++) { [void]$free.Add(@($m, $t, 0, 'tmp')) }
  }
  $f = 0; $x = 0
  foreach ($p in $pool) {
    $mon = 0
    if ($f -lt $free.Count) { $kind = $free[$f][3]; $mon = $free[$f][0]; $col = $free[$f][1]; $row = $free[$f][2]; $f++ }
    else                    { $kind = 'right'; $col = $x; $row = 0; $x++ }
    [void]$out.Add([pscustomobject]@{ Index = $p.Index; Name = $p.Name; Kind = $kind; Mon = $mon; Col = $col; Row = $row; Cat = $p.Cat })
  }
  $out
}

# Scans the desktop, builds the layout, optionally sets the wallpaper, and moves the icons. Returns the icon count.
function Invoke-DesktopArrange {
  param($Categories, [bool[]]$FreeAllowed = @($true), [bool[]]$ApplyOn = @(), [int]$GlobalX = 0, [int]$GlobalY = 0, [bool]$SortUnassigned = $false, [switch]$Wallpaper, [string]$WallpaperPath)
  $lv = Get-DesktopListView
  $names = Get-DesktopIconNames
  if ($names.Count -ne [int][Re4Native]::SendMessage($lv, 0x1004, [IntPtr]::Zero, [IntPtr]::Zero)) { throw 'Icon list changed while scanning; try again.' }
  $mons = @(Get-Monitors)
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen   # negative X/Y when a display sits left of / above the primary
  # ApplyOn: per display, false = leave that display's icons alone (empty array = every display). Unticked displays never take overflow either.
  $on = @(for ($i = 0; $i -lt $mons.Count; $i++) { $i -ge $ApplyOn.Count -or $ApplyOn[$i] })
  $fa = @(for ($i = 0; $i -lt $mons.Count; $i++) { $on[$i] -and $i -lt $FreeAllowed.Count -and $FreeAllowed[$i] })
  $layout = New-Layout -Names $names -Categories $Categories -MonitorCount $mons.Count -FreeAllowed $fa -SortUnassigned $SortUnassigned
  $sp = [int64][Re4Native]::SendMessage($lv, 0x1033, [IntPtr]::Zero, [IntPtr]::Zero)  # LVM_GETITEMSPACING
  $cellW = [int]($sp -band 0xFFFF); $cellH = [int](($sp -shr 16) -band 0xFFFF)
  if ($Wallpaper) {
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
    [void][Re4Native]::SystemParametersInfo(0x14, 0, $WallpaperPath, 3)
  }
  $st = [Re4Native]::GetWindowLong($lv, -16)                                            # auto-arrange off
  [void][Re4Native]::SetWindowLong($lv, -16, ($st -band (-bnot 0x100)))
  [void][Re4Native]::SendMessage($lv, 0x1036, [IntPtr]0x80000, [IntPtr]0)               # snap-to-grid off
  foreach ($p in $layout) {
    if (-not $on[$p.Mon]) { continue }   # 'right' block icons carry Mon 0 (the primary display)
    switch ($p.Kind) {
      'grid'  { $c = $script:Cells[$p.Col * $script:GridRows + $p.Row]; $pt = Get-FillPoint $mons[$p.Mon] $c[0] $c[1] }
      'tmp'   { $pt = Get-FillPoint $mons[$p.Mon] $script:Strip[$p.Col][0] $script:Strip[$p.Col][1] }
      'right' { $m = $mons[0]; $pt = @(($m.X + $m.W - 10 - $cellW * ([math]::Floor($p.Col / 10) + 0.5)), ($m.Y + $m.H * 330 / 1440 + $cellH * (($p.Col % 10) + 0.5))) }
    }
    $dx = $GlobalX; $dy = $GlobalY   # nudge: global + the icon's category
    if ($p.Cat -ge 0) { $dx += [int]$Categories[$p.Cat].OffX; $dy += [int]$Categories[$p.Cat].OffY }
    $x = [int][math]::Round($pt[0] - $cellW / 2 + $dx - $vs.X); $y = [int][math]::Round($pt[1] - $cellH / 2 + $dy - $vs.Y)   # list view origin = top-left of the whole desktop
    [void][Re4Native]::SendMessage($lv, 0x100F, [IntPtr]$p.Index, [IntPtr](([int64]($y -band 0xFFFF) -shl 16) -bor [int64]($x -band 0xFFFF)))
  }
  $names.Count
}

# ---------- auto-categorize ----------
# Maps desktop icon display names to what they are (shortcut target, URL, extension, folder).
# Names with no file on either Desktop folder are Windows' own items (This PC, Recycle Bin...) -> Kind 'special'.
function Get-DesktopItemInfo {
  $ws = New-Object -ComObject WScript.Shell
  $map = @{}
  foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'))) {
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue)) {
      $ext = $f.Extension.ToLower(); $target = ''
      if ($f.PSIsContainer) { $kind = 'folder' }
      elseif ($ext -eq '.lnk') { $kind = 'lnk'; try { $sc = $ws.CreateShortcut($f.FullName); $target = "$($sc.TargetPath) $($sc.Arguments)" } catch { } }
      elseif ($ext -eq '.url') { $kind = 'url'; $m = Select-String -LiteralPath $f.FullName -Pattern '^URL=(.*)$' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($m) { $target = $m.Matches[0].Groups[1].Value } }
      else { $kind = 'file' }
      $info = [pscustomobject]@{ Kind = $kind; Ext = $ext; Target = $target }
      foreach ($key in @($f.Name, $f.BaseName)) { if (-not $map.ContainsKey($key)) { $map[$key] = $info } }
    }
  }
  $map
}

function Get-CategoryRules([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Rules file not found: $Path" }
  @((Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json).rules)
}

# Returns the category name for an icon, or $null. $Info = entry from Get-DesktopItemInfo ($null = special item).
function Get-AutoCategory {
  param([string]$Name, $Info, $Rules)
  $kind = if ($Info) { $Info.Kind } else { 'special' }
  foreach ($r in $Rules) {
    try {
      if ($r.kind -and $r.kind -eq $kind) { return $r.category }
      if ($r.ext -and $Info -and @($r.ext) -contains $Info.Ext) { return $r.category }
      if ($r.name -and [regex]::IsMatch($Name, $r.name, 'IgnoreCase')) { return $r.category }
      if ($r.target -and $Info -and $Info.Target -and [regex]::IsMatch($Info.Target, $r.target, 'IgnoreCase')) { return $r.category }
    } catch { }   # a bad regex in the rules file skips that rule
  }
  $null
}
