---
name: "pdf"
description: "Use automatically for PDF tasks, including Chinese requests like 查看PDF, 读取PDF, PDF里写了什么, 总结PDF, 分析PDF, 提取PDF文字, 识别PDF内容, or questions about any .pdf file. Prefer text extraction with pdfplumber/pypdf first, then render pages with Poppler when layout, images, tables, stamps, watermarks, or scanned content matter."
---


# PDF Skill

## When to use
- Automatically use this skill whenever the user asks about a `.pdf` file.
- 中文触发词包括：查看PDF、读取PDF、PDF写了什么、这个文件中写了什么、总结PDF、分析PDF、提取PDF文字、识别PDF内容。
- Read or review PDF content where layout and visuals matter.
- Create PDFs programmatically with reliable formatting.
- Validate final rendering before delivery.

## Workflow
1. Locate the referenced PDF in the current workspace before answering.
2. Use `uv run --with pdfplumber --with pypdf python <script.py>` for text extraction and metadata/page counts. Do not ask the user to install Git Bash first.
3. If extracted text is empty, sparse, garbled, or the user asks about layout/visual content, render pages to PNG and inspect them.
   - Use `pdftoppm` if available.
   - If Poppler is unavailable, clearly say visual rendering is unavailable and ask for Poppler or an image/screenshot when needed.
4. For Chinese PDFs, preserve Chinese text and answer in Chinese unless the user asks otherwise.
5. Use `reportlab` to generate PDFs when creating new documents.
6. After each meaningful PDF edit, re-render pages and verify alignment, spacing, and legibility.

## Temp and output conventions
- Use `tmp/pdfs/` for intermediate files; delete when done.
- Write final artifacts under `output/pdf/` when working in this repo.
- Keep filenames stable and descriptive.

## Dependencies (install if missing)
Prefer `uv` for dependency management.

Python packages:
```
uv run --with reportlab --with pdfplumber --with pypdf python your_script.py
```
If `uv` is unavailable:
```
python3 -m pip install reportlab pdfplumber pypdf
```
On Windows, if `python3` is unavailable but `uv` exists, use `uv run` instead of asking the user to install Python manually.
System tools (for rendering):
```
# macOS (Homebrew)
brew install poppler

# Ubuntu/Debian
sudo apt-get install -y poppler-utils
```

If installation isn't possible in this environment, tell the user which dependency is missing and how to install it locally.

## Environment
No required environment variables.

## Rendering command
```
pdftoppm -png $INPUT_PDF $OUTPUT_PREFIX
```

## Quality expectations
- Maintain polished visual design: consistent typography, spacing, margins, and section hierarchy.
- Avoid rendering issues: clipped text, overlapping elements, broken tables, black squares, or unreadable glyphs.
- Charts, tables, and images must be sharp, aligned, and clearly labeled.
- Use ASCII hyphens only. Avoid U+2011 (non-breaking hyphen) and other Unicode dashes.
- Citations and references must be human-readable; never leave tool tokens or placeholder strings.

## Final checks
- Do not deliver until the latest PNG inspection shows zero visual or formatting defects.
- Confirm headers/footers, page numbering, and section transitions look polished.
- Keep intermediate files organized or remove them after final approval.
