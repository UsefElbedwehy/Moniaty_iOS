# Concept A: "Khatam" (خاتم), the meem monogram

## Idea

**EN.** The mark is the letter **م**, the first letter of منيتي, drawn as a solitaire ring. The round loop of the meem is the gold band. A four-point sparkle sits on top as the stone, and its lower point passes through a cut in the band the way a set diamond sits in its prongs. The sparkle is also the *wish*, the meaning of the name. The meem's calligraphic tail runs along the baseline and drops into a tapered stroke, so the symbol still reads as an Arabic letter and not only as a picture of a ring.

**AR.** الشعار هو حرف **م**، أول حروف «منيتي»، مرسوماً على هيئة خاتم سوليتير. دائرة الميم هي حلقة الخاتم الذهبية، وفوقها نجمة رباعية تمثّل الفص. يخترق طرفها السفلي الحلقة كما يُثبَّت الألماس في مخالبه. والنجمة نفسها هي «الأمنية» التي يحملها الاسم. ويمتد ذيل الميم على السطر ثم ينزل بخط مستدق، فيبقى الرمز حرفاً عربياً مقروءاً وليس مجرد صورة خاتم.

## Files

| File | Use |
|---|---|
| `mark.svg` | The symbol alone, burgundy on a transparent background, square viewBox. It is a single outlined path. |
| `app-icon-1024.png` | iOS App Store / Xcode icon. 1024×1024, RGB with no alpha, full-bleed square with no rounded corners. |
| `app-icon.svg` | Vector source of the icon: gold mark at 68% of the canvas height on flat burgundy. |
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
- Tail: it leaves the ring at the bottom on the ring's own tangent and tapers from 52 to 16 units, ending in a round terminal.
- Sparkle: half-heights of 102 (vertical) and 64 (horizontal), with concave sides. It sits 64 units above the top of the ring.
- Setting: a constant 13-unit gap cuts the band around the sparkle.

All the parts are merged with boolean union into one clean path.

## Caveats and weaknesses

- **Latin readers.** At a glance, a circle with a descending stem on the left can look like a Latin "p" or a Greek "ρ". Arabic readers see a meem right away. Latin readers mostly see "a ring with a star" first, which is acceptable.
- **29 px and below.** The prong gap and the hairline end of the tail disappear, and the sparkle turns into a small diamond. The icon still reads as a gold ring with a stone, but the delicate jewelry details are only visible from about 58 px up. If testing shows it is needed, a slightly heavier small-size cut (ring stroke about 60) could be made for the 40 px and 29 px slots.
- **Stroke weights.** The Noto Kufi wordmark at weight 330 is a little heavier than the hairline parts of the mark. A custom-drawn منيتي that reuses the mark's ring as the word's meem would tie the two together better and is the obvious next step.
- **Flat colors.** The icon uses the exact flat brand colors, with no gradient or foil effect. A subtle gold gradient (`#EAD6A6` → `#DFC389` → `#C8A866`) would feel more "jewelry" on the home screen, but it is left out to stay true to the palette.
