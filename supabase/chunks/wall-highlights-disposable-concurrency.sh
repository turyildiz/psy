#!/usr/bin/env bash
set -euo pipefail
: "${HIGHLIGHTS_DB:?}"
HOST=${HIGHLIGHTS_HOST:-/tmp/mp4c2-sock}; PORT=${HIGHLIGHTS_PORT:-55442}; USER=${HIGHLIGHTS_USER:-postgres}; ADMIN=${HIGHLIGHTS_ADMIN_USER:-supabase_admin}; LOG_DIR=${HIGHLIGHTS_LOG_DIR:-$(mktemp -d)}; mkdir -p "$LOG_DIR"; ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DB="${HIGHLIGHTS_DB}_highlight_concurrency_$$"
cleanup(){ dropdb -h "$HOST" -p "$PORT" -U "$ADMIN" --if-exists "$DB" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
createdb -h "$HOST" -p "$PORT" -U "$ADMIN" -T "$HIGHLIGHTS_DB" -O "$USER" "$DB"
psql -X -q -v ON_ERROR_STOP=1 -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" <<'SQL'
create or replace function auth.role() returns text language sql stable as $$select auth.jwt()->>'role'$$;
create or replace function public.profile_owner_is_banned(target_profile_id uuid) returns boolean language sql stable security definer set search_path='' as $$select false$$;
create table if not exists public.post_link_blocklist(domain text primary key);
drop index if exists public.profiles_one_per_user_key;
insert into auth.users(id,raw_user_meta_data,email) values ('d4000000-0000-0000-0000-000000000004','{}','concurrency@fixture.test');
insert into private.account_session_active_profiles(session_id,user_id,profile_id)
select 'dd000000-0000-0000-0000-000000000004',user_id,id from public.profiles where user_id='d4000000-0000-0000-0000-000000000004';
insert into public.posts(profile_id,body)
select p.id,'concurrency post '||g from public.profiles p cross join generate_series(1,6) g where p.user_id='d4000000-0000-0000-0000-000000000004';
with chosen as (select id from public.posts where body like 'concurrency post %' order by body limit 4)
update public.posts p set is_highlighted=true from chosen where p.id=chosen.id;
SQL
p5=$(psql -X -At -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "select id from public.posts where body='concurrency post 5'")
p6=$(psql -X -At -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "select id from public.posts where body='concurrency post 6'")
claims='{"sub":"d4000000-0000-0000-0000-000000000004","role":"authenticated","session_id":"dd000000-0000-0000-0000-000000000004"}'
psql -X -q -v ON_ERROR_STOP=1 -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "begin; set local role authenticated; select set_config('request.jwt.claims','$claims',true); select public.toggle_post_highlight('$p5'::uuid,true); select pg_sleep(2); commit" >"$LOG_DIR/concurrency-a.log" 2>&1 &
pid_a=$!
sleep 0.25
set +e
psql -X -q -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "begin; set local role authenticated; select set_config('request.jwt.claims','$claims',true); select public.toggle_post_highlight('$p6'::uuid,true); commit" >"$LOG_DIR/concurrency-b.log" 2>&1
rc_b=$?
wait "$pid_a"; rc_a=$?
set -e
[[ $rc_a -eq 0 && $rc_b -ne 0 ]]
grep -q P0001 "$LOG_DIR/concurrency-b.log"
grep -q 'You can highlight up to 5 posts; unhighlight one first.' "$LOG_DIR/concurrency-b.log"
[[ $(psql -X -At -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c 'select count(*) from public.posts where is_highlighted') == 5 ]]
psql -X -q -v ON_ERROR_STOP=1 -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -f "$ROOT/supabase/chunks/wall-highlights-apply.sql" >"$LOG_DIR/apply-after-use.log"
[[ $(psql -X -At -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c 'select count(*) from public.posts where is_highlighted') == 5 ]]
echo APPLY_AFTER_USE_PRESERVES_HIGHLIGHTS=PASS
echo CONCURRENCY_MAX_FIVE=PASS
