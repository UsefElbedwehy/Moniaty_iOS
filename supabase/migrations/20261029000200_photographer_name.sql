-- The photographers category is renamed «مصورة فوتو» (photo, beside the separate «تصوير فيديو»).
-- The apps read names from the server, so this shows without an update. Safe to re-run.
update public.categories
set name_ar = 'مصورة فوتو', name_en = 'Photographer'
where id = 'photography';
