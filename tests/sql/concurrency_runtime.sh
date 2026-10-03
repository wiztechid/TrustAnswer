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
