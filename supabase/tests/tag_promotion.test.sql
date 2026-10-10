-- Private tags promote when an item becomes company-visible. Service role until RLS policies exist.

begin;
select plan(6);

create temp table fx (
  teacher_a      uuid,
  teacher_b      uuid,
  company_id     uuid,
  template_keep  uuid,
  template_merge uuid,
  note_id        uuid,
  tag_verbs      uuid,
  tag_foreign    uuid,
  tag_private    uuid,
  tag_company    uuid,
  tag_note       uuid
);
grant all on table fx to service_role;

insert into fx (
  teacher_a, teacher_b, company_id, template_keep, template_merge, note_id,
  tag_verbs, tag_foreign, tag_private, tag_company, tag_note
) values (
  tests.create_user('teacher-a-tags@pgtap.panthera.local', 'Teacher A'),
  tests.create_user('teacher-b-tags@pgtap.panthera.local', 'Teacher B'),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid()
);

select tests.use_service_role((select teacher_a from fx));

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Tags Center', false, teacher_a from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, teacher_a, 'teacher'::public.member_role, true from fx
union all
select company_id, teacher_b, 'teacher'::public.member_role, true from fx;

insert into public.exercise_templates (id, company_id, author_id, visibility, description)
select template_keep, company_id, teacher_a, 'private'::public.visibility, 'Keep private, then share' from fx
union all
select template_merge, company_id, teacher_a, 'private'::public.visibility, 'Merge tags on share' from fx;

insert into public.tags (id, company_id, owner_id, visibility, name)
select tag_verbs, company_id, teacher_a, 'private'::public.visibility, 'Verbs' from fx
union all
select tag_foreign, company_id, teacher_b, 'private'::public.visibility, 'Foreign' from fx
union all
select tag_private, company_id, teacher_a, 'private'::public.visibility, 'grammar' from fx
union all
select tag_company, company_id, null::uuid, 'company'::public.visibility, 'Grammar' from fx
union all
select tag_note, company_id, teacher_a, 'private'::public.visibility, 'Nouns' from fx;

insert into public.template_tags (template_id, tag_id, company_id)
select template_keep, tag_verbs, company_id from fx;

select is(
  (select visibility::text from public.tags where id = (select tag_verbs from fx)),
  'private',
  'a private item does not promote its tag'
);

select throws_ok(
  $$ insert into public.template_tags (template_id, tag_id, company_id)
     select template_keep, tag_foreign, company_id from fx $$,
  '42501',
  null,
  'a private tag cannot be attached to another teacher item'
);

update public.exercise_templates
   set visibility = 'company'
 where id = (select template_keep from fx);

select is(
  (select visibility::text from public.tags where id = (select tag_verbs from fx)),
  'company',
  'sharing an item promotes its private tags'
);

insert into public.template_tags (template_id, tag_id, company_id)
select template_merge, tag_private, company_id from fx;

update public.exercise_templates
   set visibility = 'company'
 where id = (select template_merge from fx);

select ok(
  not exists (select 1 from public.tags where id = (select tag_private from fx)),
  'promotion deletes the private tag after a name merge'
);

select is(
  (select tag_id from public.template_tags where template_id = (select template_merge from fx)),
  (select tag_company from fx),
  'the item keeps the existing company tag'
);

insert into public.notes (id, company_id, author_id, visibility, title, body)
select note_id, company_id, teacher_a, 'private'::public.visibility, 'Note', 'Body' from fx;

insert into public.note_tags (note_id, tag_id, company_id)
select note_id, tag_note, company_id from fx;

update public.notes
   set visibility = 'company'
 where id = (select note_id from fx);

select is(
  (select visibility::text from public.tags where id = (select tag_note from fx)),
  'company',
  'sharing a note promotes its private tags'
);

select * from finish();
rollback;
