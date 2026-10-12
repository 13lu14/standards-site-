from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "standards"
OUTPUT = DOCS / "index.md"

CATEGORIES = [
    ("公路工程标准", "JTG"),
    ("水运工程标准", "JTS"),
    ("计量检定规程", "JJG"),
    ("交通运输行业标准", "JT"),
    ("地方与工程建设标准", None),
    ("企业温室气体核算指南", "CETS"),
    ("其他文件", None),
]


def compact_code(value: str) -> str:
    return re.sub(r"[\s／/_\-—–．.]+", "", value.upper())


def classify(title: str) -> str:
    first_token = title.split()[0] if title.split() else title
    code = compact_code(first_token)
    if code.startswith("JTG"):
        return "公路工程标准"
    if code.startswith("JTS"):
        return "水运工程标准"
    if code.startswith("JJG"):
        return "计量检定规程"
    if code.startswith("JT"):
        return "交通运输行业标准"
    if code.startswith(("DGTJ", "DGTJ08", "JGJ")):
        return "地方与工程建设标准"
    if code.startswith("CETS"):
        return "企业温室气体核算指南"
    return "其他文件"


def document_url(path: Path) -> str:
    return f"{quote(path.stem, safe='')}/"


def main() -> None:
    documents = sorted(DOCS.glob("*.md"), key=lambda path: path.stem)
    grouped: dict[str, list[Path]] = {
        name: [] for name, _ in CATEGORIES
    }

    for document in documents:
        grouped[classify(document.stem)].append(document)

    lines = [
        "---",
        "title: 全部规范",
        "---",
        "",
        "# 全部规范",
        "",
        f"当前共收录 {len(documents)} 份规范。点击名称即可打开对应文档。",
        "",
    ]

    for category, _ in CATEGORIES:
        items = grouped[category]
        if not items:
            continue
        lines.extend([f"## {category}", ""])
        for item in items:
            lines.append(f"- [{item.stem}]({document_url(item)})")
        lines.append("")

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {OUTPUT} with {len(documents)} documents.")


if __name__ == "__main__":
    main()

