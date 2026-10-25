#!/usr/bin/env bash
# Zaczynasz pracę na tym komputerze: sprawdza plik z folderu synchronizowanego,
# robi lokalny backup bezpieczeństwa, potem (do uzupełnienia) odtwarza bazę.
# Użycie: pickup.sh /sciezka/do/folderu-sync
# Skrypt nie był testowany.
set -euo pipefail

SYNC="${1:?Podaj folder synchronizowany}"

[ -f "$SYNC/latest.sql.gz" ] || { echo "Brak $SYNC/latest.sql.gz" >&2; exit 1; }
gzip -t "$SYNC/latest.sql.gz"
echo "Plik z synchronizacji:"
cat "$SYNC/latest.info" 2>/dev/null || echo "(brak latest.info)"
echo "Rozmiar: $(du -h "$SYNC/latest.sql.gz" | cut -f1)"

if curl -fsS --max-time 2 http://localhost:3100/api/health >/dev/null 2>&1 \
   || curl -fsS --max-time 2 http://localhost:3301/api/health >/dev/null 2>&1; then
  echo "Paperclip działa. Zatrzymaj go przed restore." >&2
  exit 1
fi

read -r -p "Odtworzyć bazę z tego pliku? Obecna lokalna baza zostanie zastąpiona. [tak/NIE] " ans
[ "$ans" = "tak" ] || { echo "Przerwano."; exit 1; }

echo "Lokalny backup bezpieczeństwa:"
paperclipai db:backup

# TODO: restore. Opublikowany paperclipai nie ma polecenia CLI do restore.
# Opcje do sprawdzenia (żadna nie była testowana):
#  1) skrypt Node wywołujący runDatabaseRestore z @paperclipai/db
#     (packages/db/src/backup-lib.ts), na połączeniu do lokalnej bazy;
#  2) gunzip -c "$SYNC/latest.sql.gz" | psql "<connection string lokalnej bazy>"
#     (wymaga: sudo apt install postgresql-client).
echo "Restore NIE jest jeszcze zaimplementowany w tym skrypcie." >&2
exit 2
