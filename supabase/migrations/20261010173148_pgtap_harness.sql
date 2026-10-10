-- pgTAP helpers. Not part of the API: `tests` is absent from [api].schemas.
-- Trigger tests call use_service_role so they bypass RLS until policies exist.
-- create_user inserts auth.users, so it must run as postgres (the test session).

create schema tests;

revoke all on schema tests from public;

alter default privileges in schema tests revoke execute on functions from public;

-- Profile comes from the handle_new_user trigger. Pass null to authenticate_as
-- for an anon session.
create function tests.create_user(p_email text, p_full_name text default '')
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_id, p_email, jsonb_build_object('full_name', p_full_name));
  return v_id;
end;
$$;

create function tests.authenticate_as(p_user uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_user is null then
    perform set_config('request.jwt.claims', '{}', true);
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('role', 'anon', true);
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Keeps RLS bypass and sets auth.uid() when p_user is not null.
create function tests.use_service_role(p_user uuid default null)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_user is null then
    perform set_config('request.jwt.claims', '{}', true);
    perform set_config('request.jwt.claim.sub', '', true);
  else
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', p_user, 'role', 'service_role')::text,
      true
    );
    perform set_config('request.jwt.claim.sub', p_user::text, true);
  end if;

  perform set_config('role', 'service_role', true);
end;
$$;

revoke all on all functions in schema tests from public;
grant usage on schema tests to service_role;
grant execute on all functions in schema tests to service_role;
