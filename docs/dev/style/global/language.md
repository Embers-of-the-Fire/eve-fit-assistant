# Lingual design (zh / en)

The product is **bilingual Chinese–English**; both languages are first-class everywhere
user-facing text appears.

- **Equal quality, not translation afterthought.** Chinese copy is written natively, not
  transliterated. Tone stays equivalent: where English is crisp and technical, Chinese is
  简洁、专业 (e.g. "Fit Smarter, Fly Better" ↔ "更智能的装配，更好的飞行").
- **Keep brand and technical loanwords stable.** Product names (EVE Fit Assistant / EFA),
  technology names (Flutter, Rust), and established game terms stay in their canonical
  form in both languages; do not invent Chinese renderings for them.
- **Punctuation follows the language.** Chinese text uses full-width punctuation
  (，。；：、——) and no spaces between CJK characters; English uses standard ASCII
  punctuation. Em-dashes separating clauses in English become — or 、 in Chinese as fits
  the sentence.
- **Layout tolerance.** Chinese text is denser and shorter; English text wraps longer.
  Layouts must accommodate both without truncation or overflow — never size containers to
  fit only one language.
- **One string, one key.** All user-facing strings go through the localization system of
  the relevant platform; no hardcoded user-facing copy in either language. (Exception
  noted in AGENTS.md: developer-mode-only UI in the app uses hardcoded English.)
