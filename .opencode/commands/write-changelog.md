---
description: Generate bilingual editor-template for ./x release changelog detail
---

Generate the bilingual editor-template consumed by
`data/lib/release/changelog_gen.py:_parse_editor_output`.
Do NOT write any files — only output the text block.

User will provide a list of one-line commit messages inline. If no version is given,
default to `0.0.0`.

## Steps

1. Categorize commits into Keep-a-Changelog groups using conventional-commit prefixes:
   feat → Added | refactor,perf,style,ui,ux → Improved | fix → Fixed |
   change,revert → Changed | build,ci,chore,deps,test,docs → Architecture
2. Merge related commits into a single bullet. Prefer fewer, high-quality bullets.
   Skip merge commits and release-bump noise. Only emit categories that have content.
3. Draft an en-us body with `## Category` headings and `- bullet` lines.
   Each bullet is a single line, starts capitalized, no trailing period.
4. Translate to publication-quality zh-cn. Headings: 新增 / 改进 / 修复 / 架构.
   Keep EVE technical terms in English (Dogma, abyssal, mutaplasmid, etc.).
5. Print the result in this exact format:

```
# Write release summary for v{version}.
# Lines starting with '#' are stripped on save.
# Write English after "en-us", Chinese after "zh-cn".

en-us

{english body}

zh-cn

{chinese body}

# ---- Change log (auto-generated, reference) ----
{commit list as # comment lines}
```

The parser at `changelog_gen.py:135-157` reads everything between `en-us` and `zh-cn` as
the English body, and everything from `zh-cn` onward as the Chinese body. `#` lines are
stripped.
