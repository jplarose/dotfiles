"""List album, EP, and single URLs from a YouTube Music artist collection.

YouTube Music's MPAD browse pages are not album playlists. Read their WEB_REMIX
browse data directly; yt-dlp handles the individual MPRE releases afterward.
"""

import json
import re
import sys
from urllib.error import URLError
from urllib.parse import parse_qs, urlparse
from urllib.request import Request, urlopen


ORIGIN = "https://music.youtube.com"
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36"
)


def fetch(url, payload=None):
    headers = {"User-Agent": USER_AGENT, "Accept-Language": "en-US,en;q=0.9"}
    data = None
    if payload is not None:
        headers.update({"Content-Type": "application/json", "Origin": ORIGIN})
        data = json.dumps(payload).encode()
    with urlopen(Request(url, data=data, headers=headers), timeout=30) as response:
        return response.read().decode("utf-8")


def client_context(html):
    # raw_decode handles nested JSON and braces inside strings without scraping
    # unrelated links from scripts, recommendations, or the navigation menus.
    for match in re.finditer(r"ytcfg\.set\(\s*", html):
        try:
            config, _ = json.JSONDecoder().raw_decode(html, match.end())
        except ValueError:
            continue
        if isinstance(config, dict) and "INNERTUBE_CONTEXT" in config:
            context = config["INNERTUBE_CONTEXT"]
            context["client"]["hl"] = "en"
            return context
    raise ValueError("YouTube Music did not provide its client configuration")


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def release_url(renderer):
    # Release browse IDs identify albums, EPs, and singles independently of
    # translated labels. Channels and ordinary playlists are not releases.
    endpoint = renderer.get("navigationEndpoint", {}).get("browseEndpoint", {})
    browse_id = endpoint.get("browseId", "")
    if not re.fullmatch(r"MPRE[\w-]+", browse_id):
        return None
    return f"{ORIGIN}/browse/{browse_id}"


def collection_items(response):
    # Restrict traversal to collection content. Header chips carry reload
    # tokens for Albums and Singles & EPs, which are not pagination tokens.
    for key in ("contents", "continuationContents", "onResponseReceivedActions",
                "onResponseReceivedEndpoints"):
        yield from walk(response.get(key, {}))


def text_content(value):
    if isinstance(value, str):
        return value
    return value.get("simpleText") or "".join(
        run.get("text", "") for run in value.get("runs", []))


def release_metadata(renderer):
    title = text_content(renderer.get("title", {}))
    # A label may be split across runs, combined with the year in one run,
    # or supplied as simpleText. Do not infer types from the ALBUM pageType:
    # YouTube uses that pageType for singles and EPs too.
    subtitle = text_content(renderer.get("subtitle", {}))
    labels = {"album": "Album", "ep": "EP", "single": "Single"}
    kind = next((labels[part.strip().casefold()] for part in re.split(r"[•·|]", subtitle)
                 if part.strip().casefold() in labels), "")
    year = next((part.strip() for part in re.split(r"[•·|]", subtitle)
                 if re.fullmatch(r"(?:19|20)\d{2}", part.strip())), "")
    return {"title": " ".join(title.split()), "type": kind, "year": year}


def discover(page_url, request=fetch, metadata=False):
    parsed = urlparse(page_url)
    if (parsed.scheme != "https" or parsed.netloc != "music.youtube.com"
            or not re.fullmatch(r"/browse/MPAD[\w-]+/?", parsed.path)):
        raise ValueError("expected a YouTube Music release collection URL "
                         "(https://music.youtube.com/browse/MPAD...)")
    context = client_context(request(page_url))
    query = {"browseId": parsed.path.rstrip("/").split("/")[-1]}
    params = parse_qs(parsed.query).get("params")
    if params:
        query["params"] = params[0]
    pending = [query]
    seen_tokens = set()
    seen_urls = set()
    urls = []
    while pending:
        query = pending.pop(0)
        response = json.loads(request(
            f"{ORIGIN}/youtubei/v1/browse?prettyPrint=false",
            {"context": context, **query},
        ))
        if "error" in response:
            raise ValueError(f"YouTube Music browse request failed: {response['error']}")
        for item in collection_items(response):
            renderer = item.get("musicTwoRowItemRenderer")
            if renderer:
                url = release_url(renderer)
                if url and url not in seen_urls:
                    seen_urls.add(url)
                    urls.append({"url": url, **release_metadata(renderer)} if metadata else url)
            # YouTube has used both continuation containers for grid pages.
            token = item.get("nextContinuationData", {}).get("continuation")
            if not token:
                token = item.get("continuationCommand", {}).get("token")
            if token and token not in seen_tokens:
                seen_tokens.add(token)
                pending.append({"continuation": token})
    if not urls:
        raise ValueError("no releases found on this collection page; "
                         "no downloads were started")
    return urls


def main():
    args = sys.argv[1:]
    metadata = bool(args and args[0] == "--tsv")
    if metadata:
        args.pop(0)
    if len(args) != 1:
        print("Usage: discover_singles.py [--tsv] YOUTUBE_MUSIC_COLLECTION_PAGE", file=sys.stderr)
        return 2
    try:
        urls = discover(args[0], metadata=metadata)
    except (OSError, URLError, ValueError, KeyError, TypeError) as error:
        print(f"yta: release discovery failed: {error}", file=sys.stderr)
        return 1
    print(f"Found {len(urls)} releases; skipping beets import.", file=sys.stderr)
    if metadata:
        for release in urls:
            print(f"{release['url']}\t{release['type'] or '-'}\t{release['title'] or '-'}\t{release['year'] or '-'}")
    else:
        print("\n".join(urls))
    return 0


if __name__ == "__main__":
    sys.exit(main())
