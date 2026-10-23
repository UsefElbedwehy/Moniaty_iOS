# Concept A: "Khatam" (خاتم), the meem monogram

## Idea

**EN.** The mark is the letter **م**, the first letter of منيتي, drawn as a solitaire ring. The round loop of the meem is the gold band. A four-point sparkle sits on top as the stone, and its lower point passes through a cut in the band the way a set diamond sits in its prongs. The sparkle is also the *wish*, the meaning of the name. The meem's calligraphic tail runs along the baseline and drops into a tapered stroke, so the symbol still reads as an Arabic letter and not only as a picture of a ring.

**AR.** الشعار هو حرف **م**، أول حروف «منيتي»، مرسوماً على هيئة خاتم سوليتير. دائرة الميم هي حلقة الخاتم الذهبية، وفوقها نجمة رباعية تمثّل الفص. يخترق طرفها السفلي الحلقة كما يُثبَّت الألماس في مخالبه. والنجمة نفسها هي «الأمنية» التي يحملها الاسم. ويمتد ذيل الميم على السطر ثم ينزل بخط مستدق، فيبقى الرمز حرفاً عربياً مقروءاً وليس مجرد صورة خاتم.

## Files

| File | Use |
|---|---|
| `mark.svg` | The symbol alone, burgundy on a transparent background, square viewBox. It is a single outlined path. |
| `app-icon-1024.png` | iOS App Store / Xcode icon. 1024×1024, RGB with no alpha, full-bleed square with no rounded corners. |
| `app-icon.svg` | Vector source of the icon: the heavier **icon cut** of the mark (see Construction), gold, at 76% of the canvas height on flat burgundy. |
| `lockup-ivory.svg` / `.png` | Horizontal lockup on ivory: the mark on the right (where RTL reading starts), then منيتي, then MUNYATI. The PNG is rendered at 3×. |
| `lockup-burgundy.svg` / `.png` | The same lockup reversed, gold on burgundy. |
| `small-sizes.png` | The icon at 180, 87, 58, 40 and 29 px, masked like iOS, on white and on dark gray. |

Every SVG is fully outlined: there are no `<text>` elements and no font dependencies. The Arabic was shaped with HarfBuzz (harfbuzzjs) before it was outlined, so the joining in منيتي is correct.

## Fonts (all SIL Open Font License 1.1, free for commercial use)

- **Noto Kufi Arabic** (Google / Monotype), weight 330 on the variable axis. Used for منيتي. Its round, geometric meem matches the ring in the mark.
- **Marcellus** (Brian J. Bonislawsky / Astigmatic). Used for MUNYATI, set in caps with +0.42em tracking.
- The mark itself is custom geometry built in code. No font is involved.

For the app UI, Noto Kufi Arabic paired with Marcellus (headings) or a neutral Latin sans works with this lockup.

## Colors

| Token | Hex | Use |
|---|---|---|
| Burgundy | `#8A0D3A` | Primary. The icon background, the mark and text on light backgrounds. |
| Gold | `#DFC389` | Accent. The mark and wordmark on burgundy. Never put gold on ivory or cream: the contrast is too low. |
| Cream | `#F2E5D2` | Secondary surfaces and cards. A burgundy mark works on it. |
| Ivory | `#FAFAEC` | Main light background. |

Clear space: keep at least the height of the sparkle (about 20% of the mark height) free on every side. Minimum size: 16 px tall for the mark alone, and 28 px tall for the lockup.

## Construction (reproducible)

The mark is generated in code (`/tmp/claude-0/logo-work-concept-a/mark.js` with `final-params.json`):

- Ring: centerline radius 170 and stroke 52, on a 1000-unit grid.
- Tail: it leaves the ring at the bottom on the ring's own tangent and tapers from 52 to 20 units, ending in a round terminal.
- Sparkle: half-heights of 102 (vertical) and 64 (horizontal), with concave sides. It sits 64 units above the top of the ring.
- Setting: a constant 13-unit gap cuts the band around the sparkle.

All the parts are merged with boolean union into one clean path.

**Icon cut** (used only in `app-icon.svg` / `app-icon-1024.png`): ring stroke 60, tail terminal 24, sparkle half-heights 118 / 76 sitting 68 units above the ring, setting gap 16. Everything else is identical to the master mark. It is an optical-size variant: iOS shrinks the single 1024 px icon down to 29 px, so the icon needs heavier strokes than the lockup mark does.

## Caveats and weaknesses

- **Latin readers.** At a glance, a circle with a descending stem on the left can look like a Latin "p" or a Greek "ρ". Arabic readers see a meem right away. Latin readers mostly see "a ring with a star" first, which is acceptable.
- **29 px and below.** The prong gap and the hairline end of the tail disappear, and the sparkle turns into a small diamond. The icon still reads as a gold ring with a stone, but the delicate jewelry details are only visible from about 58 px up. The heavier icon cut (see Review notes) improves this, but at 29 px the stone is still only a few pixels.
- **Stroke weights.** The Noto Kufi wordmark at weight 330 is a little heavier than the hairline parts of the mark. A custom-drawn منيتي that reuses the mark's ring as the word's meem would tie the two together better and is the obvious next step.
- **Flat colors.** The icon uses the exact flat brand colors, with no gradient or foil effect. A subtle gold gradient (`#EAD6A6` → `#DFC389` → `#C8A866`) would feel more "jewelry" on the home screen, but it is left out to stay true to the palette.

## Review notes (critic pass)

What I checked: shaping and joining of منيتي (correct, HarfBuzz-shaped Noto Kufi, no breaks between letters), palette (only the four brand hex values, plus anti-aliasing), SVG validity (all four pass `xmllint`; none has `<text>`, `href` or `@font-face`, so they need no fonts), padding, and legibility at small sizes.

Changes:
1. **App icon: new heavier "icon cut", drawn larger.** The ring stroke goes from 52 to 60 and the tail terminal from 16 to 24. The sparkle is about 15% bigger (118/76), and the setting gap is 16. The mark now fills 76% of the canvas height instead of 68%; its bounding box is x 305–707 and y 123–901 on the 1024 canvas, which is inside the iOS ~80% safe area. Before, at 40 px and 29 px the ring was a hairline loop and the stone was one or two pixels. Now the ring, the stone and the tail are all still visible at 29 px. `app-icon.svg` and `app-icon-1024.png` were regenerated (RGB, no alpha, 1024×1024).
2. **Master mark: tail terminal 16 → 20 units.** At the 28 px minimum lockup size, the end of the tail was thinner than half a pixel and broke apart. `mark.svg` and both lockups were regenerated, and the lockup PNGs were re-rendered at 3×. Nothing else in the lockups changed.
3. **`small-sizes.png` rebuilt.** The 1024 icon is downscaled with Lanczos (the way iOS resamples it) and masked with a rounded rectangle at radius 22.37%, on white and on #2C2C2E.

Tried and rejected:
- **A fillet in the crotch where the tail leaves the ring** (radii 24–110). It turned the crisp calligraphic junction into a goitre-like lump, so the sharp junction stays.
- **Other Arabic wordmark fonts:** El Messiri 500/600, Alexandria 300, Reem Kufi 400 and Noto Kufi 250. El Messiri pairs nicely at small sizes, but at display size its notched teeth and flat-sided meem look clumsy next to the mark. Noto Kufi 330 is still the cleanest.

Scripts for this pass: `/tmp/claude-0/logo-work-concept-a/mark2.js`, `lock2.mjs` and `review/export2.mjs` (the master and icon parameters are in `review/params-*.json`). The `/tmp` folder is temporary, so copy these scripts into the repo if they need to be kept.
