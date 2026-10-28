-- The hospitality category (الضيافة, formerly «القهوجيات والصبابات») gets its own icon: a dallah
-- (Arabic coffee pot) drawn into the apps, which `icon_symbol = 'dallah'` selects. An icon uploaded
-- from the dashboard (icon_url) still wins over it. Safe to re-run.
update public.categories
set icon_symbol = 'dallah'
where id = 'coffee_servers' and coalesce(icon_symbol, 'cup.and.saucer') = 'cup.and.saucer';
