# -*- coding: utf-8 -*-
"""将已有讲义从「课程作业向」收成「知识讲解向」。"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent

SKIP_SECTION_TITLES = {
    "练习",
    "检查清单",
    "练习（本项目本体）",
    "自测清单（交作业级）",
    "扩展题目（学有余力）",
    "成品规格（验收标准）",
    "里程碑（按顺序做）",
    "30 分钟搭景练习流程",
}


def strip_unwanted_sections(md: str) -> str:
    lines = md.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^(#{2,})\s+(.+?)\s*$", line)
        if m:
            title = m.group(2).strip()
            # 练习 / 检查清单 等整节删除
            if title in SKIP_SECTION_TITLES or title.startswith("练习"):
                level = len(m.group(1))
                i += 1
                while i < len(lines):
                    m2 = re.match(r"^(#{1,6})\s+", lines[i])
                    if m2 and len(m2.group(1)) <= level:
                        break
                    i += 1
                continue
            if title == "学习目标":
                out.append("## 本节要点\n")
                i += 1
                # 跳过空行
                while i < len(lines) and lines[i].strip() == "":
                    out.append(lines[i])
                    i += 1
                # 改写引导句
                if i < len(lines) and ("学完本节" in lines[i] or "做完本小项目" in lines[i]):
                    out.append("本节聚焦：\n")
                    i += 1
                    if i < len(lines) and lines[i].strip() == "":
                        out.append(lines[i])
                        i += 1
                continue
            if title == "下一步":
                out.append("## 相关章节\n")
                i += 1
                continue
        out.append(line)
        i += 1
    text = "".join(out)
    # 压缩过多空行
    text = re.sub(r"\n{4,}", "\n\n\n", text)
    return text


def main() -> None:
    for path in sorted(ROOT.glob("P*.md")):
        raw = path.read_text(encoding="utf-8")
        new = strip_unwanted_sections(raw)
        if new != raw:
            path.write_text(new, encoding="utf-8")
            print(f"updated {path.name}")
        else:
            print(f"unchanged {path.name}")


if __name__ == "__main__":
    main()
