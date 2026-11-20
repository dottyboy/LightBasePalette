#!/bin/bash
# Privatni MariaDB za testove (port 3307, samo 127.0.0.1, korisnik ta bez lozinke, baze northwind/nw_built).
# Uporaba: tools/maria_test.sh start|stop|status
D=$HOME/.local/share/typhaccess-maria
R=$D/root/usr
case "$1" in
  start)
    nohup $R/sbin/mariadbd --no-defaults --basedir=$R --datadir=$D/data --port=3307 --bind-address=127.0.0.1 \
      --socket=$D/maria.sock --pid-file=$D/maria.pid --lc-messages-dir=$R/share/mariadb \
      --lower-case-table-names=1 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci > $D/maria.log 2>&1 &
    for i in $(seq 1 30); do /usr/bin/mariadb-admin --no-defaults -uta -S $D/maria.sock ping >/dev/null 2>&1 && { echo started; exit 0; }; sleep 1; done
    echo "failed, see $D/maria.log"; exit 1 ;;
  stop) /usr/bin/mariadb-admin --no-defaults -uta -S $D/maria.sock shutdown ;;
  *) /usr/bin/mariadb-admin --no-defaults -uta -S $D/maria.sock ping ;;
esac
