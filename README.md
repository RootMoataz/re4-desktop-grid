# RE4 Desktop Grid

Turn your Windows 11 desktop into a Resident Evil 4 attaché-case inventory: the included wallpaper has a 16 × 8 grid, and this tool snaps your desktop icons into the grid cells, grouped into categories you define.

## Features

- **Scans your desktop** and lists every icon.
- **Categories** — create them, add icons, and give each category one or more **columns** of the grid. Categories fill their columns row by row, left to right.
- **Multiple monitors** — each display has its own 16 × 8 grid; a category can span displays. Per display you choose whether unassigned icons may use its free columns.
- **Choose which displays to apply to** â€” each display has an "Apply to this display" checkbox; icons that belong on an unticked display are left where they are, and unticked displays never receive overflow icons.
- **Auto-categorize** — sorts icons into categories from what they point to (shortcut target, `steam://` links, file extension, folders) and name rules in `categories.rules.json` (editable, first match wins).
- **Suggest columns** — gives column-less categories columns (8 icons per column), biggest first.
- **Sort icons A-Z** — orders icons in every category and the unassigned ones before you apply.
- **Nudge sliders** — shift icons horizontally/vertically inside their cells (all icons or just the selected category), shown live on the desktop after the first Apply.
- **TMP rows** — the "TMP" bar at the bottom of the wallpaper (12 slots) is clickable per display: give a category a display's TMP row like you would a column, and its icons fill it left to right (after its grid columns on that display).
- Unassigned icons and overflow use free columns, then unclaimed TMP rows (on displays that allow it), then a block down the right edge of the primary display.

## Requirements

Windows 11, 64-bit Windows PowerShell 5.1 (built in). No installs.

## Usage

Double-click **`Re4-IconArranger.cmd`** (or run **`Create-Shortcut.cmd`** once to put a "RE4 Desktop Arranger" shortcut with the RE4 icon on your Desktop) (or run `Re4-IconArranger.ps1` with `powershell -STA`).

1. *Rescan desktop*, then *Auto-categorize unassigned* (or build categories by hand).
2. Pick a display, select a category, click/drag columns in the grid to give it to that category (or use *Suggest columns*).
3. *Sort icons A-Z* if you want alphabetical order.
4. *Apply to desktop*. Optionally tick *Also set the RE4 wallpaper*.

Your setup is saved to `layout.json` next to the scripts (git-ignored). `Set-Re4Desktop.ps1` is the earlier one-shot script that just snaps all icons into the grid without any UI.

## How it works

- Icon names come from Windows' own `IFolderView` shell interface; icons are positioned with the desktop list view's `LVM_SETITEMPOSITION`. Auto-arrange and snap-to-grid are switched off so Explorer doesn't undo the placement. Nothing is injected into other processes.
- The grid cell centres were measured from `wallpaper.jpg` (1672 × 941) and are scaled to each display using the *Fill* wallpaper style, so a 16:9 display lines up exactly. Other aspect ratios follow Fill's centre-crop.
- If you use a different wallpaper, the cell coordinates at the top of `Re4Core.ps1` have to be re-measured.

## Known limits

- Developed on a 2560 × 1440 primary display with a 1920 × 1080 display to its right. Placing icons on the second display is untested. Displays left of / above the primary and mixed Windows scaling are handled but only tested in code, not on such a setup. Portrait displays get the landscape wallpaper centre-cropped, so their grid is cut off.
- Both displays show the same wallpaper.
- Icons reshuffle if Explorer restarts or the resolution changes; just press Apply again.
- Applying overwrites your current icon positions (they are not backed up).

## Artwork

`wallpaper.jpg` is a screenshot of Capcom's *Resident Evil 4* inventory screen, included for convenience. It belongs to Capcom; this project is unaffiliated and not licensed to redistribute it. Swap in your own image if you prefer.
