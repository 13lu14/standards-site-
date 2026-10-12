from __future__ import annotations

import re
from pathlib import Path, PurePosixPath
from urllib.parse import quote, unquote, urlsplit, urlunsplit


IMG_SRC = re.compile(r"<img\b[^>]*\bsrc=(['\"])(.*?)(['\"])", re.IGNORECASE)


def _fix_url(value: str) -> str:
    split = urlsplit(value)
    path = PurePosixPath(unquote(split.path).replace("\\", "/"))

    # Files written as raw HTML keep "images/..." from their original source.
    # At the built URL, a document lives one folder deeper, so shift it back.
    if path.parts[:1] == ("images",):
        encoded_path = quote(split.path.lstrip("/"), safe="/%")
        return urlunsplit((split.scheme, split.netloc, f"../{encoded_path}", split.query, split.fragment))

    return value


def on_page_content(html: str, page, **kwargs):
    if not page.url.startswith("standards/") or page.url == "standards/":
        return html
    return IMG_SRC.sub(lambda match: match.group(0).replace(match.group(2), _fix_url(match.group(2))), html)

