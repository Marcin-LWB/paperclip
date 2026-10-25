#!/usr/bin/env bash
# Kopiuje klucze Paperclip do wskazanego katalogu (np. szyfrowany pendrive).
# Użycie: secrets-backup.sh /sciezka/docelowa
# NIE używaj folderu współdzielonego z backupami bazy ani chmury bez szyfrowania.
# Skrypt nie był testowany.
set -euo pipefail

DEST="${1:?Podaj katalog docelowy}"
INST="${PAPERCLIP_INSTANCE_DIR:-$HOME/.paperclip/instances/default}"

mkdir -p "$DEST"
chmod 700 "$DEST"

for f in secrets/master.key secrets/decision-signing.key config.json; do
  if [ -f "$INST/$f" ]; then
    cp -p "$INST/$f" "$DEST/$(basename "$f")"
    chmod 600 "$DEST/$(basename "$f")"
    echo "OK  $f"
  else
    echo "BRAK $f"
  fi
done
echo "Pominięto .env celowo."
