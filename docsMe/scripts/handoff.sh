#!/usr/bin/env bash
# Kończysz pracę na tym komputerze: backup bazy i kopia do folderu synchronizowanego.
# Użycie: handoff.sh /sciezka/do/folderu-sync
# Wymaga zatrzymanego Paperclip (agenci nie mogą pisać do bazy w trakcie).
# Skrypt nie był testowany.
set -euo pipefail

SYNC="${1:?Podaj folder synchronizowany}"
INST="${PAPERCLIP_INSTANCE_DIR:-$HOME/.paperclip/instances/default}"
BACKUPS="$INST/data/backups"

if curl -fsS --max-time 2 http://localhost:3100/api/health >/dev/null 2>&1 \
   || curl -fsS --max-time 2 http://localhost:3301/api/health >/dev/null 2>&1; then
  echo "Paperclip nadal działa. Zatrzymaj go (Ctrl+C lub paperclipai service stop) i uruchom ponownie skrypt." >&2
  exit 1
fi

mkdir -p "$SYNC"
paperclipai db:backup

LATEST="$(ls -1t "$BACKUPS"/paperclip-*.sql.gz 2>/dev/null | head -n1 || true)"
[ -n "$LATEST" ] || { echo "Nie znaleziono pliku backupu w $BACKUPS" >&2; exit 1; }

gzip -t "$LATEST"   # sprawdza, czy archiwum nie jest uszkodzone
cp -f "$LATEST" "$SYNC/latest.sql.gz.tmp"
mv -f "$SYNC/latest.sql.gz.tmp" "$SYNC/latest.sql.gz"
date -u +"%Y-%m-%dT%H:%M:%SZ $(hostname) $(basename "$LATEST")" > "$SYNC/latest.info"

echo "Gotowe: $SYNC/latest.sql.gz ($(du -h "$SYNC/latest.sql.gz" | cut -f1))"
echo "Poczekaj, aż narzędzie synchronizacji zakończy wysyłanie, zanim zaczniesz pracę na drugim komputerze."
