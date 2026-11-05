"""Check Music collection discovery with offline browse responses."""

import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import Mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/.local/lib/yta/discover_singles.py"
spec = importlib.util.spec_from_file_location("discover_singles", SCRIPT)
singles = importlib.util.module_from_spec(spec)
spec.loader.exec_module(singles)
PAGE = "https://music.youtube.com/browse/MPADartist"
HTML = '''<script>ytcfg.set({"INNERTUBE_CONTEXT": {
    "client": {"clientName": "WEB_REMIX", "clientVersion": "current", "hl": "fr"}
}});</script>'''


def release(browse_id, kind="Single"):
    return {"musicTwoRowItemRenderer": {
        "subtitle": {"runs": [{"text": kind}, {"text": " • "}, {"text": "2026"}]},
        "navigationEndpoint": {"browseEndpoint": {"browseId": browse_id}},
    }}


def grid(items, token=None):
    content = {"items": items}
    if token:
        content["continuations"] = [{"nextContinuationData": {"continuation": token}}]
    return {"contents": {"gridRenderer": content}}


class SinglesDiscoveryTests(unittest.TestCase):
    def test_release_labels_support_combined_split_and_simple_text(self):
        for subtitle, expected in (
            ({"runs": [{"text": "Single • 2026"}]}, "Single"),
            ({"runs": [{"text": "E"}, {"text": "P • 2026"}]}, "EP"),
            ({"simpleText": " album  • 2026"}, "Album"),
            ({"runs": [{"text": "2026 • EP"}]}, "EP"),
            ({"simpleText": "2026"}, ""),
        ):
            with self.subTest(subtitle=subtitle):
                renderer = release("MPRE_one")["musicTwoRowItemRenderer"]
                renderer["subtitle"] = subtitle
                renderer["title"] = {"simpleText": "A Title"}
                self.assertEqual(singles.release_metadata(renderer),
                                 {"title": "A Title", "type": expected,
                                  "year": "2026" if "2026" in singles.text_content(subtitle) else ""})

    def test_metadata_preserves_titles_and_types_without_guessing(self):
        items = [release("MPRE_album", "Album"), release("MPRE_ep", "EP"),
                 release("MPRE_single", "Single"), release("MPRE_unknown", "Other")]
        for item in items:
            item["musicTwoRowItemRenderer"]["title"] = {
                "runs": [{"text": "100% Love\t"}, {"text": "Song\nTitle"}]}
        request = Mock(side_effect=[HTML, json.dumps(grid(items))])
        records = singles.discover(PAGE, request, metadata=True)
        self.assertEqual([record["type"] for record in records], ["Album", "EP", "Single", ""])
        self.assertEqual({record["title"] for record in records}, {"100% Love Song Title"})
        self.assertEqual({record["year"] for record in records}, {"2026"})
        self.assertTrue(records[0]["url"].endswith("MPRE_album"))

    def test_all_release_types_are_selected_and_duplicates_are_removed(self):
        response = grid([
            release("MPRE_one"), release("MPRE_ep", "EP"),
            release("MPRE_album", "Album"), release("MPRE_one"),
            release("MPRE_two"), release("UCchannel"),
        ])
        request = Mock(side_effect=[HTML, json.dumps(response)])
        self.assertEqual(singles.discover(PAGE, request), [
            "https://music.youtube.com/browse/MPRE_one",
            "https://music.youtube.com/browse/MPRE_ep",
            "https://music.youtube.com/browse/MPRE_album",
            "https://music.youtube.com/browse/MPRE_two",
        ])
        context = request.call_args.args[1]["context"]
        self.assertEqual(context["client"]["hl"], "en")
        self.assertEqual(context["client"]["clientVersion"], "current")

    def test_continuations_enumerate_beyond_first_page_and_ignore_header_filters(self):
        first = grid([release(f"MPRE_{i}") for i in range(100)], "next-page")
        first["header"] = {"nextContinuationData": {"continuation": "not-pagination"}}
        second = {"continuationContents": {"gridContinuation": {
            "items": [release("MPRE_99"), release("MPRE_100", "EP")],
            "continuations": [{"nextContinuationData": {"continuation": "last-page"}}],
        }}}
        third = {"onResponseReceivedActions": [{"appendContinuationItemsAction": {
            "continuationItems": [release("MPRE_101", "Album")],
        }}]}
        request = Mock(side_effect=[HTML, *map(json.dumps, (first, second, third))])
        urls = singles.discover(PAGE, request)
        self.assertEqual(len(urls), 102)
        self.assertTrue(urls[-1].endswith("MPRE_101"))
        self.assertEqual(request.call_args_list[2].args[1]["continuation"], "next-page")
        self.assertEqual(request.call_args_list[3].args[1]["continuation"], "last-page")

    def test_continuation_command_and_repeated_token_do_not_loop(self):
        response = grid([release("MPRE_one"), {"continuationItemRenderer": {
            "continuationEndpoint": {"continuationCommand": {"token": "same-token"}},
        }}])
        request = Mock(side_effect=[HTML, json.dumps(response), json.dumps(response)])
        self.assertEqual(len(singles.discover(PAGE, request)), 1)
        self.assertEqual(request.call_count, 3)

    def test_no_releases_is_an_error(self):
        request = Mock(side_effect=[HTML, json.dumps(grid([release("UCchannel")]))])
        with self.assertRaisesRegex(ValueError, "no releases found"):
            singles.discover(PAGE, request)

    def test_albums_only_collection_queues_every_album(self):
        response = grid([release("MPRE_album1", "Album"), release("MPRE_album2", "Album")])
        request = Mock(side_effect=[HTML, json.dumps(response)])
        self.assertEqual(singles.discover(PAGE, request), [
            "https://music.youtube.com/browse/MPRE_album1",
            "https://music.youtube.com/browse/MPRE_album2",
        ])

    def test_release_labels_are_not_required_or_language_dependent(self):
        translated = release("MPRE_translated", "Álbum")
        unlabeled = release("MPRE_unlabeled")
        del unlabeled["musicTwoRowItemRenderer"]["subtitle"]
        request = Mock(side_effect=[HTML, json.dumps(grid([translated, unlabeled]))])
        self.assertEqual(len(singles.discover(PAGE, request)), 2)

    def test_collection_filter_in_url_is_passed_to_browse_request(self):
        request = Mock(side_effect=[HTML, json.dumps(grid([release("MPRE_album", "Album")]))])
        singles.discover(PAGE + "?params=album%2Bfilter%3D&other=ignored", request)
        self.assertEqual(request.call_args.args[1]["params"], "album+filter=")

    def test_failed_pagination_does_not_return_partial_collection(self):
        request = Mock(side_effect=[HTML, json.dumps(grid([release("MPRE_one")], "next")),
                                   OSError("connection lost")])
        with self.assertRaisesRegex(OSError, "connection lost"):
            singles.discover(PAGE, request)

    def test_unsupported_pages_are_rejected_before_network_access(self):
        for page in ("https://music.youtube.com/browse/MPRE_album",
                     "https://www.youtube.com/@artist", "https://example.test/browse/MPADartist",
                     "https://music.youtube.com.evil.test/browse/MPADartist"):
            with self.subTest(page=page):
                request = Mock()
                with self.assertRaisesRegex(ValueError, "expected a YouTube Music"):
                    singles.discover(page, request)
                request.assert_not_called()

    def test_missing_client_configuration_is_actionable(self):
        with self.assertRaisesRegex(ValueError, "client configuration"):
            singles.discover(PAGE, Mock(return_value="<html>consent required</html>"))

    def test_browse_api_error_is_reported(self):
        request = Mock(side_effect=[HTML, json.dumps({"error": {"message": "unavailable"}})])
        with self.assertRaisesRegex(ValueError, "unavailable"):
            singles.discover(PAGE, request)


if __name__ == "__main__":
    unittest.main()
