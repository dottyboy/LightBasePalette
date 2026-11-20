#!/bin/bash
# Privatni Postgres 17 klaster za testove (port 5433, korisnik ta, baza northwind).
# Uporaba: tools/pg_test.sh start|stop|status
D=$HOME/.local/share/typhaccess-pg
B=/usr/lib/postgresql/17/bin
case "$1" in
  start) $B/pg_ctl -D "$D/data" -o "-p 5433 -k $D -c listen_addresses=127.0.0.1" -l "$D/pg.log" -w start ;;
  stop) $B/pg_ctl -D "$D/data" stop ;;
  *) $B/pg_ctl -D "$D/data" status ;;
esac
