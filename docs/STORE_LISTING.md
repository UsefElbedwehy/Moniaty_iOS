# Store listing and review paperwork (draft)

Ready-to-paste text for App Store Connect and Google Play Console, plus the privacy answers.
Screenshots: `design/store/ios/` (6.9" iPhone, 1320×2868, Arabic and English; retake with real
providers' photos before launch: `StoreScreenshotsTests`) and `design/store/android/` (phone,
1080×2400, Arabic and English). Check every answer against how you actually run
the business; the privacy answers must match the privacy policy in the dashboard.

---

## 1. App Store Connect

| Field | Arabic (primary) | English |
|---|---|---|
| Name (30) | منيتي - Munyati | Munyati - منيتي |
| Subtitle (30) | كل تجهيزات العروس في مكان واحد | Wedding services in one place |
| Primary category | Lifestyle | |
| Secondary category | Shopping | |
| Age rating | Answer "None" to the content questions and **Yes** to user-generated content (reviews, photos; reporting and blocking are in place). Apple then computes the rating. | |
| Support URL | https://munyati.co/support | |
| Marketing URL | https://munyati.co | |
| Privacy policy URL | https://munyati.co/privacy | |
| Copyright | © 2026 [legal company name] | |

**Promotional text (170)**
- ar: احجزي خبيرة المكياج والمصوّرة والقاعة وكل تجهيزات زفافك من مقدّمات خدمة موثّقات في الدمام والخبر والقطيف، ضمن ميزانيتك.
- en: Book makeup artists, photographers, venues and more from verified providers in Dammam, Khobar and Qatif — within your budget.

**Keywords (100, comma-separated, no spaces)**
- ar: `زفاف,عروس,مكياج,مصورة,قاعات,حناء,تجهيزات,حجز,عرس,كوافير,فساتين,الدمام,الخبر,القطيف,ميزانية`
- en: `wedding,bride,makeup,photographer,venue,henna,bridal,salon,booking,dammam,khobar,qatif,budget`

**Description — Arabic**

منيتي هو المكان الذي تجهّزين منه يوم زفافك بكل هدوء.

اكتشفي مقدّمات خدمة موثّقات في مدينتك: خبيرات المكياج، المصوّرات، قاعات الأفراح، نقش الحناء وغيرها. شاهدي صور وفيديوهات أعمالهن، والأسعار الكاملة، وتقييمات العرائس قبلك.

• حدّدي ميزانيتك وموعد زفافك، ونرتّب لك الخدمات المناسبة ونخصم كل حجز تلقائياً.
• اطلبي الحجز في الموعد الذي يناسبك، وتصلك موافقة مقدّمة الخدمة أو موعد بديل.
• ادفعي مباشرة لمقدّمة الخدمة بالتحويل البنكي أو المحفظة، وارفعي الإيصال من التطبيق.
• تابعي كل حجوزاتك في مكان واحد، مع إشعارات في كل خطوة.
• قيّمي تجربتك بعد الزفاف وساعدي العرائس من بعدك.
• تصفّحي الخريطة لتجدي الأقرب إليك.

لمقدّمات الخدمة: اعرضي خدماتك وصورك وفيديوهاتك، واستقبلي طلبات الحجز، ونظّمي أوقات عملك، وتابعي أداءك. أول شهرين مجاناً.

منيتي منصة تربط العرائس بمقدّمات الخدمة؛ الدفع يتم مباشرة بين الطرفين.

**Description — English**

Munyati is where you plan your wedding day, calmly.

Discover verified providers in your city: makeup artists, female photographers, wedding halls, henna artists and more. See their photos and videos, full prices and reviews from brides before you.

• Set your budget and wedding date; we show services that fit and deduct each booking automatically.
• Request a booking at the time that suits you; the provider approves or proposes another time.
• Pay the provider directly by bank transfer or wallet and upload the receipt in the app.
• Follow all your bookings in one place, with a notification at every step.
• Review your experience after the wedding and help the brides after you.
• Browse the map to find providers near you.

For providers: list your services with photos and videos, receive booking requests, set your working hours and follow your performance. The first two months are free.

Munyati connects brides with service providers; payment is made directly between them.

### Review notes (App Review Information → Notes)

> Munyati is a marketplace for wedding services in Saudi Arabia (makeup, photography, venues…).
> Brides pay providers **directly** (bank transfer / wallet) for services performed in person at
> the wedding, outside the app (guideline 3.1.3(e)); the app only records the receipt the bride
> uploads, and the provider confirms it. No money passes through the app for bookings.
>
> Demo accounts (sign-in is by phone number + SMS code; these numbers accept a fixed code):
> - Bride: **[+9665XXXXXXX1]**, code **[XXXXXX]**: has bookings in several states.
> - Subscribed provider: **[+9665XXXXXXX2]**, code **[XXXXXX]**: services, bookings, insights.
> - New provider: **[+9665XXXXXXX3]**, code **[XXXXXX]**: the join flow and the demo booking.
>
> Provider plans: [describe the decision you took for PLAN §16 #2: Tap or In-App Purchase].
> Users can report and block any content or user; reports are reviewed within 24 hours.
> Account deletion: Profile → Delete account (also https://munyati.co/delete-account).

Fill the brackets after setting `DEV_PHONES` / `DEV_OTP_CODE` (OWNER_TODO §2, §7).

### App Privacy ("nutrition label")

**Data used to track you:** none (no advertising, no IDFA, no data brokers).

**Data linked to you** (all collected for *App Functionality* unless noted):

| Apple data type | What it is in Munyati | Purposes |
|---|---|---|
| Contact Info → Name | Display name; provider business name | App Functionality |
| Contact Info → Phone Number | Sign-in and booking contact | App Functionality |
| Location → Coarse Location | Chosen cities (filters, city notifications) | App Functionality |
| Location → Precise Location | A provider's store/business pin on the map | App Functionality |
| Financial Info → Other Financial Info | Providers' payout details (IBAN, wallet number); payment receipts | App Functionality |
| Purchases → Purchase History | Bookings and provider plan payments | App Functionality |
| User Content → Photos or Videos | Service photos/videos, review photos, receipt images | App Functionality |
| User Content → Customer Support | Support tickets | App Functionality |
| User Content → Other User Content | Reviews and replies, booking notes, reports | App Functionality |
| Identifiers → User ID | Account ID (also attached to crash reports) | App Functionality, Analytics |
| Usage Data → Product Interaction | Screens viewed and key actions (Firebase Analytics, our analytics table) | Analytics |
| Diagnostics → Crash Data | Crashlytics | App Functionality |
| Diagnostics → Other Diagnostic Data | Handled errors | App Functionality |

Card details for provider plans are entered on Tap's hosted page and never reach Munyati, so
"Payment Info" is **not** collected by the app.

---

## 2. Google Play Console

| Field | Text |
|---|---|
| App name (30) | منيتي - Munyati |
| Short description (80), ar | كل تجهيزات العروس في مكان واحد: مكياج، تصوير، قاعات وحناء ضمن ميزانيتك |
| Short description (80), en | Wedding services in one place: makeup, photography, venues, within budget |
| Full description | Same as the App Store descriptions above |
| Category | Lifestyle (or Events) |
| Contact email | contact@munyati.co |
| Website | https://munyati.co |
| Privacy policy | https://munyati.co/privacy |
| Ads | No ads |
| Target audience | 18 and over |
| App access | "Some functionality is restricted": give the three demo numbers and code from above |
| Content rating (IARC) | No violence, sex, drugs, gambling. **Users can interact / share content: Yes** (reviews, photos), with reporting and blocking. No location sharing between users. Digital purchases: provider plans |
| Account deletion URL | https://munyati.co/delete-account |

### Data safety

- Data is **encrypted in transit**: Yes (HTTPS only).
- Users can **request deletion**: Yes, in the app (Profile → Delete account) and at the URL above.
- Shared with third parties: **No** for selling or advertising. (Service providers that process
  data for us, such as Supabase, Firebase, OurSMS and Tap, count as processors, not "sharing".)

| Play category → type | Collected | Optional? | Purpose |
|---|---|---|---|
| Personal info → Name | Yes | Required | App functionality, Account management |
| Personal info → Phone number | Yes | Required | App functionality, Account management |
| Personal info → User IDs | Yes | Required | App functionality, Analytics |
| Financial info → Purchase history | Yes | Required | App functionality |
| Financial info → Other financial info | Yes (providers' payout details, receipts) | Optional (providers) | App functionality |
| Location → Approximate location | Yes (chosen cities) | Optional | App functionality |
| Location → Precise location | Yes (provider's business pin) | Optional (providers) | App functionality |
| Photos and videos → Photos, Videos | Yes | Optional | App functionality |
| App activity → App interactions | Yes | Required | Analytics |
| App activity → Other user-generated content | Yes (reviews, notes, reports, support) | Optional | App functionality |
| App info and performance → Crash logs, Diagnostics | Yes | Required | App functionality, Analytics |
| Device or other IDs | Yes (push token, Firebase installation ID) | Required | App functionality, Analytics |

The "my location" button on the maps reads the position **on the phone only** to centre the
map; it isn't sent anywhere, so it isn't "collected" in Play's sense.
