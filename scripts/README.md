# Shell helpers

Shared shell helpers used by the dotfiles. Select `scripts` alongside `bashrc`
in `./stow-dotfiles.sh`, or link it directly from the repository root:

```bash
stow --no-folding -d "$PWD" -t "$HOME" scripts
```

`yta` in `bashrc/.bash_aliases` loads `~/.local/lib/yta/functions.bash` when
called. This small entry point reloads flag parsing, discovery, downloads,
chapter processing, and library imports on every invocation.
This file is sourced into Bash, so it needs neither executable permissions nor
an entry on `PATH`. `BEETS_DIR` can remain an unexported shell variable.

- `yta URL`: download tracks and import through beets.
- `yta --help` (`-h`): show flags, argument formats, and examples without
  requiring `BEETS_DIR` or starting downloads.
- `yta --chapters URL` (`-c`): split chapters and process their FLAC metadata/art.
- `yta --no-import URL` (`-n`): copy into `BEETS_DIR` without importing through beets.
- Combine `-c -n` to split chapters and copy them without importing.
- `yta --releases PAGE_URL` (`-r`): discover every album, EP, and single from a
  YouTube Music artist collection, then download and copy them without a beets import.

For example:

```bash
yta --releases 'https://music.youtube.com/browse/MPADUCxZ19mWaMeJAjjAAogPF7yA'
```

`--releases` takes the collection URL as its next argument and always implies
`--no-import`. Additional yt-dlp options still pass through to the download
step; `-c` also works when the individual releases contain chapters. The original
`--singles` / `-s` flag remains an alias and now queues every release type too.

Discovery preserves the title, release type, and year displayed in the collection.
Each release downloads separately so its metadata stays attached to its tracks.
Folders use `Album - TITLE`, `EP - TITLE`, or `Single - TITLE` when the type is
known. Embedded album tags contain only the clean title, which also improves
beets imports when choosing “as-is.” Beets still applies its configured paths
when importing, so its final folder can contain just the clean album title.
The collection year is written to the audio's date tag, including split chapters.
Before each release downloads, yta prints its type, title, and year. Missing
release types produce an explicit warning instead of silently using `NA`.

At the end, a formatted summary groups releases into successfully downloaded
and saved, partial downloads saved, failed, and already-downloaded skips. Each
entry shows the release type, title, and year when available; partial and failed
entries include the command's error messages. Individual tracks are not listed
as separate releases. Direct-URL invocations summarize the requested batch.

The summary prints after all imports/copies have finished, then returns to the
shell automatically. Collection runs continue after individual download or copy
failures, and return a nonzero status if any release failed. Partial downloads
still save the usable files and are explicitly marked as partial. Failed copies
or imports keep their staging directories, whose paths appear in the report.

For direct URLs, downloads prefer the source's album metadata and use its
`album_type` when available. Otherwise the title falls back to the playlist
title (with a generic `Album - `, `EP - `, or `Single - ` prefix removed), then
the video title. Unknown types use `NA - TITLE`; track counts are not used
to guess a release type. Existing library files are not renamed.

Reload the small entry point once with `source ~/.bash_aliases` (or start a new
shell). After that, workflow changes reload automatically each time yta runs.
This ensures release metadata discovered by Python reaches each download. The download
helpers also initialize metadata themselves, so an older loaded shell function
still preserves distinct release titles rather than merging them into `NA`.

Discovery uses Python 3's standard library to read YouTube Music's browse data.
The helper reads the current client configuration from the page, follows
pagination and removes duplicate release URLs. Every release listed in the
collection is queued, regardless of whether it is an album, EP, or single.
Collection filters encoded in the URL are preserved; the helper does not switch
to another release category. It completes discovery before starting any downloads. An empty result or failed page request stops the run with an error.
Only `https://music.youtube.com/browse/MPAD...` collection pages are supported;
ordinary artist home pages and individual release pages are rejected.

The discovery helper can also be run on its own to preview the URLs without
downloading audio:

```bash
python3 ~/.local/lib/yta/discover_singles.py 'https://music.youtube.com/browse/MPADUCxZ19mWaMeJAjjAAogPF7yA'
```

Add `--tsv` before the URL to preview the URL, release type, title, and year as
tab-separated fields. A `-` marks unavailable metadata. This uses the same
discovery output consumed by `yta --releases`.

YouTube Music's browse interface is unofficial and can change. This separate
helper keeps that parsing out of `.bash_aliases` and the download functions.

Other arguments pass through to yt-dlp. Existing download options, archive
location, and staging cleanup behavior are retained: empty downloads are
removed, partial downloads continue, and failed imports/copies retain staging.

Use yt-dlp's built-in cookie options in any download mode; no extra yta flag
is needed:

```bash
yta --cookies "$HOME/cookies.txt" 'https://www.youtube.com/watch?v=VIDEO_ID'
yta -c -n --cookies-from-browser firefox 'https://youtu.be/VIDEO_ID'
yta -r 'https://music.youtube.com/browse/MPAD...' --cookies-from-browser chrome
```

`--cookies FILE` reads/writes a Netscape-format cookie file.
`--cookies-from-browser BROWSER[+KEYRING][:PROFILE][::CONTAINER]` reads browser
cookies; for example, `--cookies-from-browser 'firefox:default'` selects a
profile. Quote paths or profiles containing spaces. These options reach yt-dlp
for ordinary tracks, chapters, and discovered releases. The separate collection
discovery helper fetches public pages without cookies or other yt-dlp options.

The workflow requires `BEETS_DIR` to be set, yt-dlp and its audio dependencies,
beets for imports, and `flac`/`metaflac` for chapter processing. Copies use rsync
when available and fall back to `cp`. Release discovery additionally needs
Python 3; it requires no pip packages.
