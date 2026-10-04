#!/usr/bin/env bash
set -euo pipefail
DB=postgresql://postgres:postgres@127.0.0.1:54322/postgres
psql "$DB" -v ON_ERROR_STOP=1 -f tests/sql/concurrency_fixture.sql
set +e
psql "$DB" -v ON_ERROR_STOP=1 -c "select public.ta_consume_authoritative_quota('00000000-0000-0000-0000-000000009000','questions',1,'race-a','concurrency')" >/tmp/q1 2>&1 & A=$!
psql "$DB" -v ON_ERROR_STOP=1 -c "select public.ta_consume_authoritative_quota('00000000-0000-0000-0000-000000009000','questions',1,'race-b','concurrency')" >/tmp/q2 2>&1 & B=$!
wait $A; SA=$?; wait $B; SB=$?
set -e
[[ $(( (SA==0) + (SB==0) )) -eq 1 ]] || { cat /tmp/q1 /tmp/q2; exit 1; }
[[ "$(psql "$DB" -Atc "select sum(quantity) from public.usage_events where tenant_id='00000000-0000-0000-0000-000000009000' and metric='questions'")" == 25 ]] || exit 1
echo "CONCURRENCY-I01 PASS"

member_remove() {
  local actor="$1"
  psql "$DB" -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claim.sub','$actor',true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select public.ta_change_membership(
 '00000000-0000-0000-0000-000000009100',
 '$actor','REMOVE',null
);
commit;
SQL
}
set +e
member_remove '00000000-0000-0000-0000-000000009101' >/tmp/m1 2>&1 & M1=$!
member_remove '00000000-0000-0000-0000-000000009102' >/tmp/m2 2>&1 & M2=$!
wait $M1; SM1=$?; wait $M2; SM2=$?
set -e
[[ $(( (SM1==0) + (SM2==0) )) -eq 1 ]] || { cat /tmp/m1 /tmp/m2; echo "CONCURRENCY-I02 winner count mismatch"; exit 1; }
OWNERS=$(psql "$DB" -Atc "select count(*) from public.tenant_memberships where tenant_id='00000000-0000-0000-0000-000000009100' and role='OWNER' and state='ACTIVE'")
[[ "$OWNERS" == 1 ]] || { echo "CONCURRENCY-I02 active owners=$OWNERS"; exit 1; }
echo "CONCURRENCY-I02 PASS"
