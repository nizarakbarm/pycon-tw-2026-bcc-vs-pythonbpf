---
# Export entry. The addon's code-server keeps a socket open and `slidev export`
# waits for networkidle, which then never arrives (14 s becomes 250 s or a
# timeout), so this entry deliberately omits the livecode addon. That means the
# two <Editor /> slides cannot resolve here: their component comes from the
# addon. So this entry imports slides.md in two ranges, skipping slide 9
# (`From BCC C-String to Python-BPF`) and slide 13 (`How we run one arm`).
# `slidev dev slides.md` is the presentation entry and keeps both.
#
# `src:` is read from SLIDE frontmatter (see @slidev/parser fs.mjs:81), and a
# `#N-M` suffix selects a slide range.
theme: slidev-theme-nord
layout: center
class: text-center
title: 'Python eBPF: BCC C-String Runtime vs Python-BPF AST AOT'
colorSchema: dark
highlighter: shiki
shikiOptions:
  theme: nord
---

---
src: ./slides.md#1-8
---

---
src: ./slides.md#10-12
---

---
src: ./slides.md#14-32
---
