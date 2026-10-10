-- Munyati reference data: admin roles, launch cities, categories, default app config and
-- placeholder CMS pages. Idempotent, so it is safe on a project that already has edits:
-- existing rows are left untouched (`on conflict do nothing`).

-- Admin roles and permissions (docs/research/admin-dashboard.md §12.1 d).
insert into public.admin_roles (id, name_ar, name_en) values
  ('owner', 'المالك', 'Owner'),
  ('ops', 'العمليات', 'Operations'),
  ('moderator', 'المراجعة والإشراف', 'Moderator'),
  ('content', 'المحتوى', 'Content'),
  ('marketing', 'التسويق', 'Marketing'),
  ('analyst', 'التحليلات', 'Analyst')
on conflict (id) do nothing;

insert into public.admin_role_permissions (role_id, permission) values
  ('ops', 'providers.review'), ('ops', 'bookings.manage'), ('ops', 'payments.resolve'), ('ops', 'analytics.read'),
  ('moderator', 'providers.review'), ('moderator', 'reviews.moderate'), ('moderator', 'reports.handle'),
  ('content', 'content.edit'),
  ('marketing', 'push.send'), ('marketing', 'sms.send'), ('marketing', 'sms.read'), ('marketing', 'analytics.read'),
  ('analyst', 'analytics.read'), ('analyst', 'audit.read')
on conflict do nothing;

-- Launch cities (decision #1); Khafji is ready but inactive. All editable from the dashboard.
insert into public.cities (id, name_ar, name_en, lat, lng, is_active, sort_order) values
  ('dammam', 'الدمام', 'Dammam', 26.4207, 50.0888, true, 1),
  ('khobar', 'الخبر', 'Khobar', 26.2172, 50.1971, true, 2),
  ('qatif', 'القطيف', 'Qatif', 26.5196, 50.0115, true, 3),
  ('khafji', 'الخفجي', 'Khafji', 28.4392, 48.4913, false, 4)
on conflict (id) do nothing;

-- Categories (docs/research/saudi-market-and-legal.md §1.2): 14 active at launch, the rest
-- seeded inactive. Icons are SF Symbol fallbacks until the dashboard uploads artwork.
insert into public.categories
  (id, name_ar, name_en, icon_symbol, price_hint_ar, price_hint_en, is_active, sort_order, allows_parallel_bookings, is_store_category)
values
  ('makeup', 'خبيرة مكياج', 'Makeup artist', 'paintbrush.pointed', '٣٥٠ – ٣٬٠٠٠ ر.س', 'SAR 350 – 3,000', true, 1, false, false),
  ('hair', 'تسريحات الشعر', 'Hair stylist', 'comb', null, null, true, 2, false, false),
  ('bridal_salon', 'مشاغل وصالونات العرائس', 'Bridal salons', 'sparkles', null, null, true, 3, false, false),
  ('henna', 'نقش الحناء', 'Henna artist', 'hand.raised', '٢٠٠ – ١٬٠٠٠ ر.س', 'SAR 200 – 1,000', true, 4, false, false),
  ('photography', 'مصوّرات', 'Female photographers', 'camera', '١٬٥٠٠ – ٤٠٬٠٠٠ ر.س', 'SAR 1,500 – 40,000', true, 5, false, false),
  ('venues', 'قصور وقاعات الأفراح', 'Wedding halls & venues', 'building.columns', '٦٬٠٠٠ – ٨٠٬٠٠٠ ر.س', 'SAR 6,000 – 80,000', true, 6, false, false),
  ('kosha_decor', 'الكوش والتنسيق', 'Kosha & décor', 'sparkles.rectangle.stack', null, null, true, 7, false, false),
  ('dresses', 'فساتين الزفاف', 'Wedding dresses', 'tshirt', null, null, true, 8, false, true),
  ('cakes_sweets', 'الكيك والحلويات', 'Cakes & sweets', 'birthday.cake', null, null, true, 9, false, true),
  ('coffee_servers', 'القهوجيات والصبابات', 'Coffee & hospitality servers', 'cup.and.saucer', null, null, true, 10, false, false),
  ('zaffa_tagagat', 'الزفة والطقاقات', 'Zaffa & female bands', 'music.note', null, null, true, 11, false, false),
  ('spa_skin', 'السبا والعناية بالبشرة', 'Spa & skincare', 'leaf', null, null, true, 12, false, false),
  ('favors_gifts', 'التوزيعات والهدايا', 'Favors & gifts', 'gift', null, null, true, 13, false, true),
  ('videography', 'تصوير فيديو', 'Videographers', 'video', null, null, true, 14, false, false),
  ('flowers', 'الورود وتنسيق الزهور', 'Flowers', 'camera.macro', null, null, false, 15, false, true),
  ('evening_abayas', 'فساتين السهرة والعبايات', 'Evening dresses & abayas', 'hanger', null, null, false, 16, false, true),
  ('catering', 'البوفيه والضيافة', 'Catering & buffet', 'fork.knife', null, null, false, 17, false, false),
  ('dj_sound', 'دي جي وصوتيات', 'DJ & sound', 'speaker.wave.2', null, null, false, 18, false, false),
  ('nails_lashes', 'الأظافر والرموش', 'Nails & lashes', 'hand.point.up', null, null, false, 19, false, false),
  ('perfume_bakhoor', 'العطور والبخور', 'Perfumes & bakhoor', 'drop', null, null, false, 20, false, true),
  ('invitations', 'الدعوات والبطاقات', 'Invitations', 'envelope.open', null, null, false, 21, false, true),
  ('trousseau', 'جهاز العروس', 'Bridal trousseau', 'bag', null, null, false, 22, false, true),
  ('planner', 'منسقة حفلات', 'Wedding planner', 'list.clipboard', null, null, false, 23, false, false),
  ('packages', 'باقات العروس', 'Bridal packages', 'shippingbox', null, null, false, 24, false, false),
  ('jewelry_rental', 'تأجير المجوهرات والإكسسوارات', 'Jewelry & accessory rental', 'crown', null, null, false, 25, false, true)
on conflict (id) do nothing;

-- Default remote config. Shape matches the app's RemoteConfigDTO (snake_case keys) plus
-- Munyati settings: trial length (decision #23) and booking timeouts in hours (decision #8).
insert into public.app_config (id, config) values (1, jsonb_build_object(
  'branding', jsonb_build_object('app_name', 'Munyati', 'logo_url', null,
                                 'primary_color_hex', '#8A0D3A', 'accent_color_hex', '#DFC389'),
  'feature_flags', jsonb_build_object('guestBrowsing', true, 'maintenanceMode', false),
  'enabled_modules', '[]'::jsonb,
  'supported_languages', jsonb_build_array('ar', 'en'),
  'supported_currencies', jsonb_build_array('SAR'),
  'regions', '[]'::jsonb,
  'cities', '[]'::jsonb,
  'social_links', '{}'::jsonb,
  'support', jsonb_build_object(
    'help_center_url', 'https://munyati.co/support',
    'terms_url', 'https://munyati.co/terms',
    'privacy_policy_url', 'https://munyati.co/privacy',
    'contact_methods', jsonb_build_array(jsonb_build_object('id', 'email', 'kind', 'email', 'value', 'contact@munyati.co'))),
  'update', jsonb_build_object('min_required_version', null, 'update_message', null,
                               'force_update', false, 'store_url', null),
  'trial_days', 60,
  'timeouts_hours', jsonb_build_object('request', 48, 'proposal', 24, 'payment', 48, 'receipt_confirmation', 48)
))
on conflict (id) do nothing;

-- Placeholder CMS pages so the app's legal links resolve. Replace from the dashboard with the
-- reviewed texts before launch (docs/PLAN.md §9).
insert into public.cms_pages (slug, lang, title, body_markdown) values
  ('terms', 'ar', 'الشروط والأحكام', 'سيتم نشر الشروط والأحكام هنا قبل الإطلاق.' || chr(10) || chr(10) || 'للاستفسار: contact@munyati.co'),
  ('terms', 'en', 'Terms', 'The terms will be published here before launch.' || chr(10) || chr(10) || 'Questions: contact@munyati.co'),
  ('privacy', 'ar', 'سياسة الخصوصية', 'سيتم نشر سياسة الخصوصية هنا قبل الإطلاق.' || chr(10) || chr(10) || 'للاستفسار: contact@munyati.co'),
  ('privacy', 'en', 'Privacy policy', 'The privacy policy will be published here before launch.' || chr(10) || chr(10) || 'Questions: contact@munyati.co'),
  ('about', 'ar', 'عن منيتي', '# منيتي' || chr(10) || chr(10) || 'كل تجهيزات العروس في مكان واحد: اكتشفي خدمات الزفاف في مدينتك واحجزيها ضمن ميزانيتك.'),
  ('about', 'en', 'About Munyati', '# Munyati' || chr(10) || chr(10) || 'Everything for the bride in one place: discover wedding services in your city and book them within your budget.')
on conflict do nothing;

-- Monthly analytics partitions, when pg_cron is available (Database > Extensions > pg_cron).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('analytics-partitions', '0 3 25 * *',
      $job$select public.ensure_analytics_partition((current_date + interval '1 month')::date)$job$);
  end if;
end;
$$;
