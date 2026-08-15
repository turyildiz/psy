#!/usr/bin/env bash
set -euo pipefail

# Hash-bound disposable lifecycle for Slice MP4-D. Never point this at a live database.
: "${MP4D_DB:?set MP4D_DB to the disposable fixture database name}"
MP4D_HOST=${MP4D_HOST:-/tmp/mp4c2-sock}
MP4D_PORT=${MP4D_PORT:-55442}
MP4D_USER=${MP4D_USER:-postgres}
MP4D_ADMIN_USER=${MP4D_ADMIN_USER:-supabase_admin}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LOG_DIR=${MP4D_LOG_DIR:-$(mktemp -d)}
mkdir -p "$LOG_DIR"
P=(psql -X -q -v ON_ERROR_STOP=1 -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_USER" -d "$MP4D_DB")
FILES=(
  "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql"
  "$ROOT/supabase/chunks/slice-mp4-d-apply.sql"
  "$ROOT/supabase/chunks/slice-mp4-d-verify.sql"
  "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql"
  "$ROOT/supabase/chunks/slice-mp4-d-disposable-runtime.sql"
  "$ROOT/supabase/chunks/slice-mp4-d-disposable-harness.sh"
)

sha256sum "${FILES[@]}" >"$LOG_DIR/start.sha256"
run_verdict() {
  local file=$1 label=$2 hostile=${3:-no}
  local out="$LOG_DIR/$label.log"
  if [[ $hostile == yes ]]; then
    "${P[@]}" -At -c 'set search_path=pg_catalog' -f "$file" >"$out"
  else
    "${P[@]}" -At -f "$file" >"$out"
  fi
  grep -q '|GO|' "$out"
  printf '%s=GO\n' "$label"
}
fn_xmin() {
  "${P[@]}" -At -F '|' -c "select proname,p.xmin::text,p.ctid::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and proname in ('create_post','update_post','delete_own_post','set_post_reaction','remove_post_reaction') order by proname collate \"C\";"
}
expect_state() {
  local user=$1 db=$2 file=$3 expected=$4 label=$5
  local out="$LOG_DIR/$label.log" rc
  set +e
  psql -X -q -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$user" -d "$db" -f "$file" >"$out" 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
  grep -q "$expected" "$out"
  printf '%s=%s\n' "$label" "$expected"
}

# Exact source -> target -> source, including true no-op and hostile-search-path checks.
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql" >"$LOG_DIR/initial-rollback.log"
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql" preflight-default
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql" preflight-hostile yes
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-apply.sql" >"$LOG_DIR/apply.log"
before=$(fn_xmin)
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-apply.sql" >"$LOG_DIR/apply-noop.log"
[[ $before == "$(fn_xmin)" ]]
printf 'APPLY_NOOP=PASS\n'
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-verify.sql" verify-default
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-verify.sql" verify-hostile yes
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-disposable-runtime.sql" >"$LOG_DIR/runtime.log"
grep -q 'MP4D_BEHAVIOR=PASS' "$LOG_DIR/runtime.log"
printf 'RUNTIME_MATRIX=PASS\n'

# Target-state drift and wrong-owner negative controls.
target_drift_db="${MP4D_DB}_mp4d_target_drift_$$"
dropdb -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" --if-exists "$target_drift_db" >/dev/null
createdb -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" -T "$MP4D_DB" -O "$MP4D_USER" "$target_drift_db"
psql -X -q -v ON_ERROR_STOP=1 -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" -d "$target_drift_db" -c 'alter function public.create_post(uuid,text,text[],boolean) owner to supabase_admin' >/dev/null
expect_state "$MP4D_USER" "$target_drift_db" "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql" 55000 target-drift-refused
dropdb -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" "$target_drift_db"
expect_state "$MP4D_ADMIN_USER" "$MP4D_DB" "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql" 42501 target-wrong-owner-refused

"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql" >"$LOG_DIR/rollback.log"
before=$(fn_xmin)
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql" >"$LOG_DIR/rollback-noop.log"
[[ $before == "$(fn_xmin)" ]]
printf 'ROLLBACK_NOOP=PASS\n'
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql" restored-default
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql" restored-hostile yes

# Source-state drift and wrong-owner negative controls.
source_drift_db="${MP4D_DB}_mp4d_source_drift_$$"
dropdb -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" --if-exists "$source_drift_db" >/dev/null
createdb -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" -T "$MP4D_DB" -O "$MP4D_USER" "$source_drift_db"
psql -X -q -v ON_ERROR_STOP=1 -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" -d "$source_drift_db" -c 'alter function public.create_post(uuid,text,text[],boolean) owner to supabase_admin' >/dev/null
expect_state "$MP4D_USER" "$source_drift_db" "$ROOT/supabase/chunks/slice-mp4-d-apply.sql" 55000 source-drift-refused
dropdb -h "$MP4D_HOST" -p "$MP4D_PORT" -U "$MP4D_ADMIN_USER" "$source_drift_db"
expect_state "$MP4D_ADMIN_USER" "$MP4D_DB" "$ROOT/supabase/chunks/slice-mp4-d-apply.sql" 42501 source-wrong-owner-refused

# Second bound lifecycle guards against one-pass state leakage.
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-apply.sql" >"$LOG_DIR/second-apply.log"
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-verify.sql" second-verify-default
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-verify.sql" second-verify-hostile yes
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-d-rollback.sql" >"$LOG_DIR/final-rollback.log"
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql" final-restored-default
run_verdict "$ROOT/supabase/chunks/slice-mp4-d-preflight.sql" final-restored-hostile yes
sha256sum "${FILES[@]}" >"$LOG_DIR/end.sha256"
cmp "$LOG_DIR/start.sha256" "$LOG_DIR/end.sha256"
printf 'SLICE_MP4_D_BOUND_LIFECYCLE=PASS logs=%s\n' "$LOG_DIR"
