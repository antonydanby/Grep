# Grep

This project was created for the **Kai Summer Wave 2026** and demonstrates Delphi's speed when searching through files. It includes several clients, all the client code and all the component code.

Grep is a Delphi-based search and replace tool with three front ends built on the same core engine:

- **GrepCLI** - console application for scripting and batch use
- **GrepVCL** - Windows VCL desktop application
- **GrepFMX** - FireMonkey desktop application

All three use `Source\Grep.Core.pas` for the actual grep work, so search behavior and file filtering stay aligned across the applications.


## Projects

| Project | Type | Purpose |
| --- | --- | --- |
| `GrepCLI.dpr` | Console | Fast command-line search and replace |
| `GrepVCL.dpr` | VCL desktop | Native Windows UI with form-based filters and result browsing |
| `GrepFMX.dpr` | FMX desktop | Modern FireMonkey UI with the same search features |

## 🚀 What the tool supports

The shared grep engine supports:

- plain text search
- regular expression search
- search only or search-and-replace
- case-sensitive or case-insensitive matching
- filename wildcard filtering
- include or exclude subfolders
- include or exclude hidden files
- include or exclude binary files
- minimum and maximum file size filtering
- modified date range filtering

## 🛠 How `Grep.Core.pas` works

`TGrep` in `Source\Grep.Core.pas` is the shared search engine.

### Main settings

`TGrep` exposes properties that the CLI and both UIs populate before starting a search:

- `SearchMode` - `gsmText` or `gsmRegex`
- `SearchText` - text or regex pattern to match
- `ReplaceText` - replacement text for replace operations
- `CaseSensitive`
- `Wildcards`
- `IncludeSubfolders`
- `ExcludeBinary`
- `ExcludeHidden`
- `MinSize`
- `MaxSize`
- `DateFrom`
- `DateTo`

Defaults are set in the constructor. Out of the box it searches all files, includes subfolders, and excludes hidden and binary files.

### Search flow

`TGrep.Search`:

1. starts a background task
2. enumerates files with `TDirectory.GetFiles`
3. applies the file filters in `FileMatchesFilters`
4. checks file contents with `FileContainsMatch`
5. raises `OnFileFound` for each matching file
6. raises `OnSearchCompleted` when the scan finishes

`TGrep.Replace` follows the same broad flow, but loads matching files into a `TStringList`, replaces text or regex matches, saves the file, and then raises `OnFileFound` for each modified file.

### Matching

- Text search uses `Contains` or `ContainsText`
- Regex search uses `TRegEx`
- Case-insensitive regex mode adds `roIgnoreCase`
- Replace uses `StringReplace` for text mode and `TRegEx.Replace` for regex mode

### File filtering

`FileMatchesFilters` checks:

- file size
- file timestamp
- hidden attribute
- binary content

Binary detection currently reads the file bytes and treats a file as binary if a null byte is found in the first 1024 bytes.

### Match retrieval

Once a front end receives `OnFileFound`, it can call `RequestMatches` for that file. `RequestMatches` gathers the matching lines via `GetMatches` and delivers them through `OnRequestedContents`.

`GetMatches` currently returns the matched lines and line numbers for a file. The surrounding context lines used by the desktop UIs are assembled in the form layer after loading the source file again.

## Result model: `MatchesList.pas`

`Source\MatchesList.pas` provides the shared in-memory result model used by the desktop applications.

`TMatchesData` stores:

- filename
- file timestamp
- line number
- matched line text
- lines above the match
- lines below the match
- expanded/collapsed display state

`TMatchesList` wraps an object list and provides simple navigation, filtering, sorting, and current-item tracking.

## GrepCLI

`GrepCLI` is intended for terminal use and automation.

### Command-line options

- `-folder <path>` - required root folder
- `-text <text>` - plain text search
- `-regex <pattern>` - regex search
- `-replace <text>` - replacement text
- `-dryrun` - preview a replace operation without writing files
- `-wildcards <pattern>` - file mask, default `*.*`
- `-casesensitive`
- `-nosubfolders`
- `-includehidden`
- `-includebinary`
- `-minsize <bytes>`
- `-maxsize <bytes>`
- `-datefrom <yyyy-mm-dd>`
- `-dateto <yyyy-mm-dd>`
- `-showmatches <n>`
- `-logfile <path>`

### CLI behavior

The CLI wires the `TGrep` events directly:

- `OnFileFound` prints `FOUND: <file>`
- `OnRequestedContents` prints matching lines as `<file> (<line>): <text>`
- `OnSearchCompleted` signals overall completion

The CLI waits on an event until both the directory scan is complete and all requested match dumps have been written. Optional logfile output is flushed as results are written.

### Examples

```text
GrepCLI -folder D:\Projects -text JSON -wildcards *.pas
GrepCLI -folder D:\Projects -regex "\bclass\b" -showmatches 5
GrepCLI -folder D:\Projects -text OldName -replace NewName -dryrun
GrepCLI -folder D:\Projects -text Grep.Core -wildcards *.pas -logfile .\grep.log
```

## GrepVCL

`GrepVCL` is the native Windows desktop edition.

The main form in `Source\MainForm_VCL.pas` configures a `TGrep` instance from the UI and presents results in a `TListView`. It supports:

- text or regex mode
- case-sensitive searching
- replace mode
- wildcard filtering
- subfolder, hidden file, and binary file options
- date range filters
- min/max file size filters
- configurable context lines

When a file match is reported, the form requests detailed line matches from `TGrep`, converts them into `TMatchesData`, and stores them in `TMatchesList`. The VCL result view can expand or collapse a match to show the surrounding lines, with the matched line visually emphasized.

## GrepFMX

`GrepFMX` is the FireMonkey desktop edition.

The main form in `Source\MainForm_FMX.pas` owns the design-time UI and drives `TGrep`. Display logic is kept separate in `Source\MatchesDisplay_FMX.pas`.

The FMX version provides the same core search and filter features as the VCL version, with:

- a modern card-based filter page
- a results page backed by `TListView`
- expandable result details
- a custom-painted detail area for the selected match

Like the VCL version, it converts `TGrep` line matches into `TMatchesData` entries and uses `MatchesList` as the backing store for result browsing.

## 📖 Source layout

| Path | Purpose |
| --- | --- |
| `Source\Grep.Core.pas` | Shared search and replace engine |
| `Source\MatchesList.pas` | Shared desktop result model |
| `Source\MainForm_VCL.pas` | VCL main form and UI behavior |
| `Source\MatchesDisplay_VCL.pas` | VCL result rendering support |
| `Source\MainForm_FMX.pas` | FMX main form and UI behavior |
| `Source\MatchesDisplay_FMX.pas` | FMX result display logic |
| `GrepCLI.dpr` | Console entry point |
| `GrepVCL.dpr` | VCL desktop entry point |
| `GrepFMX.dpr` | FMX desktop entry point |

## Notes

- The CLI, VCL, and FMX applications intentionally share the same grep engine rather than reimplementing search logic per UI.
- The desktop applications build additional display context around the matched line after `TGrep` reports the raw hits.
- If you change filtering or matching behavior in `Grep.Core.pas`, that change affects all three front ends.
  
# 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
