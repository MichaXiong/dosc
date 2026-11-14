# -*- coding: utf-8 -*-
"""扫描 unity-content/P*.md，生成 topics-data.js 供 HTML 读取。

用法（仓库根目录）:
  python unity_dosc/unity-content/_sync_topics.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "topics-data.js"
TITLE_RE = re.compile(r"^#\s+(?:P[\d.]+\s+)?(.+)$", re.M)
ID_RE = re.compile(r"^P\d+\.\d+$")


def phase_of(tid: str) -> int:
    return int(tid.split(".")[0][1:])


def extract_title(tid: str, md: str) -> str:
    m = TITLE_RE.search(md)
    if not m:
        return tid
    title = m.group(1).strip()
    return re.sub(rf"^{re.escape(tid)}\s+", "", title)


def sort_key(path: Path) -> list[int]:
    return [int(x) for x in path.stem[1:].split(".")]


def main() -> None:
    data: dict[str, dict] = {}
    for path in sorted(ROOT.glob("P*.md"), key=sort_key):
        tid = path.stem
        if not ID_RE.match(tid):
            continue
        md = path.read_text(encoding="utf-8").rstrip() + "\n"
        data[tid] = {
            "title": extract_title(tid, md),
            "phase": phase_of(tid),
            "md": md,
        }

    # JSON 与 JS 对象字面量兼容（无双引号键）
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    text = (
        "/** 由 _sync_topics.py 根据 P*.md 自动生成，请勿手改正文。 */\n"
        f"window.UNITY_TOPICS = {payload};\n"
    )
    # 带 BOM，避免中文 Windows 下 file:// 打开时把 JS 误判为系统编码导致乱码
    OUT.write_text(text, encoding="utf-8-sig")
    ids = ", ".join(data) or "(none)"
    print(f"wrote {OUT.name}: {len(data)} topic(s) -> {ids}")


if __name__ == "__main__":
    main()
