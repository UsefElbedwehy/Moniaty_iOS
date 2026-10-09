# Concept B: "Nuqta & Wish" (calligraphic wordmark)

## Idea

**EN:** The logo is the name itself, منيتي ("my wish"), set as a Naskh calligraphic wordmark. In calligraphy each dot (nuqta) is drawn as a small rhombus, so here every nuqta is cut as a small diamond, like a gem. The dot of the ن becomes a gold four-point star, the "wish". The last stroke of the final ي continues as a fine swash that rises over the word to that star, like a wish travelling to its star.

**AR:** الشعار هو الاسم نفسه "منيتي" مكتوبًا بخط النسخ. في الخط العربي تُرسم النقطة على شكل معيّن، فحوّلنا كل النقاط إلى ماسات صغيرة. نقطة النون صارت نجمة ذهبية تمثّل "الأمنية". وامتدّ آخر حرف الياء في ضربة رفيعة تصعد فوق الكلمة حتى تصل إلى النجمة، كأن الأمنية تسير نحو نجمتها.

## Files

| File | What it is |
|---|---|
| `mark.svg` | The symbol on its own: the full calligraphic word with swash and star, square viewBox, transparent background. Letters and nuqat are burgundy and the star is gold. |
| `mark-reversed.svg` | The same mark for dark or burgundy backgrounds: ivory letters with gold nuqat and star. |
| `app-icon-1024.png` | iOS app icon at 1024×1024. RGB with no alpha channel, full-bleed square, no rounded corners. |
| `app-icon.svg` | Vector source of the app icon. |
| `lockup-ivory.svg` / `.png` | Horizontal lockup on ivory: MUNYATI, a gold hairline rule, then منيتي (Arabic on the right). PNG is 2403×849. |
| `lockup-burgundy.svg` / `.png` | The reversed lockup on burgundy: ivory Arabic, gold Latin, gold rule and gold nuqat. |
| `small-sizes.png` | The icon at 180, 87, 58, 40 and 29 px, shown at 1:1 with a simulated iOS corner mask, on white and on #2C2C2E. |

All SVGs are pure outlines with no `<text>` and no font dependency. The Arabic was shaped with HarfBuzz (harfbuzzjs), so letters join exactly as a browser renders the font; this was checked side by side against Chrome. The glyph outlines were then edited:

- the font's dots were removed and replaced with drawn diamonds;
- the ن dot was replaced with the star;
- the hook at the end of the final ي was cut off, and the swash was merged into the same contour so there is no seam.

## Fonts and licences (all free for commercial use)

- **Amiri Bold** by Khaled Hosny: SIL Open Font License 1.1. It is the base for the Arabic letterforms, using the كشيدة form منيتـي.
- **Cormorant Garamond SemiBold (600)** by Christian Thalmann / Catharsis Fonts: SIL OFL 1.1. Used for MUNYATI in capitals, tracked +300/1000 (0.3 em).

The text has been converted to outlines, so no font files have to ship with the logo. Under the OFL, the logo artwork can be trademarked.

## Colour use

| Token | Hex | Use |
|---|---|---|
| Burgundy | `#8A0D3A` | Primary. Letters on light grounds; background of the icon and the reversed lockup. |
| Gold | `#DFC389` | Accent. The star always; nuqat and Latin on burgundy; the divider rule. |
| Ivory | `#FAFAEC` | Light background; letters on burgundy. |
| Cream | `#F2E5D2` | Secondary light background; works in place of ivory under the burgundy version. |

Rules:

- On light backgrounds the nuqat stay burgundy, because gold on ivory has only about 1.6:1 contrast and the dots are needed to read the word. Only the star is gold there, as an accent.
- For single-colour use (emboss, stamp, fax), make the star the same colour as the letters.

## Caveats and known weaknesses

- **29 px:** below about 40 px the icon shows the word's outline rather than readable letters (29 and 40 px are legacy 1x sizes only; on current iPhones the smallest icon is 58 px, where it reads). The ي bowl, the م loop and a gold glint are still there, but the swash hairline and the diamond pairs merge. It reads clearly at 40 px and above. If you want a sharper Settings-size icon, a separate small icon could drop the swash and enlarge the word.
- **Base font:** the letterforms are Amiri, a well-known book typeface. The diamonds, star and swash make it unique, but Arabic type designers may recognise the base. For a fully custom mark, a calligrapher could redraw it using these files as the brief.
- **Height:** the swash makes the wordmark tall, so the horizontal lockup has generous space above the Latin. In very wide, short spaces (navigation bars) use the Arabic word alone.
- **Hairline at small sizes:** the swash thins to a hairline near the star and will drop out in very small print (under about 15 mm wide). The icon uses a slightly heavier hairline.
- **Crescent and star:** the curved swash next to a star can be read as a crescent-and-star motif. The arc is open and runs into the star, so it reads as a shooting star, but it is worth checking with the client.
- **Gold on ivory:** the star is soft on ivory (low contrast). This is intentional, but it may look pale in some print processes. Specify a metallic gold foil for print.

## Review notes

A design review checked these assets: shaping against Chrome's Amiri rendering, renders at all sizes, palette pixels, and SVG validity. The Arabic shaping is correct and matches the browser glyph for glyph, so the letters were not changed. These changes were made:

1. **Swash end cap:** the swash ended in a flat, blunt cut next to the star, which was most visible on the app icon. It now ends in a round, pen-like cap in all files. It is also slightly heavier near the tip: 10 units for the mark and lockups, 22 for the icon. This keeps the tip from breaking up in small print.
2. **App icon padding:** the artwork was 86% of the icon width, which left only about 6% margin at the ي bowl. It looked cramped against the iOS corner mask. It now takes 81%, so each side has about 100 px of margin at 1024. Diamonds and star are enlarged slightly (dotScale 0.98, starR 1.10) and the swash tapers less, so the icon keeps its legibility at 58 to 87 px.
3. **Lockup alignment:** MUNYATI was centred on the full height of the Arabic, including the swash. That put it visibly high, with a dead band under it. It now sits on the Arabic baseline, so its cap height lines up with the short teeth. The gold rule is centred on the Latin.
4. **Re-rendered PNGs:** the PNGs were re-rendered from the new SVGs. `app-icon-1024.png` is RGB with no alpha and only the three palette colours plus anti-aliasing. The `small-sizes.png` caption now notes that 29 and 40 px are legacy 1x sizes.
5. **Checks:** all SVGs pass xmllint, contain no `<text>`, `href` or `@font-face`, and are fully self-contained outlines.

Build script: `/tmp/claude-0/logo-work-b/build2.mjs <outdir> 0.81 baseline`. It uses the `roundCap` option added in `logo.mjs`.
