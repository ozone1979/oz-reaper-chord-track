# Oz Reaper Chord Track

This script set gives a Chord Track-style workflow in REAPER with:

1. A selected MIDI chord source track.
2. Key/Scale capture from the MIDI editor Key Snap root + scale.
3. Snap modes for existing MIDI and live/recorded MIDI.
4. Per-track Auto-snap Arm modes (Studio One-style): **Off**, **Chords**, **Scales**, **Chords + Scales**.
5. A dockable panel showing key/scale, chord track, selected track arm status, and arm/snap controls.
6. Chord blocks in the panel timeline lane (Scaler-style) with chord name + scale degree labels.
7. Interactive chord blocks: double-click to open/zoom for editing, right-click for inversions/substitutions/chord transforms.

## Files

- `index.xml` (ReaPack repository index)
- `RELEASE.md` (quick release checklist)
- `tools/generate-reapack-index.ps1` (regenerates `index.xml` from current files)
- `tools/publish-reapack-release.ps1` (one-command tag-based ReaPack release)
- `tools/sync-reaper-scripts.ps1` (one-command sync to local REAPER `Scripts/.../Oz Reaper Chord Track/Scripts` test mirror)
- `Oz Chord Track - Register actions from actions folder.lua` (optional bulk action registrar)
- `Oz Chord Track - Cleanup stale top-level actions.lua` (optional migration cleanup helper)
- `Oz Chord Track Core.lua` (compatibility loader that forwards to `libs/Oz Chord Track Core.lua`)
- `actions/*.lua` (canonical user-facing Action List scripts)
- `actions/Oz Chord Track Core.lua` (action-side core bridge)
- `libs/Oz Chord Track - Start input snap manager (experimental).lua` (internal)
- `libs/Oz Chord Track - Stop input snap manager (experimental).lua` (internal)
- `libs/Oz Chord Track Core.lua` (internal implementation)
- `libs/Oz Chord Track Loader.lua` (shared helper/loader for wrappers and internal script resolution)
- `Effects/ReaTrak/Oz Chord Track Input Snap` (JSFX companion for manager)

Hierarchy note:

- `actions/` is the authoritative location for user actions.
- `libs/` contains non-user-called implementation scripts and shared loaders.
- Top-level no longer duplicates the full action list.

## Setup in REAPER

1. Open **Actions** and import scripts from this folder.
	- Import scripts from `actions/`.
	- If you previously imported top-level actions from older versions, run/import `Oz Chord Track - Cleanup stale top-level actions.lua` once.
	- Optional: run/import `Oz Chord Track - Register actions from actions folder.lua` to auto-register all `actions/Oz Chord Track - *.lua` scripts.
	- Do not import scripts from `libs/`.
2. Optionally bind shortcuts or toolbar buttons.
3. Open any MIDI item in the MIDI editor, enable **Key snap**, choose root+scale.

## Local ReaPack sync/testing mirror

If you keep a local REAPER test mirror at `%APPDATA%\REAPER\Scripts\Oz Reaper Chord Track\Scripts`, run:

- `powershell -ExecutionPolicy Bypass -File .\tools\sync-reaper-scripts.ps1 -Verify`

Optional overrides:

- `-DestinationRoot "C:\path\to\REAPER\Scripts\Oz Reaper Chord Track\Scripts"`
- `-SourceRoot "C:\path\to\repo\Oz Reaper Chord Track"`

## ReaPack feed (GitHub)

This repo now includes a ReaPack index at `index.xml` and a generator script.

Default feed URL (after push):

- `https://raw.githubusercontent.com/ozone1979/oz-reaper-chord-track/main/index.xml`

Latest release:

- `v0.1.2` — `https://github.com/ozone1979/oz-reaper-chord-track/releases/tag/v0.1.2`

Regenerate the index after adding/removing actions or support files:

- `powershell -ExecutionPolicy Bypass -File .\tools\generate-reapack-index.ps1 -GithubOwner "ozone1979" -RepoName "oz-reaper-chord-track" -Branch "main" -Version "0.1.0" -Author "ozone1979"`

For new releases, bump `-Version` before committing so ReaPack sees an update.

If the final GitHub owner/repo differs, rerun the generator with the correct `-GithubOwner` and `-RepoName` values, then commit/push the updated `index.xml`.

### Tag-based releases (recommended)

Use tag-pinned source URLs so each ReaPack version references immutable files.

- `powershell -ExecutionPolicy Bypass -File .\tools\publish-reapack-release.ps1 -Version "0.1.1" -GithubOwner "ozone1979" -RepoName "oz-reaper-chord-track" -Author "ozone1979"`

What this does:

1. Regenerates `index.xml` with source URLs pinned to `v<Version>`.
2. Commits the updated `index.xml`.
3. Creates annotated git tag `v<Version>`.
4. Pushes `main` and the tag.
5. Creates a GitHub release for that tag.
6. Updates README `Latest release` to the new tag.

CI automation:

- `.github/workflows/reapack-tag-release.yml` validates that all `index.xml` source URLs are pinned to the pushed tag and ensures a GitHub release exists for that tag.
- For a step-by-step operator checklist, use `RELEASE.md`.

## Core workflow

### A) Set the chord track

1. Select the MIDI chord source track.
2. Run **Set selected track as chord track**.

Chord notes are read from overlapping MIDI notes on this track at note time.

### B) Capture key+scale from MIDI editor

1. In MIDI editor set **Key snap** root + scale.
2. Run **Sync key+scale from MIDI editor**.

### C) Snap MIDI directly

Run one of:

- **Snap selected MIDI to chords and scale**
- **Snap selected MIDI to chords only**
- **Snap selected MIDI to scale only**

Target priority is:

1. Active MIDI editor take,
2. Selected MIDI items,
3. All MIDI items on selected tracks (excluding the chord track).

### D) One-click variants

- **One-click setup+sync+snap (chords and scale)**
- **One-click setup+sync+snap (chords only)**
- **One-click setup+sync+snap (scale only)**

These set chord track from selection, sync MIDI editor key/scale, then snap.

## Auto-snap Arm modes (per-track)

Set selected target track(s) with:

- **Arm selected tracks for auto snap Chords**
- **Arm selected tracks for auto snap Scales**
- **Arm selected tracks for auto snap Chords+Scales**
- **Disarm selected tracks auto snap**
- **UnArm all target tracks auto snap**

Then run:

- **Snap selected tracks by auto snap arm** (uses each selected track’s assigned arm mode)
- **Snap armed tracks now (assigned modes)** (uses arm modes across all tracks)
- **Snap selected tracks now to chords / scale / chords and scale**

Tracks set to **Off** are not snapped.

## Dockable panel

Run:

- **Open dockable panel**

The panel shows:

- A tabbed top area with scrollable per-tab content
- Chord blocks from the chord track in a dedicated bottom lane, aligned to the current arrange horizontal zoom/scroll
- Scaler-style block labels with centered chord name and degree badge
- Color-tinted chord blocks by interpreted quality (major/minor/dominant/etc.)

It also includes:

- **Home tab**: scale info/sync, chord track label + assign button, and selected-track Follow summary
- **Snap tab**: merged Follow+Snap workflow for selected tracks with four core controls (**Arm = Ready to snap**, **Snap now**, **Pre/Post Recording**, **Snap Method**) plus an **UnArm All** convenience button and runtime diagnostics
- **Theme tab**: chord block theme controls (Auto / Blue / Purple / Neutral)
- **Theme tab**: timeline align offset control (−32 px to +32 px) with coarse (1 px) and fine (0.5 px) modes for ruler/chord-lane alignment
- A top-right compact-view toggle icon (Normal/Compact)
- In **Compact** view, Home is arranged in horizontal cards/columns instead of a single vertical list
- In **Compact** view, non-Home tabs open in a disconnected popout window (Snap/Theme) with an **X** exit button
- Compact popout windows remember their last position and size between launches
- In **Compact** view, chord-lane alignment takes priority; Home content is placed beside the lane only when true alignment-side space exists, otherwise it stacks above while keeping both regions visible
- In **Compact** Home, scrolling now keeps partially visible items rendered (no pop-in/pop-out at viewport edges)
- When Compact Home cards stack to one column, vertical gaps between cards are removed
- Main-panel tab buttons stay visible at small widths by adapting label style (full text → short text → icon)
- The bottom status strip is always drawn with an opaque background (no transparent gap)
- In **Compact** Home view, the chord-block lane shifts upward to sit directly under the Home content (reduced empty gap)

The Home tab only contains scale, chord track selection/label, and selected-track Follow status/trigger.

Responsive readability behavior:

- Tab content auto-adjusts font sizes, row spacing, and button density based on panel size
- Long labels are trimmed to fit narrow widths while keeping options accessible via tab-specific menus
- Tab rows are clipped to the tab content area to prevent content from drawing over the tab bar
- Chord-block labels (degree badge, chord name, quality tag) now auto-fit by both block width and block height for stable readability in compact spacing
- Quality tags hide earlier on narrow blocks so chord names retain priority and stay readable

Chord-block interactions:

- **Double-click** a chord block to open MIDI editor on that chord and zoom to the selected chord notes
- **Right-click** a chord block for quick actions:
	- Open in MIDI editor
	- Invert up / invert down
	- Set chord to Major / Minor / Dominant 7 / Major 7
	- Substitute Relative Minor / Relative Major / Tritone
- Labels update automatically when chord notes change
- **Auto** theme follows REAPER theme brightness (dark themes bias Purple; light themes bias Neutral)

## Live mode (experimental)

Preferred unified actions:

- **Start new note snap (Pre)**
- **Start new note snap (Post)**
- **Stop new note snap**

Optional preset Post-start actions:

- **Start new note snap (Post - Chords+Scales)**
- **Start new note snap (Post - Chords)**
- **Start new note snap (Post - Scales)**

Start actions:

- **Start live snap to chords and scale (experimental)**
- **Start live snap to chords only (experimental)**
- **Start live snap to scale only (experimental)**
- **Start live snap by auto snap arm mode (experimental)**
- **Start auto snap armed tracks on record (experimental)**

These Action List entries are compatibility aliases that now start unified **Snap tab → Selected Track Snap → Post Recording (Live engine)** using the mapped snap method.

Stop action:

- **Stop live snap**

This Action List entry remains a compatibility alias that calls unified new-note-snap stop.

Panel control note:

- In current panel UI, live post-processing is controlled from **Snap tab → Selected Track Snap → Post Recording (Live engine)**.

In auto-snap-arm live action, record-armed tracks use each track’s Auto-snap Arm mode.
In record-only auto-snap action, snapping only runs while REAPER is actively recording.
In fixed live snap modes (Chords + Scales / Chords / Scales), target tracks must be armed (ready to snap), then can be record-armed or input-monitored.
Snap sections in both docked and popout panels show New Note Snap runtime diagnostics (for example: manager running status for Pre mode, or live-engine waiting/active state for Post mode).
When record-only mode is used, post-record snapping now retries briefly after stop so takes that appear after save/discard prompts are still processed.

## Input snap manager (experimental)

This is the **Pre** branch of the unified New Note Snap workflow: a background ReaScript updates shared chord/scale state and auto-manages a JSFX input snap filter on armed target tracks.

Actions:

- **Start input snap manager (experimental)**
- **Stop input snap manager (experimental)**
- **Repair input snap FX instances** (runs Stop+Start manager to rebuild clean JSFX instances)

Implementation note:

- Manager implementation scripts live under `libs/`; top-level Start/Stop entries are compatibility wrappers.

How it works:

- Uses the stored chord track + stored scale from this script set
- In unified **Snap tab → Selected Track Snap → Pre Recording**, uses the selected-track snap method (**Chords / Scales / Chords + Scales**) as an override for active targets
- Changing selected-track **Snap Method** while **Pre** is running updates manager override/JSFX follow mode live (no restart required), and status now indicates whether the input manager was started or already running
- Disarming selected tracks (arm toggle Off) removes those tracks from new-note-snap targeting
- **UnArm All** clears auto-snap arming from all target tracks (chord track excluded)
- If JSFX files are updated, run **Repair input snap FX instances** once to reload clean instances before testing live Follow-mode display updates
- If started directly by action (outside unified UI), it falls back to each armed track’s Follow mode from Auto-snap Arm assignment
- Auto-inserts/enables **JS: ReaTrak/Oz Chord Track Input Snap** on armed target tracks
- Disables that JSFX on tracks that are not currently active targets
- Remaps incoming note-on/note-off in the input FX stage (before recording)

Notes:

- Track must be record-armed to be managed as an active input target
- If no chord is active at the current time position, scale-only behavior may dominate depending on track mode
- Snap-tab arming flow automatically starts/stops one pipeline at a time (Pre manager or Post live engine) based on whether armed targets exist
- Stopping the input snap manager clears managed input-snap JSFX instances so the next start can rebuild a clean single instance per target track

## Notes

- Scale capture requires an active MIDI editor with a valid MIDI take
- Chord+Scale mode prefers intersection; if empty, it falls back to chord tones
- Live behavior is best-effort and applies to newly detected notes on live target tracks (record-armed, or input-monitored in fixed live modes)
- Status/message wording is now normalized across Action List dialogs, the docked panel, and the compact popout window
