"""Run the generated metadata rules through yt-dlp without network or audio."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(importlib.util.find_spec("yt_dlp"), "yt-dlp Python module is not installed")
class MetadataTests(unittest.TestCase):
    def metadata(self, info, title="", kind="", chapters=False, pipeline=False, legacy=False, year=""):
        import yt_dlp
        from yt_dlp.postprocessor.metadataparser import MetadataParserPP

        script = '''source "$1"
            split_chapters="$2"
            yta_release_title="$3"
            yta_release_type="$4"
            yta_release_year="$6"
            _yta_download() {
                shift
                python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "$@"
            }
            yta_process_chapters() { :; }
            if [[ "$5" == true ]]; then
                yta_download_tracks /tmp/yta-metadata-test
            else
                yta_download_and_process /tmp/yta-metadata-test
            fi
        '''
        result = subprocess.run(
            ["bash", "--noprofile", "--norc", "-c", script, "test",
             str(ROOT / "scripts/.local/lib/yta/functions.bash"),
             str(chapters).lower(), title, kind, str(legacy).lower(), year],
            capture_output=True, text=True, check=True,
        )
        args = json.loads(result.stdout)
        if pipeline:
            info = {"id": "offline", "url": "https://example.invalid/audio.webm",
                    "ext": "webm", "extractor": "generic", "extractor_key": "Generic",
                    **info}
            with tempfile.TemporaryDirectory() as tmp:
                fixture = Path(tmp) / "info.json"
                fixture.write_text(json.dumps(info))
                result = subprocess.run(
                    [sys.executable, "-m", "yt_dlp", "--ignore-config", *args,
                     "--simulate", "--load-info-json", str(fixture), "--print", "%()j"],
                    capture_output=True, text=True, check=True)
            processed = json.loads(result.stdout)
            return processed, processed["_filename"]
        opts = yt_dlp.parse_options(["--ignore-config", *args]).ydl_opts
        with yt_dlp.YoutubeDL({"quiet": True}) as downloader:
            for processor in opts["postprocessors"]:
                if processor["key"] == "MetadataParser":
                    MetadataParserPP(downloader, processor["actions"]).run(info)
            template = args[args.index("-o") + (3 if chapters else 1)]
            if chapters:
                template = template.removeprefix("chapter:")
            filename = downloader.evaluate_outtmpl(template, info)
        return info, filename

    def test_collection_overrides_generic_playlist_type_and_title(self):
        for kind in ("Album", "EP", "Single"):
            with self.subTest(kind=kind):
                info, filename = self.metadata(
                    {"title": "Song", "playlist_title": "Album - Wrong"},
                    "100% Love: %(title)s", kind)
                self.assertEqual(info["meta_album"], "100% Love: %(title)s")
                self.assertIn(f"/{kind} - 100% Love: %(title)s/", filename)

    def test_direct_urls_prefer_album_metadata_and_normalize_type(self):
        info, filename = self.metadata({"title": "Song", "album": "Real Title",
                                        "album_type": "ep", "playlist_title": "Album - Wrong"})
        self.assertEqual(info["meta_album"], "Real Title")
        self.assertIn("/EP - Real Title/", filename)

    def test_collection_release_year_overrides_upload_date_tag(self):
        info, _ = self.metadata({"title": "Song", "upload_date": "20250101"},
                                "Release", "EP", pipeline=True, year="2020")
        self.assertEqual(info["meta_date"], "2020")

    def test_collection_title_backslashes_and_plain_words_are_literal(self):
        for title in (r"Love \1: 100%", "Single"):
            with self.subTest(title=title):
                info, _ = self.metadata({"title": "Song"}, title, "Single")
                self.assertEqual(info["meta_album"], title)

    def test_missing_type_removes_generic_playlist_prefix_without_guessing(self):
        info, filename = self.metadata({"title": "Song", "playlist_title": "Album - My Single"})
        self.assertEqual(info["meta_album"], "My Single")
        self.assertIn("/NA - My Single/", filename)
        self.assertNotIn("/Album - ", filename)

    def test_unknown_type_and_missing_album_fall_back_to_video_title(self):
        info, filename = self.metadata({"title": "A Video", "album_type": "unknown"})
        self.assertEqual(info["meta_album"], "A Video")
        self.assertIn("/NA - A Video/", filename)

    def test_actual_cli_pipeline_with_old_and_current_callers(self):
        for legacy in (False, True):
            for kind in ("Album", "EP", "Single", ""):
                with self.subTest(legacy=legacy, kind=kind):
                    info, filename = self.metadata(
                        {"title": "Song", "playlist_title": "Album - Generic"},
                        "Real Title", kind, pipeline=True, legacy=legacy)
                    self.assertEqual(info["meta_album"], "Real Title")
                    self.assertIn(f"/{kind or 'NA'} - Real Title/", filename)

    def test_legacy_caller_without_discovery_metadata_keeps_titles_separate(self):
        paths = []
        for title in ("First", "Second"):
            info, filename = self.metadata(
                {"title": "Song", "playlist_title": f"Album - {title}"},
                pipeline=True, legacy=True)
            self.assertEqual(info["meta_album"], title)
            self.assertIn(f"/NA - {title}/", filename)
            paths.append(str(Path(filename).parent))
        self.assertNotEqual(*paths)

    def test_chapters_use_collection_title_and_type(self):
        info, filename = self.metadata({"title": "Video", "section_number": 1,
                                        "section_title": "Intro"}, "My Release", "EP", True)
        self.assertEqual(info["yta_album"], "My Release")
        self.assertIn("/EP - My Release/01 - Intro.", filename)


if __name__ == "__main__":
    unittest.main()
