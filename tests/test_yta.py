"""Exercise the sourced yta workflow without downloads or library imports."""

import json
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["YTA_LOG"], "a") as log:
    log.write(json.dumps([name, args]) + "\n")
if name == "yt-dlp":
    outcome = json.loads(os.environ.get("MOCK_DOWNLOAD_RESULTS", "{}" )).get(args[-1], {})
    if outcome.get("stderr"):
        print(outcome["stderr"], file=sys.stderr)
    if os.environ.get("YTA_REAL_METADATA"):
        import subprocess
        fixture = Path(os.environ["YTA_REAL_METADATA"])
        result = subprocess.run(
            [sys.executable, "-m", "yt_dlp", "--ignore-config", *args[:-1],
             "--simulate", "--load-info-json", str(fixture), "--print", "%()j"],
            capture_output=True, text=True, check=True)
        info = json.loads(result.stdout)
        output = Path(info["_filename"])
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text("simulated audio")
        with open(os.environ["YTA_LOG"], "a") as log:
            log.write(json.dumps(["metadata", info]) + "\n")
        sys.exit(0)
    output = args[args.index("-o") + 1]
    run = Path(output.split("/_source/")[0].split("/%(")[0])
    if outcome.get("empty", os.environ.get("EMPTY")) != "1":
        album = run / "An Artist" / os.environ.get("ALBUM_NAME", "An Album")
        album.mkdir(parents=True)
        (album / "01 - A Track.flac").write_text("original audio")
        if "--split-chapters" in args:
            (album / "cover.jpg").write_text("art")
            (run / "_source").mkdir()
            (run / "_source" / "original.flac").write_text("full video")
    sys.exit(int(outcome.get("status", os.environ.get("DOWNLOAD_STATUS", "0"))))
elif name == "beet":
    sys.exit(int(os.environ.get("IMPORT_STATUS", "0")))
elif name == "rsync":
    status = int(os.environ.get("COPY_STATUS", "0"))
    if not status:
        shutil.copytree(args[-2], args[-1], dirs_exist_ok=True)
    sys.exit(status)
elif name == "ffmpeg":
    if os.environ.get("FFMPEG_STATUS"):
        print("ERROR: chapter audio decoding failed", file=sys.stderr)
        sys.exit(int(os.environ["FFMPEG_STATUS"]))
    sys.stdout.write("decoded audio")
elif name == "flac":
    Path(args[args.index("-o") + 1]).write_text(sys.stdin.read())
'''


class YtaTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.library = self.home / "Music Library"
        self.log = self.home / "calls.jsonl"
        helpers = self.home / ".local/lib/yta"
        helpers.mkdir(parents=True)
        for name in ("functions.bash", "discover_singles.py"):
            (helpers / name).symlink_to(ROOT / "scripts/.local/lib/yta" / name)
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        mock = bin_dir / "mock"
        mock.write_text(MOCK)
        mock.chmod(0o755)
        for command in ("yt-dlp", "beet", "rsync", "ffmpeg", "flac", "metaflac"):
            (bin_dir / command).symlink_to(mock)
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=f"{bin_dir}:{os.environ['PATH']}",
                        TEST_LIBRARY=str(self.library), YTA_LOG=str(self.log))
        self.env.pop("BEETS_DIR", None)
        self.env.pop("BASH_ENV", None)

    def run_yta(self, *args, configured=True, discovery=None, **env):
        # Deliberately leave BEETS_DIR unexported, as in a local shell config.
        script = 'source "$1"; shift; '
        if discovery is not None:
            # Substitute discovery at the Python boundary; the sourced shell
            # helper and the remaining download/copy workflow still run.
            script += '''python3() {
                printf '%s\\n' "$DISCOVER_URLS"
                return "${DISCOVER_STATUS:-0}"
            }; '''
            env["DISCOVER_URLS"] = discovery
        if configured:
            script += 'BEETS_DIR="$TEST_LIBRARY"; '
        script += 'yta "$@"'
        return subprocess.run(
            ["bash", "--noprofile", "--norc", "-c", script, "test",
             str(ROOT / "bashrc/.bash_aliases"), *args],
            env=self.env | env, capture_output=True, text=True,
        )

    def calls(self, name):
        if not self.log.exists():
            return []
        return [args for command, args in map(json.loads, self.log.read_text().splitlines())
                if command == name]

    def staged_runs(self):
        return list((self.library / "_staging").glob("ytplxflac.*"))

    def test_default_download_imports_and_cleans_staging(self):
        url = "https://example.test/watch?v=123&list=456"
        result = self.run_yta("--playlist-items", "1:2", url)
        self.assertEqual(result.returncode, 0, result.stderr)
        opts = self.calls("yt-dlp")[0]
        self.assertEqual(opts[-3:], ["--playlist-items", "1:2", url])
        self.assertIn("--embed-metadata", opts)
        self.assertNotIn("--split-chapters", opts)
        self.assertEqual(self.calls("beet")[0][:3],
                         ["--directory", str(self.library), "import"])
        self.assertEqual(self.staged_runs(), [])

    def test_help_requires_no_configuration_or_workflow_side_effects(self):
        for flag in ("--help", "-h"):
            with self.subTest(flag=flag):
                result = self.run_yta(flag, configured=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                for option in ("Usage:", "--chapters", "--no-import", "--releases",
                               "--singles", "--cookies FILE", "--cookies-from-browser",
                               "BROWSER[+KEYRING][:PROFILE][::CONTAINER]", "Examples:"):
                    self.assertIn(option, result.stdout)
                self.assertEqual(result.stderr, "")
                self.assertFalse(self.log.exists())
                self.assertFalse(self.library.exists())
                self.assertFalse((self.home / ".config/yt-dlp").exists())

    def test_entry_point_reloads_the_workflow_each_time(self):
        result = subprocess.run(
            ["bash", "--noprofile", "--norc", "-c",
             'source "$1"; yta_run() { return 99; }; yta --help',
             "test", str(ROOT / "bashrc/.bash_aliases")],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Usage:", result.stdout)

    def test_cookie_options_reach_every_download_mode(self):
        for flags in ((), ("-n",), ("-c",), ("-c", "-n"),
                      ("-r", "page"), ("-c", "-s", "page")):
            for cookie_args in (("--cookies", str(self.home / "my cookies.txt")),
                                ("--cookies-from-browser", "firefox:My Profile"),
                                ("--cookies=" + str(self.home / "my cookies.txt"),),
                                ("--cookies-from-browser=firefox:My Profile",)):
                with self.subTest(flags=flags, cookie_args=cookie_args):
                    result = self.run_yta(*flags, *cookie_args, "url",
                                          discovery="https://music.youtube.com/browse/MPRE_one")
                    self.assertEqual(result.returncode, 0, result.stderr)
                    opts = self.calls("yt-dlp")[-1]
                    start = opts.index(cookie_args[0])
                    self.assertEqual(opts[start:start + len(cookie_args)], list(cookie_args))

    def test_cookie_options_require_a_value_before_starting_work(self):
        for flag in ("--cookies", "--cookies-from-browser"):
            for tail in ((), ("",), ("--chapters",)):
                with self.subTest(flag=flag, tail=tail):
                    result = self.run_yta(flag, *tail)
                    self.assertEqual(result.returncode, 2)
                    self.assertIn("requires a value", result.stderr)
                    self.assertFalse(self.log.exists())
                    self.assertFalse(self.library.exists())

    def test_chapters_process_metadata_before_import(self):
        result = self.run_yta("--chapters", "url")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--split-chapters", self.calls("yt-dlp")[0])
        self.assertEqual(len(self.calls("ffmpeg")), 1)
        tags, art = self.calls("metaflac")
        self.assertIn("--set-tag=ARTIST=An Artist", tags)
        self.assertIn("--set-tag=TITLE=A Track", tags)
        self.assertTrue(art[0].startswith("--import-picture-from=3||||"))
        self.assertEqual(len(self.calls("beet")), 1)
        self.assertEqual(self.staged_runs(), [])

    def test_no_import_and_combined_short_flags(self):
        for flags in (("--no-import",), ("-c", "-n")):
            with self.subTest(flags=flags):
                result = self.run_yta(*flags, "url")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls("beet"), [])
                track = self.library / "An Artist/An Album/01 - A Track.flac"
                self.assertTrue(track.exists())
                self.assertFalse((self.library / "_source").exists())
                self.assertEqual(self.staged_runs(), [])

    def test_missing_configuration_does_not_download(self):
        result = self.run_yta("url", configured=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("BEETS_DIR is not set", result.stderr)
        self.assertEqual(self.calls("yt-dlp"), [])

    def test_empty_download_fails_and_cleans_staging(self):
        result = self.run_yta("url", EMPTY="1", DOWNLOAD_STATUS="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("downloaded no files", result.stderr)
        self.assertEqual(self.calls("beet"), [])
        self.assertEqual(self.staged_runs(), [])

    def test_partial_download_continues_to_import(self):
        result = self.run_yta("url", DOWNLOAD_STATUS="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("reported some errors", result.stderr)
        self.assertEqual(len(self.calls("beet")), 1)

    def test_failed_import_keeps_staging_and_status(self):
        result = self.run_yta("url", IMPORT_STATUS="7")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(len(self.staged_runs()), 1)
        self.assertIn("keeping staging directory", result.stderr)
        self.assertIn("Failed (1)", result.stdout)
        self.assertIn("beets import failed; keeping staging directory", result.stdout)

    def test_failed_copy_keeps_staging_and_status(self):
        result = self.run_yta("-n", "url", COPY_STATUS="9")
        self.assertEqual(result.returncode, 9)
        self.assertEqual(len(self.staged_runs()), 1)
        self.assertIn("keeping staging directory", result.stderr)

    def test_releases_routes_discovered_urls_to_download_and_skips_import(self):
        urls = ["https://music.youtube.com/browse/MPRE_first",
                "https://music.youtube.com/browse/MPRE_second"]
        for flag in ("--releases", "-r", "--singles", "-s"):
            with self.subTest(flag=flag):
                result = self.run_yta(
                    flag, "https://music.youtube.com/browse/MPADartist",
                    "--playlist-items", "1:2", discovery="\n".join(urls),
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                downloads = self.calls("yt-dlp")[-2:]
                for opts, url in zip(downloads, urls):
                    self.assertEqual(opts[-3:], ["--playlist-items", "1:2", url])
                opts = downloads[-1]
                self.assertNotIn(flag, opts)
                self.assertNotIn("https://music.youtube.com/browse/MPADartist", opts)
                self.assertEqual(self.calls("beet"), [])
                self.assertEqual(self.staged_runs(), [])
                self.assertTrue((self.library / "An Artist/An Album/01 - A Track.flac").exists())

    def test_release_metadata_is_scoped_to_each_download(self):
        result = self.run_yta("-r", "page", discovery=(
            "https://music.youtube.com/browse/MPRE_one\tSingle\t100% Love\n"
            "https://music.youtube.com/browse/MPRE_two\tEP\tSecond Release"))
        self.assertEqual(result.returncode, 0, result.stderr)
        first, second = self.calls("yt-dlp")
        self.assertIn("100% Love", first)
        self.assertIn("Single", first)
        self.assertIn("Second Release", second)
        self.assertIn("EP", second)
        self.assertNotIn("100% Love", second)
        self.assertEqual(self.staged_runs(), [])

    @unittest.skipUnless(importlib.util.find_spec("yt_dlp"), "yt-dlp Python module is not installed")
    def test_release_workflow_copies_into_distinct_real_yt_dlp_paths(self):
        fixture = self.home / "info.json"
        fixture.write_text(json.dumps({
            "id": "offline", "title": "Track", "uploader": "Artist",
            "playlist_title": "Album - Generic Title", "ext": "webm",
            "url": "https://example.invalid/audio.webm", "vcodec": "none",
            "acodec": "opus", "extractor": "generic", "extractor_key": "Generic",
        }))
        result = self.run_yta("-r", "page", YTA_REAL_METADATA=str(fixture), discovery=(
            "https://music.youtube.com/browse/MPRE_one\tSingle\tFirst\n"
            "https://music.youtube.com/browse/MPRE_two\tEP\tSecond\n"
            "https://music.youtube.com/browse/MPRE_three\t-\tThird"))
        self.assertEqual(result.returncode, 0, result.stderr)
        for folder in ("Single - First", "EP - Second", "NA - Third"):
            self.assertTrue(any((self.library / "Artist" / folder).glob("*")), folder)
        self.assertEqual([info["meta_album"] for info in self.calls("metadata")],
                         ["First", "Second", "Third"])
        self.assertFalse((self.library / "Artist/NA").exists())
        self.assertEqual(self.staged_runs(), [])

    @unittest.skipUnless(importlib.util.find_spec("yt_dlp"), "yt-dlp Python module is not installed")
    def test_captured_collection_response_reaches_real_download_paths_and_tags(self):
        # Only HTTP and audio downloads are replaced. The real discovery CLI,
        # TSV parsing, shell metadata handoff, and yt-dlp CLI all execute.
        http_fixture = ROOT / "tests/fixtures/yta_collection.json"
        python_shim = self.home / "bin/python3"
        python_shim.write_text(f'''#!{sys.executable}
import io, os, runpy, sys
from pathlib import Path
if len(sys.argv) > 1 and sys.argv[1].endswith("discover_singles.py"):
    import urllib.request
    def urlopen(request, **kwargs):
        if request.data is None:
            return io.BytesIO(b'<script>ytcfg.set({{"INNERTUBE_CONTEXT": {{"client": {{"hl": "en"}}}}}});</script>')
        return io.BytesIO(Path(os.environ["YTA_HTTP_FIXTURE"]).read_bytes())
    urllib.request.urlopen = urlopen
    sys.argv = sys.argv[1:]
    runpy.run_path(sys.argv[0], run_name="__main__")
else:
    os.execv(sys.executable, [sys.executable, *sys.argv[1:]])
''')
        python_shim.chmod(0o755)
        info_fixture = self.home / "track.json"
        info_fixture.write_text(json.dumps({
            "id": "offline", "title": "Track", "uploader": "Artist", "ext": "webm",
            "url": "https://example.invalid/audio.webm", "vcodec": "none",
            "acodec": "opus", "extractor": "generic", "extractor_key": "Generic",
        }))
        result = self.run_yta("-r", "https://music.youtube.com/browse/MPADartist",
                              YTA_REAL_METADATA=str(info_fixture), YTA_HTTP_FIXTURE=str(http_fixture))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Single - Win, Win (year: 2026)", result.stderr)
        self.assertIn("EP - The Problem With Everything (year: 2024)", result.stderr)
        self.assertTrue((self.library / "Artist/Single - Win, Win").is_dir())
        self.assertTrue((self.library / "Artist/EP - The Problem With Everything").is_dir())
        self.assertEqual([info["meta_date"] for info in self.calls("metadata")], ["2026", "2024"])
        self.assertEqual(self.staged_runs(), [])

    def test_chapter_album_tag_does_not_include_folder_type(self):
        result = self.run_yta("-c", "-n", "url", ALBUM_NAME="EP - An Album")
        self.assertEqual(result.returncode, 0, result.stderr)
        tags = self.calls("metaflac")[0]
        self.assertIn("--set-tag=ALBUM=An Album", tags)
        self.assertTrue((self.library / "An Artist/EP - An Album/01 - A Track.flac").exists())

    def test_final_summary_groups_releases_and_preserves_actual_errors(self):
        result = self.run_yta("-r", "page", discovery=(
            "good\tAlbum\tComplete Release\t2020\n"
            "bad\tEP\tUnavailable Release\t2021\n"
            "partial\tAlbum\tIncomplete Release\t2022\n"
            "archived\tSingle\tPrevious Release\t2023"),
            MOCK_DOWNLOAD_RESULTS=json.dumps({
                "bad": {"empty": "1", "status": 1, "stderr": "ERROR: Video is unavailable"},
                "partial": {"status": 1, "stderr": "ERROR: Track 2 is private"},
                "archived": {"empty": "1", "stderr": "[download] xyz: has already been recorded in the archive"},
            }))
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = result.stdout
        for heading in ("Successfully downloaded and saved (1)",
                        "Partial downloads saved (errors occurred) (1)", "Failed (1)",
                        "Skipped (already downloaded) (1)"):
            self.assertIn(heading, summary)
        for title in ("Complete Release", "Unavailable Release", "Incomplete Release", "Previous Release"):
            self.assertEqual(summary.count(title), 1)
        self.assertIn("ERROR: Video is unavailable", summary)
        self.assertIn("ERROR: Track 2 is private", summary)
        self.assertNotIn("01 - A Track", summary)
        self.assertEqual(len(self.calls("yt-dlp")), 4)
        self.assertEqual(len(self.calls("rsync")), 2)
        self.assertEqual(self.staged_runs(), [])

    def test_copy_failures_are_reported_after_attempting_remaining_releases(self):
        result = self.run_yta("-r", "page", discovery="one\tEP\tFirst\ntwo\tSingle\tSecond",
                              COPY_STATUS="9")
        self.assertEqual(result.returncode, 9, result.stderr)
        self.assertIn("Failed (2)", result.stdout)
        self.assertIn("EP - First", result.stdout)
        self.assertIn("Single - Second", result.stdout)
        self.assertIn("failed to move files", result.stdout)
        self.assertIn("keeping staging directory:", result.stdout)
        self.assertEqual(len(self.calls("yt-dlp")), 2)
        self.assertEqual(len(self.staged_runs()), 2)

    def test_ignored_yt_dlp_errors_are_still_reported_as_partial(self):
        result = self.run_yta("-r", "page", discovery="one\tEP\tPartial",
                              MOCK_DOWNLOAD_RESULTS=json.dumps({"one": {
                                  "status": 0, "stderr": "ERROR: One track could not be downloaded"}}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Partial downloads saved (errors occurred) (1)", result.stdout)
        self.assertIn("ERROR: One track could not be downloaded", result.stdout)

    def test_metadata_containing_failed_is_not_treated_as_an_error(self):
        result = self.run_yta("-r", "page", discovery="one\tEP\tFailed State",
                              MOCK_DOWNLOAD_RESULTS=json.dumps({"one": {
                                  "stderr": "[MetadataParser] Parsed album: Failed State"}}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Successfully downloaded and saved (1)", result.stdout)
        self.assertIn("Partial downloads saved (errors occurred) (0)", result.stdout)

    def test_chapter_processing_failure_is_reported_and_staging_is_kept(self):
        result = self.run_yta("-c", "-n", "url", FFMPEG_STATUS="3")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("Failed (1)", result.stdout)
        self.assertIn("ERROR: chapter audio decoding failed", result.stdout)
        self.assertEqual(self.calls("rsync"), [])
        self.assertEqual(len(self.staged_runs()), 1)

    def test_singles_discovery_failure_does_not_start_download_or_staging(self):
        result = self.run_yta("-s", "page", discovery="partial url", DISCOVER_STATUS="4")
        self.assertEqual(result.returncode, 4)
        self.assertEqual(self.calls("yt-dlp"), [])
        self.assertFalse((self.library / "_staging").exists())

    def test_singles_requires_one_page_argument(self):
        for args in (("--releases",), ("--singles",), ("-r", ""), ("-s", "-c"),
                     ("-r", "page", "-s", "another")):
            with self.subTest(args=args):
                result = self.run_yta(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Usage:", result.stderr)
        self.assertEqual(self.calls("yt-dlp"), [])

    def test_singles_with_chapters_and_partial_download_still_copies(self):
        result = self.run_yta(
            "-c", "-s", "page", discovery="https://music.youtube.com/browse/MPRE_single",
            DOWNLOAD_STATUS="1",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls("ffmpeg")), 1)
        self.assertEqual(self.calls("beet"), [])
        self.assertEqual(self.staged_runs(), [])

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_stow_installs_helpers_without_readme(self):
        target = self.home / "stow-target"
        target.mkdir()
        subprocess.run(
            ["stow", "--no-folding", "-d", str(ROOT), "-t", str(target), "scripts"],
            check=True, capture_output=True, text=True,
        )
        helper = target / ".local/lib/yta/functions.bash"
        self.assertTrue(helper.is_symlink())
        self.assertEqual(helper.resolve(), ROOT / "scripts/.local/lib/yta/functions.bash")
        self.assertTrue((target / ".local/lib/yta/discover_singles.py").is_symlink())
        self.assertFalse((target / "README.md").exists())


if __name__ == "__main__":
    unittest.main()
