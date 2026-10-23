# Concept C: "Jasmine Wish Star" (نجمة الفُل)

## Idea

**EN:** Four ivory jasmine petals (Arabian jasmine, or *full* فل, the flower Gulf brides wear in their hair) open in front of a gold four-point wishing star. Together the two layers make an eight-point star, a form that comes from Islamic geometric ornament. A thin gap separates the petals from the star, so the mark looks layered and crafted rather than drawn as clip-art. The message is "your wish blooms here" (منيتي means "my wish").

**AR:** أربع بتلات من الفُل، زهرة العروس الخليجية، تتفتّح أمام نجمة أمنية ذهبية. تتداخل الطبقتان فتكوّنان نجمة ثمانية مستوحاة من الزخرفة الإسلامية، ويفصل بينهما خطّ رفيع يمنح الشعار إحساس الحِرفة والفخامة. الرسالة: «أمنيتك تتفتّح هنا».

## Files

| File | What it is |
|---|---|
| `mark.svg` | The symbol alone. Square 240×240 viewBox, transparent background, burgundy petals and gold star. Pure paths: no masks and no fonts. |
| `app-icon-1024.png` | iOS App Store icon, 1024×1024. Full-bleed, square corners, RGB with no alpha channel. Ivory petals and gold star on flat burgundy. |
| `lockup-ivory.svg` / `.png` | Horizontal lockup on ivory #FAFAEC. The PNG is 1692×820 (2x). |
| `lockup-burgundy.svg` / `.png` | The reversed lockup on burgundy #8A0D3A. Ivory Arabic, gold Latin, ivory and gold mark. |
| `small-sizes.png` | The icon at 180, 87, 58, 40 and 29 px (iOS mask simulated) on white and on dark gray. |

The lockup reads right to left: the mark comes first on the right, then منيتي, with MUNYATI centred underneath.

All text in the SVGs is **converted to outlines**, so the files need no fonts. The Arabic was shaped with HarfBuzz (harfbuzzjs) and then outlined, so the joining is correct (initial م, medial ن ي ت, final ي). It matches what the browser renders.

## Fonts (both free for commercial use)

- **Arabic: Readex Pro Light (300)** by Thomas Jockin and Nadine Chahine, under the SIL Open Font License 1.1. I chose it because its diamond-shaped dots echo the pointed petals and star points of the mark.
- **Latin: Cormorant Garamond SemiBold (600)** by Christian Thalmann (Catharsis Fonts), under the SIL Open Font License 1.1. It is set in capitals with 0.30 em tracking.

Both fonts come from Google Fonts. Use the same two families in the app UI and on the website for headings, so the brand stays consistent.

## Colors

| Token | Hex | Use |
|---|---|---|
| Burgundy | `#8A0D3A` | Primary. Petals on light backgrounds, the app icon background, the reversed lockup background. |
| Gold | `#DFC389` | Accent. The wishing star and the Latin name on burgundy. Never use it for small text on ivory, because the contrast is too low. |
| Cream | `#F2E5D2` | A secondary surface, such as cards and onboarding backgrounds. It works as a background for the ivory lockup too. |
| Ivory | `#FAFAEC` | The main light background. Petals and Arabic text in the reversed versions. |

**One-color use** (embossing, foil, a single-color print or a watermark): fill both paths in `mark.svg` with the same color. The gap between petals and star keeps the shape readable in one color.

**Clear space:** keep at least the width of one petal (about 20% of the mark's width) clear on every side.

**Minimum size:** 16 px for the mark alone and 240 px wide for the full lockup. Below 240 px the tracked MUNYATI line drops under about 7 px cap height and its hairline serifs break up, so use the mark alone or the mark with منيتي only.

## Caveats and known weaknesses

- **Cross reading.** The four petals point straight up, down, left and right. Seen quickly, they can read as a plus or cross shape. The gold diagonal star turns the silhouette into an eight-point star, and the quatrefoil rosette is very common in Islamic tile work. Even so, a local reviewer should check it. If needed, a fix is to make the gold star more prominent (longer points) or to add a second ring of petals.
- **Similar marks.** Four-petal and star rosettes are a common ornamental form, so there may be similar marks in beauty, hospitality and events. A trademark search is needed before committing.
- **Off-the-shelf Arabic font.** The wordmark is the font as published, not custom lettering. For a fully ownable logotype, a lettering artist should refine it, for example by tightening the space between ي and ت, adjusting the dots, or extending the final ي into a petal.
- **Detail lost at small sizes.** At 29 to 40 px the gap between petals and star disappears and the mark becomes an eight-point burgundy, ivory and gold star. It stays recognizable but loses its layered detail.
- **Dots.** The diamond dots of Readex Pro were scaled down to 80% in the wordmark (see Review notes). A lettering artist should still give them a final optical pass.
- **Flat icon.** The icon uses flat brand burgundy with no gradient or texture, so the colors are exactly the brand colors. A very subtle radial gradient would add depth if wanted.

## Review notes (critic pass)

The reviewer checked every render: the Arabic shaping (م ن ي ت ي, initial, medial and final forms all correct), legibility at small sizes, padding, the color values (every PNG holds only the four brand hex values plus anti-aliasing), and the SVGs (valid XML, paths only, no fonts, masks, clips or external references). The reviewer changed these things:

1. **Stronger eight-point star, weaker "plus" reading.** The gold wishing star now reaches almost as far as the petals: its point radius went from 92 to 101 (petals are 102) and its waist from 28 to 30. The silhouette now reads as an even eight-point star instead of a cross of petals with gold filling the gaps. This matters most on ivory, where the low-contrast gold used to let the burgundy petals dominate. The reviewer also tried rotating the mark 45°, which put the gold star upright, and rejected it: the gold then read as a cross.
2. **Slightly wider gap** between the petals and the star (4.5 to 5 units), so the layering survives a little longer as the icon gets smaller.
3. **Larger mark in the app icon.** The mark now spans about 68% of the canvas instead of 65%, which helps at 29 to 58 px. It still sits well inside the iOS safe area (inner 80%) and clears the corner mask.
4. **Smaller Arabic dots.** The diamond dots of منيتي were scaled to 80% around their own centres. Only the dot contours changed; the joins and letter bodies are untouched. The heavy dots at display size were the most visible flaw in the wordmark.
5. **Raised the minimum lockup width** from 120 px to 240 px, because the tracked Cormorant line cannot be read at 120 px.
6. Re-rendered every PNG and saved them as RGB with no alpha. The mark and lockup SVGs were regenerated with the new geometry.

The updated generator is in `/tmp/claude-0/logo-review-c/` (`final.mjs`, `lockup.mjs` GEOM, `dots.mjs`).

**Still open:** the icon background is still flat. A Saudi reviewer should still check the cross reading, although it is much weaker now. A trademark search is still needed. The wordmark is still a stock font apart from the dots.
