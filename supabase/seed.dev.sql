-- daniels-scale: development seed. FICTIONAL DATA ONLY.
-- Never put real student names or admin credentials in this repo (minors' PII).
--
-- Admin accounts are NOT seeded here — auth.users rows must be created via the
-- Supabase dashboard or admin API, then linked:
--   1. Create users seondo@scale.dics.kr and sasaeng@scale.dics.kr (password auth).
--   2. insert into public.admins (user_id, display_name, role) values
--        ('<seondo-uuid>', '선도부', 'SEONDO'),
--        ('<sasaeng-uuid>', '사생회', 'SASAENG');
-- The login screen maps typed ID -> "<id>@scale.dics.kr".

-- Point items (spec §32: no invented fixed scores for the first three —
-- admins configure them later from 벌점 항목 관리)
insert into public.point_items (name, type, fixed_points, is_fixed, is_active) values
  ('지각', 'NEGATIVE', null, false, true),
  ('복장불량', 'NEGATIVE', null, false, true),
  ('신발장 미정리', 'NEGATIVE', null, false, true),
  ('선생님 재량 벌점', 'NEGATIVE', null, false, true),
  ('모범 행동', 'POSITIVE', null, false, true);

-- Sample students (spec §32 — fictional)
insert into public.students (name, grade) values
  ('홍길동', 2),
  ('김민지', 1),
  ('이준호', 3),
  ('박서연', 2);
