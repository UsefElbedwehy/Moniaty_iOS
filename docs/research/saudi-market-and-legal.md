# Munyati (منيتي): Saudi wedding-services market, cities, manual payments, legal context and brand

Research date: 2026-10-09. Method: WebSearch only. **WebFetch failed for every site tried** (DNS errors for apps.apple.com, frhsa.com, afrah-ksa.com and help.salla.sa), so no competitor store page or website could be opened directly. Everything below comes from search-result summaries, and each claim cites its URL. Prices in particular come from vendor listings, blogs and press reports of mixed age. Treat them as **seed hints** for the budget feature, not as market truth.

---

## 0. Summary

| Topic | Recommendation |
|---|---|
| Categories | Seed **14 launch categories** (§1.2), with ~10 more switched off in the dashboard. Give each category two flags: `allows_parallel_bookings`, which exempts goods-type categories from rule #20, and `is_store_category`, which links it to rule #14. |
| Budget (#13) | Filter on **each provider's own "starting from" price**. The SAR ranges below are not reliable enough to filter on and are only good as UI hints, such as "typical: 350–3,000". Deduct from the budget only when a booking is **approved or paid**, not when it is requested. |
| Competitors | No dominant Saudi bridal-booking app turned up. The real incumbent is **Instagram, Snapchat and WhatsApp**. The nearest apps are Zafaf.net (a directory), Afrah and Farha (halls, kosha and photography), Megavents (venues), مناسبتي (beauty and events) and Fresha (salons). |
| Cities | "Damam - Khaibar - Tafeef" most likely means the **Eastern Province cluster الدمام / الخبر / القطيف (Dammam / Khobar / Qatif)**. The literal reading, Dammam / Khaybar / Taif, gives three cities in three different regions about 1,000 km apart. **Ask the owner before seeding.** Cities are dynamic (#17), so a wrong guess is cheap to fix, but it would also go into the marketing copy and the ASO keywords. |
| Payments | Support these method types: `iban` (SA + 22 digits, mod-97 check), `sarie_alias` (mobile number or national ID through the instant-payments system "سريع") and `wallet` (STC Bank / urpay / other, keyed by mobile number). Require the account-holder name. Put a **booking reference code** in the transfer note. Hash every receipt image. **Freeze payment-method edits** while a payment is pending. |
| Legal | Munyati needs its own **CR** and **e-store verification on the Business Platform (business.sa)**, which replaced Maroof. It must also publish the E-Commerce Law Art. 6/7 disclosures and a PDPL privacy policy. Show a "موثّق" badge on providers who give a **CR or freelance-document (وثيقة العمل الحر) number**. Collect the number at onboarding, but don't make it a hard gate for the MVP (§5.3). |
| Brand | Use **"Munyati"** everywhere. It matches munyati.co and contact@munyati.co. Retire "Moniaty". Suggested subtitle: **«كل تجهيزات العروس في مكان واحد»** (30 characters, AR) / **"Bridal services, booked easily"** (30 characters, EN). |

---

## 1. Category seed list (bilingual) with price hints

### 1.1 Price evidence found (SAR)

| Category | Price evidence | Source and caveat |
|---|---|---|
| Bridal makeup | Wedding-day application listed at **SAR 100 to 1,300** on a Riyadh booking platform. One Riyadh home-makeup listing at **SAR 999** for 1.5 h. | [Fresha Riyadh bridal makeup](https://www.fresha.com/lp/en/tt/bridal-makeup/in/sa-riyadh-riyadh), [Fresha Riyadh makeup](https://www.fresha.com/lp/en/tt/makeup-artists/in/sa-riyadh-riyadh) (live listings, Riyadh) |
| Bridal makeup | Riyadh salons on Zafaf from **SAR 350**. A "silver" bride package at **SAR 2,000** covers makeup, hair, body makeup, nails and lashes. | [Zafaf.net Riyadh salon prices](https://saudi-arabia.zafaf.net/hair-make-up/ideas/prices-of-workshops-riyadh-1574) (age unknown) |
| Bridal makeup | An artist quoted an average of **~SAR 1,500**. Celebrity artists charge **15,000–20,000**, sometimes up to 30,000. | [Al-Watan](https://www.alwatan.com.sa/article/1097138), [Al-Muwaten 2023](https://www.almowaten.net/2023/10/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D9%85%D9%83%D9%8A%D8%A7%D8%AC-%D8%A7%D9%84%D8%B9%D8%B1%D9%88%D8%B3%D8%A9-%D9%82%D8%AF-%D8%AA%D8%B5%D9%84-%D8%A5%D9%84%D9%89-30-%D8%A3%D9%84%D9%81-%D8%B1%D9%8A%D8%A7/) (press) |
| Henna (bride) | **Khobar ≤ SAR 200**, **Dammam SAR 700**. Makkah and Buraydah SAR 200–400. Riyadh from SAR 1,000. One Riyadh artist charges SAR 350 for both hands and feet. | Zafaf.net listings: [Khobar](https://saudi-arabia.zafaf.net/henneh-art/alkhobar/um-rawan), [Dammam](https://saudi-arabia.zafaf.net/henneh-art/dammam/assma-for-henna), [Riyadh](https://saudi-arabia.zafaf.net/henneh-art/riyadh/nouraan-45542), [Makkah](https://saudi-arabia.zafaf.net/henneh-art/makkah/soso-45785) |
| Photography / video | Full-day Riyadh coverage with women's and men's crews: **SAR 18,000–67,000**. Another guide: **10,000–40,000**. A Dammam package listing at **1,500** (scope unclear). | [Tov Studio guide](https://tovstudiophoto.com/best-wedding-photographers-in-saudi-arabia/), [saudieventmanagement](https://saudieventmanagement.com/blog/exceptional-wedding-cost-saudi-arabia-guide), [yaadgaarai Dammam](https://yaadgaarai.com/city/dammam/) (vendor marketing, likely skewed high) |
| Halls / venues | Wedding halls **20k–80k**, hotels **50k–150k**, outdoor 30k–100k. Economy halls in Jeddah 6k–17k. North Jeddah **SAR 200 per chair** including hospitality and the stage (Al-Watan, June 2024). | [hijri-calendars calculator](https://hijri-calendars.com/marriage-cost-calculator.php?lang=en), [Palazzo Palace review of published figures](https://palazzopalace.com/en/wedding-cost-saudi-arabia/) |
| Decor / kosha | Riyadh "decoration" **SAR 40k–120k**. This probably covers the full décor, not the kosha alone. | Via [palazzopalace](https://palazzopalace.com/en/wedding-cost-saudi-arabia/) (unverified as a kosha-only price) |
| Dress | Designer gown **SAR 20k–150k+** (undated). Second-hand evening dress in Dammam: SAR 950 (classified ad). | [palazzopalace](https://palazzopalace.com/en/wedding-cost-saudi-arabia/), [mstaml](https://www.mstaml.com/product/%D9%81%D8%B3%D8%AA%D8%A7%D9%86-%D8%B3%D9%87%D8%B1%D9%87-%D9%85%D8%A7%D8%B1%D9%83%D9%87-%D8%B9%D8%A7%D9%84%D9%85%D9%8A%D9%87-%D9%81%D9%8A-%D8%A7%D9%84%D8%AF%D9%85%D8%A7%D9%85-%D8%A8%D8%B3%D8%B9%D8%B1-950-%D8%B1%D9%8A%D8%A7%D9%84-%D8%B3%D8%B9%D9%88%D8%AF%D9%8A) |
| Whole wedding | **SAR 100k–300k**, including mahr, venue, hospitality, shabka and honeymoon. Jan 2024 report: mahr ~50k, party ~30k, honeymoon ~20k. | [hijri-calendars](https://hijri-calendars.com/marriage-cost-calculator.php?lang=en), [palazzopalace](https://palazzopalace.com/en/wedding-cost-saudi-arabia/) |
| Coffee servers (قهوجيات), kosha alone, cakes, zaffa / طقاقات, DJ, invitations, perfumes | **No sourced price found.** Ad listings such as [hawamer](https://hawamer.com/vb/hawamer2998300-1) and [mourjan](https://www.mourjan.com/sa/events-planning/5/) list Dammam coffee servers without prices. | Collect from the first providers you onboard |

**Takeaways for feature #13 (budget):**
- Prices vary by 10–100× within a single category, for example makeup from SAR 100 to SAR 30,000. A static "typical range" is too wide to drive filtering.
- **Store a `price_from` (and optional `price_to`) on every service.** "Show services ≤ budget" should compare against `price_from`.
- The bride's whole budget is the wrong yardstick. A bride with a 20k budget would see a 19k photographer and then have 1k left for everything else. Offer an optional **per-category allocation**, auto-suggested from category weights and editable by her, and filter each category against its own allocation. Keep the owner's simple version, where every service ≤ remaining budget, as the default.
- Deduct only bookings in `approved` or `paid` state. Restore the amount on decline, cancel or expiry. Recompute the remainder from bookings on the server rather than decrementing a stored number, so retries can't make it drift.
- Ask for the budget **after the bride has seen value**, for example on first open of Home or the first booking, with "Skip" and "Edit later in Profile". Asking during onboarding adds friction to a sensitive question. Also ask for the **wedding date** (Hijri and Gregorian), because it drives availability filtering and reminders.

### 1.2 Proposed seed categories

`launch` = seed and activate on day 1. `later` = seed inactive and enable from the dashboard. `parallel` = exempt from rule #20 (a bride can hold several active bookings in the category). `store` = typically sold through a linked store (#14).

| # | slug | العربية | English | Launch | Flags | Price hint (SAR) |
|---|---|---|---|---|---|---|
| 1 | `makeup` | خبيرة مكياج | Makeup artist | launch | | 350 – 3,000 (premium up to 20k+) |
| 2 | `hair` | تسريحات الشعر | Hair stylist | launch | | not found (often bundled with makeup) |
| 3 | `bridal_salon` | مشاغل وصالونات العرائس | Bridal salons | launch | | ~2,000 package (Riyadh) |
| 4 | `henna` | نقش الحناء | Henna artist | launch | parallel (henna night plus wedding day) | 200 – 1,000 |
| 5 | `photography` | مصورات | Female photographers | launch | | 1,500 – 40,000 |
| 6 | `videography` | تصوير فيديو | Videographers | later (merge into photography at first) | | included above |
| 7 | `venues` | قصور وقاعات الأفراح | Wedding halls & venues | launch | | 6,000 – 80,000 (hotels up to 150k) |
| 8 | `kosha_decor` | الكوش والتنسيق | Kosha & décor | launch | | not verified (full décor 40k–120k in Riyadh) |
| 9 | `flowers` | الورود وتنسيق الزهور | Flowers | later | parallel, store | not found |
| 10 | `dresses` | فساتين الزفاف (بيع، تأجير، تفصيل) | Wedding dresses (buy, rent, tailor) | launch | store | wide (rental to 150k+) |
| 11 | `evening_abayas` | فساتين السهرة والعبايات | Evening dresses & abayas | later | parallel, store | not found |
| 12 | `cakes_sweets` | الكيك والحلويات | Cakes & sweets | launch | parallel, store | not found |
| 13 | `catering` | البوفيه والضيافة | Catering & buffet | later | | not found |
| 14 | `coffee_servers` | القهوجيات والصبابات | Coffee & hospitality servers | launch | parallel | not found |
| 15 | `zaffa_tagagat` | الزفة والطقاقات | Zaffa & female bands | launch | | not found |
| 16 | `dj_sound` | دي جي وصوتيات | DJ & sound | later | | not found |
| 17 | `spa_skin` | السبا والعناية بالبشرة | Spa & skincare | launch | parallel | not found |
| 18 | `nails_lashes` | الأظافر والرموش | Nails & lashes | later | parallel | not found |
| 19 | `perfume_bakhoor` | العطور والبخور | Perfumes & bakhoor | later | parallel, store | not found |
| 20 | `invitations` | الدعوات والبطاقات | Invitations | later | store | not found |
| 21 | `favors_gifts` | التوزيعات والهدايا | Favors & gifts | launch | parallel, store | not found |
| 22 | `trousseau` | جهاز العروس | Bridal trousseau | later | parallel, store | not found |
| 23 | `planner` | منسقة حفلات | Wedding planner | later | | not found |
| 24 | `packages` | باقات العروس | Bridal packages | later | | varies |
| 25 | `jewelry_rental` | تأجير المجوهرات والإكسسوارات | Jewelry & accessory rental | later | store | not found |

Notes:
- Rule #20 (one active booking per category until completed) works well for makeup, photography, venues and kosha. It would **block legitimate behaviour** for goods and repeatable services such as henna for both the henna night and the wedding, several sweets orders, or spa visits. Add the `allows_parallel_bookings` column so admins can exempt a category without a code change.
- Consider a **"women-only provider"** flag on services (`female_staff_only`). Brides in KSA often require female photographers and makeup artists, and the flag makes a strong filter chip. This is a product assumption; validate it in user interviews.
- Provider-uploaded portfolio photos often show **brides**. Require the provider to tick a box confirming they have the client's consent, and give every image a "report" option (#28). See §5.5.

---

## 2. Competitors (Saudi and Gulf)

Store pages and competitor sites could not be opened (WebFetch DNS failures). The descriptions below come from search summaries and the companies' own marketing. Current ratings and activity levels are **not verified**.

| Name | What it is | Good | Weak or gap for brides | Source |
|---|---|---|---|---|
| **Zafaf.net (زفاف.نت)** | Arabic wedding-vendor directory launched in 2015 by Turkey's Düğün. Freemium: listing is free, visibility is paid. Has Dammam and Khobar henna listings with prices. | Large SEO footprint, price fields, city pages | Directory only, with no booking, scheduling or payment flow. The vendor-pays-for-visibility model resembles Munyati's tiers. | [Wamda 2016](https://www.wamda.com/2016/10/turkish-wedding-marketplace-dugun-sets-sights-ksa-zafafnet), [Zafaf Dammam henna](https://saudi-arabia.zafaf.net/henneh-art/dammam/assma-for-henna) |
| **Arabia Weddings** | Editorial site and vendor directory (182 Saudi planner listings). Has Eastern Province venue guides (Crowne Plaza Al Khobar, Mövenpick Al Khobar). | Editorial authority, inspiration content | No booking; English-heavy | [planners](https://www.arabiaweddings.com/saudi-arabia/planners), [EP venues](https://www.arabiaweddings.com/tips/top-wedding-venues-eastern-province-ksa) |
| **أفراح (Afrah)** | App for halls, kosha, photography and other wedding supplies (iOS and Android) | Multi-category, KSA-wide | Heavy promotional forum spam, so the real traction is unclear; venue-centric | [afrah-ksa.com](https://www.afrah-ksa.com/) (summary only) |
| **فرحة (Farha, frhsa.com)** | "Book your wedding services by paying only a deposit": halls, photographers, kosha, coordination, hospitality. iOS only per its own page. | Deposit-first model matches local habit | Site could not be reached (DNS), so it may be inactive | [frhsa.com](https://frhsa.com/) (search summary) |
| **Megavents** | Venue and event-space booking. Claims to be the "first licensed digital platform in Saudi Arabia" for venues and vendors (catering, photography, bridal). | Licensing claim builds trust | Venue/B2B focus, not bride-centric | [App Store](https://apps.apple.com/us/app/id1564827044) |
| **مناسبتي – مقدم الخدمة** | Provider-side app for beauty, gifts and hospitality. Customers filter by service, price, location and rating, book, chat in-app, and pay in-app or cash. | Closest feature match: two-sided, booking plus chat | KSA coverage unconfirmed; general events, not bride-specific | [App Store](https://apps.apple.com/us/app/id6461205319) |
| **Jamelah (جميلة)**, Crystal, Makeme-Up | Home or in-salon beauty booking (makeup, hair, massage) | On-demand beauty UX | Not wedding-specific; no budget or multi-vendor planning | [Jamelah](https://apps.apple.com/us/app/id1440420314), [Makeme-Up](https://apps.apple.com/us/app/-/id6745891030) |
| **Fresha / Salonist** | Global salon booking with Riyadh bridal-makeup listings | Polished booking UX, real-time availability | Salon-centric, weak in the Eastern Province, no bride journey | [Fresha](https://www.fresha.com/lp/en/tt/bridal-makeup/in/sa-riyadh-riyadh), [Salonist](https://salonist.io/cs/en/ct/makeup/in/sa-riyadh) |
| FRH (2018) | Makeup artists and photographers in Madinah and Makkah | n/a | Probably defunct (8-year-old article) | [Arab News](https://www.arabnews.com/node/1362876/spa/aggregate) |
| Everything Woman | Makeup-artist booking (Kuwait) | n/a | Kuwait market | [App Store](https://apps.apple.com/app/id6448625961) |
| *Bride Assistant* | Graduation-project prototype aimed at **Eastern Province brides** (budgeting, venues, vendors) | Evidence of the same need in the same region | Not a live product | [Mostaql](https://mostaql.com/portfolio/3190368-bride-assistant-app-graduation-project) |
| **Instagram, Snapchat, WhatsApp** | The de facto market: vendors post work and take bookings by DM | Free and trusted | No availability, no price transparency, no dispute path, reviews can't be trusted | [Al Maktoum Initiatives on social media and Saudi weddings](https://www.almaktouminitiatives.org/en/middle-east-exchange/story/how-social-media-is-changing-the-business-of-weddings-in-ksa) |

**Differentiation ideas for Munyati:**
1. **Bride-first journey**: wedding date, budget and remaining budget, category checklist ("you still need: kosha, coffee servers"), and a countdown. No competitor found combines these with booking.
2. **Local depth**: launch dense in one tight cluster (Dammam, Khobar, Qatif) rather than thin nationwide.
3. **Trust layer on a manual-payment model**: provider verification badge (CR or freelance document), a structured receipt flow with admin disputes, masked verified reviews only after completion, and report/flag (#28). This answers the main pain of DM-based booking.
4. **Provider tools that beat Instagram**: calendar, conflict-free scheduling, reschedule proposals, and the demo booking (#24). A provider who manages her diary in Munyati will push her Instagram followers into the app, and that is the growth loop.
5. **Women-only filter and Arabic-first copy**, with Hijri dates shown alongside Gregorian.

---

## 3. Cities: what "Damam - Khaibar - Tafeef" probably means

| Owner wrote | Literal match | Region | Alternative match | Region |
|---|---|---|---|---|
| Damam | **الدمام Dammam** (certain) | Eastern Province | n/a | n/a |
| Khaibar | خيبر Khaybar (small town about 150 km north of Madinah) | Madinah Province | **الخبر Al-Khobar** (Arabic consonants خ-ب-ر, also spelled "Khubar"); or **الخفجي Khafji** | Eastern Province |
| Tafeef | الطائف Taif | Makkah Province | **القطيف Al-Qatif** ("Qateef" shares the -eef ending) | Eastern Province |

Reasoning:
- Dammam, Khobar and Qatif form one contiguous metro area in the Eastern Province, all within roughly 30 km of each other. Saudi weather and service bulletins routinely group them together ([Saudipedia: Eastern Province administrative centres](https://saudipedia.com/قائمة-المراكز-الإدارية-في-المنطقة-الشرقية)). A bridal marketplace needs **local density**, since a makeup artist travels to the bride. Three adjacent cities form a viable launch market. Dammam, Khaybar and Taif are three different provinces about 1,000+ km apart, and that would be a very unusual launch footprint for a small startup.
- The owner's previous app is **Maalim Al-Khafji** (`kolna-al-khafji-ios`), so the owner has ties to the Eastern Province. Khafji (الخفجي) is also in the Eastern Province, about 300 km north of Dammam. "Khaibar" could therefore also mean **Khafji**.
- The orchestration brief also frames Munyati as "an app for brides in the Eastern Province".
- Sibling reports in this folder (`admin-dashboard.md`, `lamha-ios-and-backend.md`, `kolna-backend.md`, `backend-stack-and-cost.md`) assumed Dammam, Khaybar and Taif. **Those assumptions should be revisited** once the owner confirms. The latency and maps notes about "Khaibar/Taif" in `backend-stack-and-cost.md` would then become Khobar/Qatif.

**Recommendation:** Ask the owner a single question: "هل تقصد الدمام والخبر والقطيف؟ أم الدمام وخيبر والطائف؟" (Do you mean Dammam, Khobar and Qatif, or Dammam, Khaybar and Taif?). Until the owner answers, seed **الدمام / Dammam, الخبر / Al Khobar, القطيف / Al Qatif** as `active`, with Khafji ready but inactive. Store `name_ar`, `name_en`, `slug`, `lat` and `lng` per city so the map (Explore tab) can centre on it, and keep "All" as a client-side meta-option rather than a database row.

---

## 4. Manual payment methods in KSA and fraud controls

Apple's guideline 3.1.3(e) treats a bride paying a provider directly for a real-world service as outside in-app purchase. See `docs/research/app-store-policy.md` §2: wording must say "pay the provider directly", and Munyati must never appear to hold the money.

### 4.1 Methods providers can list

| Method type | What it is | Fields to collect | Validation | Source |
|---|---|---|---|---|
| `iban` (bank transfer) | Any Saudi bank account. Transfers up to **SAR 20,000** settle instantly through **سريع (SARIE IPS)**, launched by SAMA in Feb 2021, which runs 24/7. | `account_holder_name` (must match the bank's beneficiary name), `iban`, `bank_name` (derived) | `^SA\d{22}$` after stripping spaces and upper-casing (24 characters: `SA` + 2 check digits + 2-digit bank code + 18-character account). Run the **ISO 13616 mod-97** check. Derive the bank from characters 5–6. Bank-code tables in secondary sources **conflict**, so build the lookup from a SAMA or bank-published list rather than hard-coding from blogs. | [Saudipedia: سريع](https://saudipedia.com/نظام-المدفوعات-الفورية-سريع), [ohmyfin IBAN format](https://ohmyfin.ai/swift-codes/SAMBSARIACS) |
| `sarie_alias` (transfer by mobile number) | Through سريع a sender can pay to a **mobile number**, national ID/iqama or email registered to the recipient's bank account, and the app shows the recipient's name before confirming. | `account_holder_name`, `alias_type` (mobile, national ID, email), `alias_value`, optional `bank_name` | Mobile `^05\d{8}$` (normalise to `+9665…`). Show only a masked national ID to brides, or don't offer the national-ID alias at all (privacy). | [Saudipedia](https://saudipedia.com/نظام-المدفوعات-الفورية-سريع), [GIB guide (PDF)](https://gib.com/sites/default/files/reference-guide-arabic.pdf) |
| `wallet` (STC Bank, formerly STC Pay) | SAMA approved stc pay's transition to **STC Bank** (beta in April 2024). Upgraded users get an IBAN. | `wallet_provider`, `account_holder_name`, `wallet_mobile`, optional IBAN | Mobile regex. Recommend the IBAN when one exists. | [FinTech Futures](https://www.fintechfutures.com/bankingtech/sama-greenlights-beta-launch-of-stc-bank), [STC Bank notice](https://stcbank.com.sa/notice-of-transformation) |
| `wallet` (urpay, Al Rajhi) | Wallet with local and wallet-to-wallet transfers; signup by mobile, ID and Nafath | same as above | same as above | [lifeinsaudiarabia](https://lifeinsaudiarabia.net/make-urpay-international-bank-transfer/) (blog) |
| `wallet` (Barq, Alinma Pay, others) | Licensed wallets exist (SAMA licensed its 32nd payment company in May 2026), but **nothing verifiable about Barq or Alinma Pay P2P mechanics was found** | `wallet_provider` (admin-managed enum), `account_holder_name`, `wallet_mobile` | Mobile regex | [SAMA news](https://www.sama.gov.sa/en-US/MediaCenter/News/Pages/news-1146.aspx), [saudilifeguide (blog)](https://saudilifeguide.com/best-money-transfer-services/) |

Design notes:
- Make `wallet_provider` an **admin-editable lookup table** (name, logo, active flag), like categories. The wallet market is changing (STC Pay → STC Bank, new licences), and remote content (#19) then covers wallet logos too.
- Let a provider list several methods and mark one as primary. Show brides a **copy button** for the IBAN or mobile number and the exact amount.
- Wallet limits (for example a monthly cap of about SAR 20,000 on STC Pay deposits through one payout provider) are **not authoritative** for P2P transfers. Don't encode limits; for high-value bookings, show a hint such as "large amounts: prefer bank transfer" ([PayerMax docs](https://docs.payermax.com/en/202506-version/disbursement/payment-method-list/mea/saudi-arabia.html)).

### 4.2 Fraud patterns with screenshot receipts

General patterns, mostly from non-Saudi sources. No SAMA warning specific to forged transfer screenshots was found.

| Pattern | Description | Source |
|---|---|---|
| Edited screenshot | Amount, date or beneficiary edited in an image editor or generated with AI. Fake receipts can closely mimic real banking-app confirmation screens. | [Cashfree](https://cashfree.com/blog/fake-payment-screenshot-scams), [Resistant AI](https://resistant.ai/blog/venmo-scams) |
| Partial payment + fake remainder | A real small deposit, then a forged receipt for the balance | [Trend Micro](https://helpcenter.trendmicro.com/en-us/article/TMKA-18984) |
| Reused receipt | The same real receipt submitted for two bookings, or by two brides | Common pattern; mitigated by hashing |
| Off-platform move | The scammer moves the conversation to WhatsApp to escape platform monitoring | [Trend Micro](https://helpcenter.trendmicro.com/en-us/article/TMKA-18984) |
| **Payment-detail swap** (provider side, or a compromised account) | The IBAN is changed just before a bride pays; the money goes to a third party | Inferred risk; banks warn customers about requests to pay new or personal accounts ([SC Saudi fraud alert](https://www.sc.com/sa/uploads/sites/59/content/docs/Fraud-alert-Arabic.pdf)) |
| Provider denies receipt | A provider claims "not received" to extract a second payment | Inferred risk for a manual model |

The key principle from every source: **verify against the bank account or app, never the image** ([TD Commons](https://www.tdcommons.org/dpubs_series/7477), [Klippa](https://www.klippa.com/en/blog/information/detect-fake-receipts/)). Only the provider can do that check, so the product must make the provider's confirmation explicit and on the record.

### 4.3 Mitigations to build

1. **Booking reference code**, e.g. `MN-7K3QX` (short, unambiguous characters). Show it next to the amount with the instruction «اكتبي هذا الرمز في ملاحظة التحويل» ("write this code in the transfer note"). The provider confirms they saw it in their bank app.
2. **Structured receipt submission**: the bride uploads the image **and** types the amount, transfer date/time, sending bank and the last 4 digits of her account or her wallet mobile. Mismatches with the booking amount are flagged.
3. **Image hashing**: store the SHA-256 of the original bytes and a perceptual hash (pHash/dHash) per upload. Flag exact or near duplicates across all bookings to admins. The perceptual-hash step is an engineering recommendation; no source was found that documents it for receipts.
4. **Keep the original file** in a private bucket, with server-side metadata (upload time, device and app version). Serve brides and providers re-encoded copies.
5. **Explicit provider confirmation**: the provider taps "تم استلام المبلغ في حسابي" ("I received the amount in my account"), not "the receipt looks fine". Log who confirmed and when, as an immutable audit row.
6. **Timeouts**: if the provider neither confirms nor rejects within N hours (configurable, e.g. 48 h), auto-escalate to admin, and on the bride's side show "awaiting provider confirmation" instead of silently cancelling.
7. **Dispute window**: either party can open a dispute within X days of a payment state change. A dispute freezes the booking, notifies admins, and keeps reviews locked.
8. **Freeze payment methods** while any booking is `awaiting_payment`. An edit to a payment method triggers an OTP re-auth, an admin-visible audit row and a 24 h "new account" banner for brides.
9. **Name match**: show the **account-holder name** prominently, so the bride can compare it with the name her bank shows before confirming (سريع displays it).
10. **Keep chat in the app**, and make it clear that payments made to details not shown in Munyati are unprotected.
11. **Provider risk score** for the admin dashboard: counts of disputes, unconfirmed payments, duplicate-receipt hits and payment-method edits.

---

## 5. Legal context (practical, for a small startup; not legal advice)

### 5.1 Munyati as the platform operator
- **Commercial Registration (CR):** under the new Commercial Register Law, in force since **3 April 2025**, a single national CR is valid across all regions, has no expiry date, and needs an annual data confirmation. The CR number doubles as the unified establishment number, starting with 7. ([Arab News](https://www.arabnews.com/node/2595553), [HFW](https://www.hfw.com/insights/saudi-arabias-new-commercial-registration-law-impacts-and-next-steps-for-business-owners/), [Clyde & Co](https://www.clydeco.com/en/insights/2025/09/ksa-commercial-registration-law-and-trade-name-law))
- **E-store verification:** the Ministry of Commerce named the **Business Platform (business.sa, Saudi Business Center)** as the **only** authorised verification platform, replacing Maroof. Verification needs a CR or a valid professional/freelance document plus a **commercial bank account**. Applicants sign in through Nafath and prove domain ownership with a DNS TXT record on munyati.co. Verified stores are publicly searchable. ([MoC Mar 2023](https://mc.gov.sa/en/mediacenter/News/Pages/29-03-23-02.aspx), [MoC Sep 2023](https://mc.gov.sa/en/mediacenter/News/Pages/03-09-23-01.aspx), [Salla help](https://help.salla.sa/en/article/verify-store-on-business-platform-instead-of-maroof/gno9ilestioyspm61yu5buzp))
- **E-Commerce Law (2019) and its Implementing Regulations (2020):**
  - **Art. 6**: disclose name/identifier and address (unless registered with an e-shop authentication entity), contact details, and CR name and number ([official EN text, MISA](https://misa.gov.sa/app/uploads/2025/07/E-Commerce-Law.pdf)).
  - **Art. 7**: before the contract, give the consumer a statement of terms, the steps to conclude the contract, provider info, characteristics of the service, **total price including all fees and taxes**, payment arrangements and any warranty (same source).
  - Secondary sources add the **VAT number**, the authentication proof and a privacy policy as items to display ([Tamimi](https://www.tamimi.com/law-update/july-2020/articles/theres-something-in-your-cart-an-update-on-e-commerce-in-saudi-arabia/), [Global Compliance News](https://www.globalcompliancenews.com/2020/03/16/saudi-arabia-regulates-e-commerce/), [Salla merchant obligations](https://help.salla.sa/en/article/merchant-ecommerce-obligations/g0cbvwqncrfmptexs580y6f7)). Verify these against the Implementing Regulations.
  - **Where this lands in the product:** a footer on munyati.co and an "About / Legal" screen in the app showing the legal entity name, CR number, VAT number (once registered), address, contact@munyati.co, a phone or WhatsApp number, and the business.sa verification badge. On every booking-request screen, show the service price, what's included, and the provider's cancellation/deposit terms **before** the bride submits.
- **VAT:** ZATCA's standard mandatory-registration threshold is taxable supplies above SAR 375,000 in 12 months. This is general knowledge and was not re-verified in this research; confirm it with an accountant. The threshold applies to Munyati's subscription revenue, not to the brides' payments to providers.

### 5.2 Consumer protection: cancellations and refunds
- **E-Commerce Law Art. 13**: a consumer may rescind within **7 days** of the service contract date **provided the service has not been received or benefited from**, at the consumer's cost unless agreed otherwise. Exceptions include custom-made products and (per Mondaq) **catering**. If performance is delayed **more than 15 days** past the agreed date, absent force majeure, the consumer may cancel for a full refund. ([MISA text](https://misa.gov.sa/app/uploads/2025/07/E-Commerce-Law.pdf), [Clyde & Co PDF](https://www.clydeco.com/clyde/media/fileslibrary/J470323_KSA_E-commerce_Law_Interactive_-_Update_0919_FV2.pdf), [Mondaq](https://www.mondaq.com/saudiarabia/economic-analysis/844624/e-commerce-law))
- **Practical rule set for Munyati:**
  - Every service carries a **cancellation policy template** chosen by the provider from 3–4 admin-defined options, e.g. "Flexible: full refund up to 7 days before", "Standard: deposit non-refundable after approval", "Custom-made: non-refundable after work starts". Display it before booking and snapshot it onto the booking row.
  - Munyati doesn't hold the money, so refunds are **provider-to-bride transfers** recorded with the same receipt flow in reverse (`refund_pending → refund_sent → refund_confirmed`).
  - The 2020 COVID precedent: the Ministry of Commerce told consumers that wedding-hall payments were refundable when events were banned, with complaints to **1900**. Put the consumer-complaints channel (1900 / the MoC app) in the support page as an escalation path ([thelawsa.com, a legal commentary site](https://thelawsa.com/%d8%a7%d8%b3%d8%aa%d8%b1%d8%af%d8%a7%d8%af-%d9%85%d8%a8%d9%84%d8%ba-%d8%ad%d8%ac%d8%b2-%d9%82%d8%a7%d8%b9%d8%a9/), as summarised by search). No current MoC rule specific to wedding halls was found.
- **Subscription side:** under the App Store recommendation (StoreKit IAP), Apple handles provider subscription refunds on iOS.

### 5.3 Do providers need a CR or a freelance document?
- **Freelance document (وثيقة العمل الحر)**: issued by MHRSD through freelance.sa (sign-in with Nafath). Usually free, valid about **1 year** (sources conflict on 1 vs 2 years), and it lets individuals offer services **without a CR**. Applicants pick a profession from the approved list and must prove it with certificates or work samples. ([Qoyod](https://www.qoyod.com/en/what-is-a-freelance-work-document-sa/), [wdeftksa](https://wdeftksa.com/sa/guides/freelance), [khaleejcalculators](https://khaleejcalculators.com/freelance/freelance-professions))
- **Not verified:** whether "makeup artist", "henna artist" or "photographer" are on the current approved profession list. No search returned the official list. Check freelance.sa directly.
- **Home-based businesses** (e.g. a bride's-salon run from home): the activity is chosen from the Saudi Business Center activity guide, and the CR can list the home as premises. Activities that **receive customers regularly, such as women's salons, need a separate entrance and separate facilities** ([rukn-services](https://rukn-services.com/%D8%B1%D8%AE%D8%B5%D8%A9-%D8%A8%D9%84%D8%AF%D9%8A%D8%A9-%D8%A8%D8%AF%D9%88%D9%86-%D9%85%D8%AD%D9%84-%D8%A7%D9%84%D8%B9%D9%85%D9%84-%D9%85%D9%86-%D8%A7%D9%84%D9%85%D9%86%D8%B2%D9%84-%D9%88%D8%A7%D9%84/), a service-office blog).
- **Practical recommendation:**
  - At provider signup, collect `legal_doc_type` (`cr | freelance | none`), `legal_doc_number` and an optional document upload.
  - Admins verify the documents and grant a **«موثّق» (verified) badge**.
  - Rank verified providers higher, and offer verification as a Plus/Diamond perk or prerequisite.
  - Don't hard-block unverified providers at MVP, because many bridal freelancers today work informally through Instagram. Put the "provider is responsible for their own licensing" clause in the provider terms.
  - Revisit the policy with counsel before scaling.

### 5.4 PDPL (personal data)
Covered in depth in `docs/research/backend-stack-and-cost.md` §7: Frankfurt hosting, the transfer basis and the privacy-policy contents. Points specific to this marketplace:
- The privacy policy must be available **before collection** and state the purpose, the data collected, how it is collected, stored, processed and destroyed, and data-subject rights and how to exercise them. The Implementing Regulations require clear wording in an appropriate language, so publish both **Arabic and English** ([myctrl PDPL Art. 12 mapping](https://myctrl.tools/frameworks/sa-pdpl/article-12), [DataGuidance](https://www.dataguidance.com/opinion/saudi-arabia-final-implementing-regulations-and)). Enforcement began in September 2024 ([Clyde & Co](https://www.clydeco.com/en/insights/2024/09/saudi-arabia-s-personal-data-protection-law-become)). SDAIA consulted on amendments in April 2025 ([Clyde & Co](https://www.clydeco.com/en/insights/2025/05/saudi-arabia-new-pdp-law-consultation)), and the final status of those amendments is unverified.
- Personal data under the PDPL includes photographs ([cookie-script summary](https://cookie-script.com/privacy-laws/saudi-arabia-personal-data-protection-law/amp)). That covers bride portfolio photos, receipts, IBANs, the budget and the wedding date. List each of these explicitly, together with its **retention period**, e.g. receipts kept N months after completion or dispute closure for audit and then deleted.
- Cross-border transfer needs a lawful basis plus safeguards, and a transfer-risk assessment where no adequacy decision exists ([King & Spalding](https://www.kslaw.com/insights/articles/international-personal-data-transfers-under-saudi-arabias-data-protection-law)).
- Marketing SMS through OurSMS (#10) needs a consent flag, separate from the OTP consent, and an opt-out path. See `docs/research/oursms.md`.

### 5.5 Content and conduct (supports #15, #28)
- Require provider consent to publish client (bride) photos, and remove reported images quickly. Cultural sensitivity around women's images is high in KSA. Search for a specific statute (e.g. the Anti-Cyber Crime Law privacy provisions) was **not performed**; have counsel confirm before writing the content policy.
- Masked reviewer names (#15) follow the Maalim pattern and help with privacy as well.

### 5.6 Pages to publish on munyati.co (#29)
Landing page (AR/EN), Privacy Policy (PDPL), Terms of Use (bride), **Provider Terms** (subscription, the provider's licensing responsibility, payment-method accuracy, dispute cooperation, content consent), Cancellation & Refund Policy (templates from §5.2), Payment Safety guide for brides (reference code, name check, never pay outside the listed methods), Community Guidelines / Report, Support / Contact (contact@munyati.co plus a WhatsApp number), the Art. 6 legal-entity block in the footer, and `/.well-known/apple-app-site-association` for universal links (#27).

---

## 6. Brand: "منيتي"

- **Meaning:** منيتي is "my wish / my heart's desire", from مُنية (wish). The related given name is rendered in Latin script as Muniah/Monia/Moniah ([QuranicNames](https://cdn.quranicnames.com/muniah/)). It is a warm, feminine, aspirational name that fits a bride-centric app.
- **Spelling conflict:** the repo, folder and project use **"Moniaty"** (`/home/user/moniaty_ios`, GitHub `Moniaty_iOS`). The purchased domain and email use **"Munyati"** (`munyati.co`, `contact@munyati.co`).
- **Recommendation: standardise on "Munyati".** Reasons:
  1. It matches the domain and email you already own, so universal links, the AASA file and support emails stay consistent.
  2. "Mun-ya-ti" tracks the Arabic مُنْيَتي syllable by syllable.
  3. "Moniaty" invites the misreading "money-aty" (finance).
  4. Searches turned up no existing Saudi app named Munyati, Moniaty or Monyati. That is only a weak signal; run a **SAIP trademark search** and an App Store name check before committing.
  - Rename the display name, bundle ID (e.g. `co.munyati.app`), XcodeGen target and docs. Keep the GitHub repo name if renaming is costly, but add a note to the README.
- **App Store metadata** (name ≤ 30, subtitle ≤ 30, keywords ≤ 100 characters per localisation; Apple ignores words already in the name, so don't repeat them):
  - Name: **منيتي - Munyati** (15 characters)
  - Arabic subtitle: **كل تجهيزات العروس في مكان واحد** (30). Alternative: **احجزي خدمات زفافك بكل سهولة** (27).
  - English subtitle: **Bridal services, booked easily** (30). Alternative: **Your wedding, all in one app** (28).
  - Arabic keywords (94): `زفاف,زواج,مكياج,ميكب,مصورة,تصوير,حناء,قاعات,كوشة,قهوجيات,فستان,مشغل,صالون,تجهيزات,الدمام,الخبر`
  - English keywords (96): `bride,wedding,makeup,photographer,henna,venue,hall,kosha,decor,dress,salon,planner,Dammam,Khobar`
  - Replace the city keywords once the cities are confirmed (§3). Check in App Store Connect which localisations the Saudi storefront indexes; this was not verified here.
- **Logo direction** (for the requested new logo; colours from the brief): burgundy `#8A0D3A` as the primary mark on ivory `#FAFAEC`, with gold `#DFC389` as the accent and cream `#F2E5D2` for surfaces. Motif ideas: a monogram built from the Arabic letters «م» or «منيتي», a star or wish spark (أمنية), or an abstract ring. Avoid literal bride silhouettes, which date quickly and may be culturally sensitive. Check contrast: burgundy on ivory is high contrast, while gold on ivory is too light for small text, so use it for ornaments only.

---

## 7. What to reuse, adapt or add

| Item | Status |
|---|---|
| Name masking for reviews (#15) | Reuse the Maalim/Kolna review-masking migrations (see `kolna-backend.md`) |
| Cities and categories tables | Adapt: add `allows_parallel_bookings`, `is_store_category` and per-category `budget_weight`; seed from §1.2 and §3 |
| Payment methods, receipts, disputes | **Missing.** No equivalent in Kolna or Lamha, which use Tap card payments. Needs new tables (`provider_payment_methods`, `payment_receipts` with `sha256` and `phash`, `booking_disputes`, `payment_method_audit`) and admin screens. |
| IBAN validator | Missing. Add a small Swift and SQL/TS function (mod-97 plus a bank-code lookup table). |
| Legal pages and AASA | Adapt the Lamha `.well-known/apple-app-site-association` and the Kolna CMS pages pattern for the §5.6 pages |
| Provider verification badge | Missing. New `provider_verifications` table and an admin review queue. |

## 8. Open questions for the owner
1. Cities: Dammam, Khobar and Qatif, or Dammam, Khaybar and Taif, or does "Khaibar" mean Khafji? (§3)
2. Should unverified providers (no CR or freelance document) be allowed at launch? (§5.3)
3. Is a "female staff only" filter wanted? (§1.2)
4. Which categories should allow several simultaneous bookings? (§1.2, rule #20)
5. Confirm the brand spelling "Munyati" across the app, the repo and the store listing. (§6)
