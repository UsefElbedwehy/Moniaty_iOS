-- Draft legal pages (ar + en): privacy, terms, provider terms and FAQ, replacing the
-- placeholders seeded in 20261010000100_reference_data.sql. They describe how the app actually
-- works (docs/PLAN.md §4 and §16). Drafts: have them reviewed by a Saudi lawyer and fill in the
-- [bracketed] company details before launch. Later edits happen in the dashboard (Pages).

insert into public.cms_pages (slug, lang, title, body_markdown) values

-- ---------------------------------------------------------------------------------------------
-- Privacy policy
-- ---------------------------------------------------------------------------------------------
('privacy', 'ar', 'سياسة الخصوصية', $md$آخر تحديث: 16 أكتوبر 2026

توضّح هذه السياسة كيف تجمع منيتي («المنصة» أو «نحن») بياناتك الشخصية وتستخدمها وتحميها، وفقاً لنظام حماية البيانات الشخصية في المملكة العربية السعودية. تُشغَّل منيتي من قِبَل [اسم المنشأة كما في السجل التجاري]، سجل تجاري رقم [رقم السجل].

## 1. البيانات التي نجمعها

**بيانات الحساب:** رقم الجوال، والاسم، ونوع الحساب (عروس أو مقدّمة خدمة)، ولغة التطبيق.

**بيانات العروس:** المدن المختارة، وتاريخ الزفاف (اختياري)، والميزانية (اختيارية)، والمفضّلة.

**بيانات مقدّمة الخدمة:** اسم النشاط، والفئات والمدن، ورقم السجل التجاري أو وثيقة العمل الحر والمستندات المرفقة بطلب الانضمام، والخدمات والصور والأسعار، والمتاجر (العنوان والموقع وروابط التواصل)، وطرق استلام المبالغ (الآيبان أو رقم التحويل الفوري أو المحفظة واسم صاحب الحساب).

**بيانات الحجوزات والدفع:** تفاصيل الحجز ومواعيده وسجلّ حالاته، وصور إيصالات التحويل مع المبلغ ووقت التحويل والبنك المحوِّل. لا نستلم مبالغ الحجوزات ولا نطّلع على حساباتك البنكية.

**اشتراكات مقدّمات الخدمة:** تتم عبر بوابة الدفع Tap. لا نخزّن بيانات البطاقات، ونحتفظ فقط بحالة العملية ومبلغها.

**المحتوى الذي تضيفينه:** التقييمات والردود، والبلاغات، وتذاكر الدعم.

**بيانات الجهاز والاستخدام:** رمز الإشعارات، وإصدار التطبيق، وأحداث الاستخدام داخل التطبيق (مثل مشاهدة خدمة أو البحث)، وتقارير الأعطال.

**الموقع:** يُستخدم موقعك أثناء فتح الخريطة فقط لعرض مقدّمات الخدمة القريبات، ولا نحفظه في خوادمنا. الكاميرا ومكتبة الصور تُستخدم فقط عندما تختارين رفع صورة.

## 2. لماذا نستخدم بياناتك

- لإنشاء حسابك والتحقق من رقم جوالك برمز لمرة واحدة.
- لعرض الخدمات المناسبة لمدينتك وميزانيتك.
- لتنفيذ الحجوزات بين العروس ومقدّمة الخدمة وإرسال الإشعارات والرسائل النصية المتعلقة بها.
- لمراجعة طلبات انضمام مقدّمات الخدمة وإدارة اشتراكاتهن.
- لمنع الاحتيال، ومنها كشف الإيصالات المكررة، ولمعالجة البلاغات والنزاعات.
- لتحسين التطبيق وإصلاح الأعطال وإعداد إحصاءات مجمّعة، ومنها إحصاءات تُعرض لمقدّمة الخدمة عن خدماتها.

نعالج بياناتك بناءً على موافقتك، ولتنفيذ الخدمة التي طلبتِها، وللوفاء بالتزاماتنا النظامية، ولمصلحتنا المشروعة في حماية المنصة ومستخدميها.

## 3. مع من نشارك بياناتك

- **الطرف الآخر في الحجز:** ترى مقدّمة الخدمة اسم العروس وتفاصيل الحجز والإيصال، وترى العروس بيانات الدفع التي أضافتها مقدّمة الخدمة. لا يُعرض رقم الجوال للطرف الآخر.
- **التقييمات:** تظهر التقييمات العامة باسم مختصر (أول حرفين من كل كلمة فقط).
- **مزوّدو خدمات يعملون لصالحنا:** Supabase (استضافة قاعدة البيانات والملفات)، وGoogle Firebase (الإشعارات وتحليلات الاستخدام وتقارير الأعطال)، وOurSMS (الرسائل النصية)، وTap Payments (دفع الاشتراكات). يلتزمون بمعالجة البيانات وفق تعليماتنا فقط.
- **الجهات المختصة:** عندما يطلب النظام ذلك.

لا نبيع بياناتك، ولا نعرض إعلانات، ولا نتتبّعك عبر تطبيقات أو مواقع أخرى.

## 4. نقل البيانات خارج المملكة

تُستضاف بعض البيانات لدى مزوّدي خدمات خوادمهم خارج المملكة (منها الاتحاد الأوروبي). نتّخذ الضمانات التي يتطلبها النظام لحماية بياناتك عند نقلها.

## 5. مدة الاحتفاظ

نحتفظ ببياناتك ما دام حسابك قائماً. عند حذف حسابك نحذف بياناتك الشخصية أو نجعلها مجهولة الهوية، ونحتفظ فقط بما يلزمنا النظام بالاحتفاظ به (مثل سجلات الحجوزات والمدفوعات) دون ربطه بهويتك قدر الإمكان، وللمدة التي يحددها النظام.

## 6. حقوقك

يحق لك الاطلاع على بياناتك، وطلب نسخة منها، وتصحيحها، وحذفها، والرجوع عن موافقتك. يمكنك تعديل معظم بياناتك من التطبيق، وحذف حسابك من «حسابي ← حذف الحساب» أو من [صفحة حذف الحساب](https://munyati.co/delete-account). لأي طلب آخر راسلينا على contact@munyati.co وسنرد خلال 30 يوماً. ويحق لك تقديم شكوى إلى الهيئة السعودية للبيانات والذكاء الاصطناعي (سدايا).

## 7. حماية البيانات

نقيّد الوصول إلى البيانات بحيث لا يرى كل مستخدم إلا ما يخصّه، وتُحفظ الإيصالات في مخزن خاص ولا تُعرض إلا عبر روابط مؤقتة، وتُسجَّل إجراءات فريق الإدارة.

## 8. العمر

منيتي مخصّصة لمن أتمّ 18 عاماً.

## 9. التعديلات

قد نحدّث هذه السياسة، وسننشر النسخة الجديدة هنا مع تاريخ التحديث، ونبلغك داخل التطبيق إذا كان التغيير جوهرياً.

## 10. التواصل

[اسم المنشأة]، [العنوان الوطني]. البريد: contact@munyati.co$md$),

('privacy', 'en', 'Privacy policy', $md$Last updated: 16 October 2026

This policy explains how Munyati ("the platform", "we") collects, uses and protects your personal data under the Saudi Personal Data Protection Law (PDPL). Munyati is operated by [company name as in the commercial registration], CR no. [number].

## 1. Data we collect

**Account data:** mobile number, name, account type (bride or service provider) and app language.

**Bride data:** chosen cities, wedding date (optional), budget (optional) and favorites.

**Provider data:** business name, categories and cities, commercial registration or freelance certificate number and documents attached to the application, services, photos and prices, stores (address, location, contact links), and payout methods (IBAN, instant-transfer number or wallet, and account-holder name).

**Booking and payment data:** booking details, times and status history, and transfer receipt images with the amount, transfer time and sending bank. We never receive booking money and never access your bank accounts.

**Provider subscriptions:** paid through the Tap payment gateway. We don't store card details; we keep only the status and amount of each payment.

**Content you add:** reviews and replies, reports and support tickets.

**Device and usage data:** push notification token, app version, in-app usage events (such as viewing a service or searching) and crash reports.

**Location:** used only while the map is open, to show nearby providers. We don't store it on our servers. The camera and photo library are used only when you choose to upload a photo.

## 2. Why we use your data

- To create your account and verify your mobile number with a one-time code.
- To show services that fit your city and budget.
- To carry out bookings between brides and providers and send the related notifications and text messages.
- To review provider applications and manage subscriptions.
- To prevent fraud, including detecting reused receipts, and to handle reports and disputes.
- To improve the app, fix errors and produce aggregated statistics, including the statistics providers see about their own services.

We process your data based on your consent, to provide the service you asked for, to meet our legal obligations and for our legitimate interest in protecting the platform and its users.

## 3. Who we share it with

- **The other party to a booking:** the provider sees the bride's name, the booking details and the receipt; the bride sees the payment details the provider added. Mobile numbers are not shown to the other party.
- **Reviews:** public reviews show a shortened name (only the first two letters of each word).
- **Service providers working for us:** Supabase (database and file hosting), Google Firebase (notifications, usage analytics and crash reports), OurSMS (text messages) and Tap Payments (subscription payments). They process data only on our instructions.
- **Authorities:** when the law requires it.

We don't sell your data, show ads or track you across other apps or websites.

## 4. Transfers outside Saudi Arabia

Some data is hosted by service providers whose servers are outside the Kingdom (including the European Union). We apply the safeguards the law requires when data is transferred.

## 5. Retention

We keep your data while your account exists. When you delete your account we delete or anonymise your personal data and keep only what the law requires (such as booking and payment records), unlinked from your identity where possible, for the period the law sets.

## 6. Your rights

You can access your data, get a copy, correct it, delete it and withdraw your consent. You can edit most data in the app and delete your account from "Profile → Delete account" or the [account deletion page](https://munyati.co/delete-account). For anything else, email contact@munyati.co and we'll reply within 30 days. You can also complain to the Saudi Data & AI Authority (SDAIA).

## 7. Security

Access is restricted so each user sees only their own data, receipts are kept in private storage and shown only through short-lived links, and admin actions are logged.

## 8. Age

Munyati is for people aged 18 or over.

## 9. Changes

We may update this policy. We'll post the new version here with its date and tell you in the app if a change is significant.

## 10. Contact

[Company name], [national address]. Email: contact@munyati.co$md$),

-- ---------------------------------------------------------------------------------------------
-- Terms of use (everyone)
-- ---------------------------------------------------------------------------------------------
('terms', 'ar', 'الشروط والأحكام', $md$آخر تحديث: 16 أكتوبر 2026

باستخدامك تطبيق منيتي أو موقع munyati.co فإنك توافقين على هذه الشروط. تُشغَّل منيتي من قِبَل [اسم المنشأة كما في السجل التجاري]، سجل تجاري رقم [رقم السجل].

## 1. دور منيتي

منيتي منصة إلكترونية تربط العرائس بمقدّمات خدمات الزفاف. **منيتي ليست طرفاً في الاتفاق على الخدمة**، ولا تقدّم الخدمات بنفسها، **ولا تستلم مبالغ الحجوزات ولا تحتفظ بها**: يتم الدفع مباشرة من العروس إلى مقدّمة الخدمة. مقدّمة الخدمة مسؤولة عن خدمتها وجودتها وعن صحة ما تنشره.

## 2. الحساب

- يجب أن يكون عمرك 18 عاماً فأكثر، وأن تستخدمي رقم جوال سعودي يخصّك.
- أنتِ مسؤولة عن صحة بياناتك وعن كل ما يتم من خلال حسابك.
- يمكنك التصفح كضيفة، ويلزم تسجيل الدخول للحجز والمفضّلة والتقييم والإبلاغ.

## 3. الحجز

- ترسل العروس طلب حجز لموعد متاح، ولمقدّمة الخدمة أن تقبله أو تعتذر عنه أو تقترح موعداً آخر.
- ينتهي الطلب الذي لا يُرد عليه خلال 48 ساعة، والموعد المقترح الذي لا يُرد عليه خلال 24 ساعة. قد تتغير هذه المدد، وتظهر المدة المطبّقة في التطبيق.
- يمكن للعروس أن يكون لها حجز نشط واحد فقط في كل فئة حتى يكتمل أو يُلغى.

## 4. الدفع والإيصالات

- بعد قبول الطلب تحوّل العروس **المبلغ كاملاً** إلى مقدّمة الخدمة بإحدى طرق الدفع الظاهرة في الحجز، وتكتب رمز الحجز في ملاحظة التحويل، ثم ترفع صورة الإيصال خلال 48 ساعة وإلا انتهى الحجز.
- تؤكّد مقدّمة الخدمة استلام المبلغ في حسابها، أو ترفض الإيصال مع ذكر السبب. إذا لم تردّ خلال 48 ساعة يُحال الحجز لفريق منيتي.
- رفع إيصال مزوّر أو مكرر، أو إنكار استلام مبلغ تم استلامه فعلاً، احتيال يؤدي إلى إيقاف الحساب فوراً وقد نبلغ عنه الجهات المختصة.

## 5. الإلغاء والاسترداد

- يمكن لأي من الطرفين إلغاء الحجز من التطبيق وفق ما يسمح به التطبيق في كل مرحلة.
- يخضع استرداد المبالغ المدفوعة للاتفاق بين العروس ومقدّمة الخدمة ولسياسة الإلغاء المعلنة في صفحة الخدمة. يتم الاسترداد مباشرة من مقدّمة الخدمة إلى العروس مع إيصال.
- إذا ألغت مقدّمة الخدمة حجزاً مدفوعاً، أو لم تقدّم الخدمة، فعليها إعادة المبلغ كاملاً.

## 6. النزاعات

يمكن لأي من الطرفين فتح نزاع على حجز مدفوع مع إرفاق ما يثبت موقفه. يُوقف النزاع الحجز والتقييمات حتى يراجعه فريق منيتي. قرار منيتي يتعلق باستخدام المنصة (مثل حالة الحجز وإيقاف الحسابات)، ولا يمنع أي طرف من اللجوء إلى الجهات المختصة.

## 7. التقييمات

يُتاح التقييم بعد اكتمال الحجز فقط، ويجب أن يكون صادقاً ومبنياً على تجربة حقيقية. قد نراجع التقييمات قبل نشرها، ولنا إخفاء ما يخالف هذه الشروط.

## 8. الاستخدام الممنوع

لا يُسمح بـ: الاحتيال أو انتحال الشخصية، أو المحتوى المسيء أو غير اللائق أو المخالف للأنظمة أو الآداب العامة، أو التحرش أو الإساءة لأي مستخدم، أو نشر صور الآخرين دون موافقتهم، أو محاولة الالتفاف على المنصة أو الإضرار بأنظمتها. **لا نتسامح مطلقاً** مع المحتوى المسيء أو المستخدمين المسيئين. يمكنك الإبلاغ عن أي محتوى أو مستخدم وحظره من التطبيق، ونراجع البلاغات خلال 24 ساعة.

## 9. المحتوى والملكية

يبقى المحتوى الذي تضيفينه ملكاً لك، وتمنحين منيتي إذناً غير حصري بعرضه داخل المنصة وفي الترويج لها. اسم منيتي وشعارها وتصميمها ملك لنا.

## 10. إيقاف الحساب وحذفه

لنا إيقاف أي حساب يخالف هذه الشروط أو يعرّض المستخدمين للخطر. ويمكنك حذف حسابك في أي وقت من التطبيق؛ راجعي [سياسة الخصوصية](https://munyati.co/privacy) لمعرفة ما نحتفظ به.

## 11. حدود المسؤولية

نقدّم المنصة «كما هي». بالقدر الذي يسمح به النظام، لا تتحمّل منيتي مسؤولية الخدمات المقدّمة بين المستخدمين أو المبالغ المحوّلة بينهم أو أي خسارة غير مباشرة، مع بقاء مسؤوليتنا عمّا نقدّمه نحن.

## 12. النظام المطبّق والتعديلات

تخضع هذه الشروط لأنظمة المملكة العربية السعودية، ومنها نظام التجارة الإلكترونية. قد نعدّل الشروط وننشر النسخة الجديدة هنا، ويعني استمرارك في الاستخدام بعد التعديل موافقتك عليه.

## 13. التواصل

contact@munyati.co$md$),

('terms', 'en', 'Terms of use', $md$Last updated: 16 October 2026

By using the Munyati app or munyati.co you agree to these terms. Munyati is operated by [company name as in the commercial registration], CR no. [number].

## 1. What Munyati does

Munyati is an online platform that connects brides with wedding service providers. **Munyati is not a party to the service agreement**, doesn't provide the services itself, **and never receives or holds booking payments**: the bride pays the provider directly. Each provider is responsible for their service, its quality and the accuracy of what they publish.

## 2. Your account

- You must be 18 or over and use a Saudi mobile number that belongs to you.
- You're responsible for the accuracy of your details and for everything done through your account.
- You can browse as a guest; you need to sign in to book, save favorites, review or report.

## 3. Booking

- The bride sends a request for an available slot; the provider can accept it, decline it or propose another time.
- A request that isn't answered within 48 hours expires, and a proposed time that isn't answered within 24 hours expires. These periods may change; the app shows the ones that apply.
- A bride can have only one active booking per category until it's completed or cancelled.

## 4. Payment and receipts

- Once the request is accepted, the bride transfers **the full amount** to the provider using one of the payment methods shown in the booking, writes the booking code in the transfer note and uploads the receipt within 48 hours, or the booking expires.
- The provider confirms the money arrived in their account, or rejects the receipt with a reason. If they don't respond within 48 hours, the booking goes to the Munyati team.
- Uploading a fake or reused receipt, or denying a payment that was actually received, is fraud: the account is suspended immediately and we may report it to the authorities.

## 5. Cancellations and refunds

- Either party can cancel a booking in the app, as allowed at each stage.
- Refunds of amounts paid follow the agreement between the bride and the provider and the cancellation policy shown on the service page. Refunds go directly from the provider to the bride, with a receipt.
- If a provider cancels a paid booking or doesn't deliver the service, they must refund the full amount.

## 6. Disputes

Either party can open a dispute on a paid booking and attach evidence. A dispute pauses the booking and its reviews until the Munyati team reviews it. Munyati's decision concerns use of the platform (such as the booking status and account suspensions) and doesn't stop either party from going to the competent authorities.

## 7. Reviews

Reviews are possible only after a booking is completed and must be honest and based on a real experience. We may moderate reviews before publishing them and hide any that break these terms.

## 8. Prohibited use

You may not: commit fraud or impersonate anyone; post offensive, indecent or unlawful content; harass or abuse any user; publish other people's photos without their consent; bypass the platform or harm its systems. **We have zero tolerance** for objectionable content and abusive users. You can report and block any content or user in the app, and we review reports within 24 hours.

## 9. Content and ownership

Content you add stays yours, and you give Munyati a non-exclusive permission to show it on the platform and in its promotion. The Munyati name, logo and design belong to us.

## 10. Suspension and deletion

We may suspend any account that breaks these terms or puts users at risk. You can delete your account at any time in the app; see the [privacy policy](https://munyati.co/en/privacy) for what we keep.

## 11. Liability

We provide the platform "as is". As far as the law allows, Munyati isn't liable for services provided between users, money transferred between them, or indirect losses; we remain responsible for what we provide ourselves.

## 12. Governing law and changes

These terms are governed by the laws of the Kingdom of Saudi Arabia, including the E-Commerce Law. We may change them and will post the new version here; continuing to use Munyati after a change means you accept it.

## 13. Contact

contact@munyati.co$md$),

-- ---------------------------------------------------------------------------------------------
-- Provider terms (in addition to the terms of use)
-- ---------------------------------------------------------------------------------------------
('provider-terms', 'ar', 'شروط مقدّمات الخدمة', $md$آخر تحديث: 16 أكتوبر 2026

تنطبق هذه الشروط على مقدّمات الخدمة بالإضافة إلى [الشروط والأحكام](https://munyati.co/terms).

## 1. الانضمام والموافقة

- تقدّمين طلب انضمام يتضمن بيانات النشاط والفئات والمدن ورقم السجل التجاري أو وثيقة العمل الحر.
- لا تظهر خدماتك للعرائس إلا بعد مراجعة فريق منيتي للطلب والموافقة عليه. لنا رفض أي طلب أو طلب مستندات إضافية.
- تقرّين بأن لديك التراخيص النظامية اللازمة لتقديم خدماتك، وبأن كل ما تقدّمينه صحيح.
- يصلك عند التسجيل **طلب تجريبي** من «عروس تجريبية» للتعرّف على طريقة العمل، وهو ليس حجزاً حقيقياً.

## 2. الخدمات والأسعار

- يجب أن تكون أوصاف الخدمات وصورها وأسعارها صحيحة ومحدّثة، وأن يكون السعر المعروض هو المبلغ الكامل المطلوب.
- لا تنشري صور عرائس أو أشخاص إلا بموافقتهم الصريحة.
- عليك توضيح سياسة الإلغاء والاسترداد في وصف الخدمة.

## 3. استلام المبالغ

- أضيفي طرق دفع صحيحة باسم صاحب الحساب الفعلي. لا يمكن تعديل طرق الدفع أثناء وجود دفعة معلّقة، ويتطلب تعديلها التحقق برمز.
- تأكّدي من وصول المبلغ إلى حسابك قبل الضغط على «تم استلام المبلغ في حسابي»، وردّي على الإيصال خلال 48 ساعة.
- أنتِ المسؤولة عن إصدار الفواتير وعن التزاماتك الضريبية والنظامية تجاه المبالغ التي تستلمينها.

## 4. الالتزام بالحجوزات

- قدّمي الخدمة في الموعد المؤكّد وكما هي موصوفة.
- إذا اضطررتِ لإلغاء حجز مدفوع فعليك إعادة المبلغ كاملاً للعروس.
- تكرار الإلغاء أو عدم الحضور أو الشكاوى المثبتة قد يؤدي إلى إخفاء خدماتك أو إيقاف حسابك.

## 5. الاشتراكات

- **فترة تجريبية مجانية لمدة شهرين** تبدأ من تاريخ الموافقة على حسابك، مرة واحدة لكل رقم جوال.
- بعدها تختارين باقة شهرية (عادية أو بلس أو دايموند). تختلف الباقات في عدد الخدمات والمتاجر والصور وترتيب الظهور والإحصاءات، كما هو موضح في صفحة الباقات.
- الدفع عبر بوابة Tap بالسعر الظاهر عند الدفع. **لا يتجدد الاشتراك تلقائياً**؛ نذكّرك قبل انتهائه بـ 14 و7 و3 أيام ويوم واحد.
- الترقية إلى باقة أعلى تبدأ فوراً مع احتساب المتبقي من باقتك الحالية. والانتقال إلى باقة أقل يبدأ بعد انتهاء الباقة الحالية.
- إذا تجاوزت خدماتك حدّ الباقة تُوقف الخدمات الزائدة مؤقتاً ولا تُحذف. وإذا انتهت الفترة التجريبية أو الباقة دون تجديد تُخفى خدماتك حتى تشتركي.
- رسوم الاشتراك غير قابلة للاسترداد بعد بدء الباقة، إلا فيما يوجبه النظام.
- قد نعدّل الباقات وأسعارها، ولا يسري التعديل على باقة مدفوعة قائمة.

## 6. التقييمات

لا يجوز طلب تقييمات مقابل مزايا أو كتابة تقييمات لنفسك. يمكنك الرد على التقييمات بأسلوب لائق، وتقييمك للعروس خاص لا يظهر لها ولا للعموم.

## 7. التواصل

contact@munyati.co$md$),

('provider-terms', 'en', 'Provider terms', $md$Last updated: 16 October 2026

These terms apply to service providers in addition to the [terms of use](https://munyati.co/en/terms).

## 1. Joining and approval

- You submit an application with your business details, categories, cities and commercial registration or freelance certificate number.
- Your services are shown to brides only after the Munyati team reviews and approves your application. We may decline any application or ask for more documents.
- You confirm you hold the licences needed to provide your services and that everything you submit is accurate.
- When you register, you receive a **demo request** from a "demo bride" so you can learn how bookings work. It isn't a real booking.

## 2. Services and prices

- Service descriptions, photos and prices must be accurate and up to date, and the price shown must be the full amount you charge.
- Don't publish photos of brides or other people without their explicit consent.
- State your cancellation and refund policy in the service description.

## 3. Receiving payments

- Add correct payment methods in the real account holder's name. Payment methods can't be changed while a payment is pending, and changing them requires a verification code.
- Make sure the money has reached your account before tapping "I received the amount in my account", and respond to each receipt within 48 hours.
- You're responsible for issuing invoices and for your tax and legal obligations on the money you receive.

## 4. Honouring bookings

- Deliver the service at the confirmed time and as described.
- If you have to cancel a paid booking, you must refund the bride in full.
- Repeated cancellations, no-shows or proven complaints may lead to your services being hidden or your account suspended.

## 5. Subscriptions

- **A two-month free trial** starts on the day your account is approved, once per mobile number.
- After that you choose a monthly plan (Normal, Plus or Diamond). Plans differ in the number of services, stores and photos, search placement and insights, as shown on the plans page.
- You pay through the Tap gateway at the price shown at checkout. **Plans don't renew automatically**; we remind you 14, 7, 3 and 1 days before yours ends.
- Upgrading starts immediately, with credit for what's left of your current plan. Moving to a smaller plan starts after the current plan ends.
- If you have more services than your plan allows, the extra ones are paused, not deleted. If your trial or plan ends without renewal, your services are hidden until you subscribe.
- Subscription fees are non-refundable once the plan has started, except where the law requires a refund.
- We may change plans and prices; changes don't affect a plan you've already paid for.

## 6. Reviews

Don't offer benefits in exchange for reviews or review yourself. You may reply to reviews politely. Your review of a bride is private: neither she nor the public sees it.

## 7. Contact

contact@munyati.co$md$),

-- ---------------------------------------------------------------------------------------------
-- FAQ
-- ---------------------------------------------------------------------------------------------
('faq', 'ar', 'الأسئلة الشائعة', $md$## للعرائس

**هل الحجز عبر منيتي مجاني؟**
نعم، لا تدفع العروس أي رسوم لمنيتي. تدفعين سعر الخدمة فقط لمقدّمة الخدمة مباشرة.

**كيف أدفع؟**
بعد قبول طلبك تظهر لك طرق الدفع الخاصة بمقدّمة الخدمة ورمز الحجز. حوّلي المبلغ كاملاً واكتبي رمز الحجز في ملاحظة التحويل، ثم ارفعي صورة الإيصال من صفحة الحجز.

**هل تستلم منيتي المبلغ؟**
لا. المبلغ يُحوَّل مباشرة إلى مقدّمة الخدمة، ولا نطّلع على حسابك البنكي.

**ماذا لو لم تؤكّد مقدّمة الخدمة استلام المبلغ؟**
إذا لم تردّ خلال 48 ساعة يُحال الحجز إلى فريق منيتي. ويمكنك فتح نزاع من صفحة الحجز في أي وقت.

**لماذا لا أستطيع حجز خدمتين من نفس الفئة؟**
يُسمح بحجز نشط واحد في كل فئة حتى يكتمل أو يُلغى، لحماية مواعيد مقدّمات الخدمة.

**كيف أحذف حسابي؟**
من «حسابي ← حذف الحساب»، أو من [صفحة حذف الحساب](https://munyati.co/delete-account).

## لمقدّمات الخدمة

**كيف أنضم؟**
حمّلي التطبيق واختاري «أنا مقدّمة خدمة» وأكملي طلب الانضمام. نراجع الطلب ونتواصل معك قبل نشر خدماتك.

**ما تكلفة الاشتراك؟**
أول شهرين مجاناً من تاريخ الموافقة، ثم تختارين باقة شهرية. الأسعار الحالية في صفحة الباقات داخل التطبيق.

**هل يتجدد الاشتراك تلقائياً؟**
لا، نذكّرك قبل انتهائه وتجدّدينه بنفسك.

**ما هو الطلب التجريبي؟**
حجز وهمي يصلك عند التسجيل لتجرّبي كل خطوات الحجز. لا يُحتسب في إحصاءاتك.

## الدعم

راسلينا على contact@munyati.co أو افتحي تذكرة من «حسابي ← الدعم».$md$),

('faq', 'en', 'FAQ', $md$## For brides

**Is booking through Munyati free?**
Yes, brides pay Munyati nothing. You pay only the service price, directly to the provider.

**How do I pay?**
Once your request is accepted, you'll see the provider's payment methods and a booking code. Transfer the full amount with the booking code in the transfer note, then upload the receipt from the booking page.

**Does Munyati receive the money?**
No. The money goes directly to the provider, and we never see your bank account.

**What if the provider doesn't confirm my payment?**
If they don't respond within 48 hours, the booking goes to the Munyati team. You can also open a dispute from the booking page at any time.

**Why can't I book two services in the same category?**
You can have one active booking per category until it's completed or cancelled. This protects providers' calendars.

**How do I delete my account?**
From "Profile → Delete account", or the [account deletion page](https://munyati.co/delete-account).

## For providers

**How do I join?**
Download the app, choose "I'm a service provider" and complete the application. We review it and contact you before your services go live.

**How much does it cost?**
The first two months from approval are free; then you choose a monthly plan. Current prices are on the plans page in the app.

**Does my plan renew automatically?**
No. We remind you before it ends and you renew it yourself.

**What is the demo request?**
A sample booking you receive when you register, so you can try every booking step. It doesn't count in your statistics.

## Support

Email contact@munyati.co or open a ticket from "Profile → Support".$md$)

on conflict (slug, lang) do update
  set title = excluded.title, body_markdown = excluded.body_markdown, is_published = true;
