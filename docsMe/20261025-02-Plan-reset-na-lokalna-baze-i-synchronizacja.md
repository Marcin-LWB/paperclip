# Plan: reset Paperclip na lokalną bazę + synchronizacja między komputerami

Data: 2026-10-25. Dokument jest planem „na wszelki wypadek”. Nic z niego nie zostało jeszcze wykonane.

## Dlaczego

- Diagnoza ([20261025-01](20261025-01-Diagnoza-opoznien-Paperclip-Supabase.md)) wskazała zdalną bazę Supabase (Free, t4g.nano, 0,5 GB RAM, iowait, timeouty) jako przyczynę opóźnień, a nie kod Paperclip ani komputer.
- Agent nie zmieniał kodu aplikacji, więc repo nie jest potrzebne do uruchamiania. Wystarczy instalacja zarządzana.
- Cel: lokalna baza w WSL, bez Supabase, bez własnego forka i builda.

## Fakty sprawdzone w repo

- Instalacja zarządzana (`doc/INSTALLING.md`): kod w `~/.paperclip/cli/`, dane w `~/.paperclip/instances/default/`. Aktualizacja: `paperclipai update`.
- Domyślna baza to wbudowany PostgreSQL (pakiet `embedded-postgres`). Wystarczy nie ustawiać `DATABASE_URL`.
- Backup: `paperclipai db:backup` tworzy **jeden plik** `paperclip-RRRRMMDD-GGMMSS.sql.gz` w `~/.paperclip/instances/default/data/backups/`. Ostatni miał 4,8 MB.
- W kodzie jest `runDatabaseRestore` (`packages/db/src/backup-lib.ts`), ale **nie ma polecenia CLI do restore**. Do odtworzenia potrzebny jest mały skrypt poza repo albo ręczne `psql`.
- Backup NIE zawiera plików lokalnych (załączniki na dysku, workspace) ani `master.key`. Bez `master.key` sekrety z bazy są nieczytelne.

## Sekrety i pliki poza bazą (ważne)

Baza sama nie wystarcza. Poza backupem bazy żyją:

| Plik / miejsce | Po co | Uwagi |
| --- | --- | --- |
| `~/.paperclip/instances/default/secrets/master.key` | odszyfrowanie sekretów zapisanych w bazie (klucze API, tokeny) | bez niego sekrety po restore są bezużyteczne; ten sam plik na obu komputerach |
| `~/.paperclip/instances/default/secrets/decision-signing.key` | weryfikacja podpisanych decyzji | j.w. |
| `~/.paperclip/instances/default/config.json` | port, ścieżki | ścieżka do `master.key` zależy od nazwy użytkownika WSL |
| `~/.paperclip/instances/default/.env` | hasła/adresy Supabase | po przejściu na lokalną bazę **nie przenosić**; nowa instancja ma własny |
| logowanie Codex (`codex login`) | dostęp agentów do modelu | nie przenosi się; logować na każdym komputerze osobno |
| załączniki / workspace na dysku | pliki zadań | poza backupem bazy; synchronizować osobno albo nie polegać na nich |

Zasady:

- Klucze (`*.key`) kopiować **raz**, zaszyfrowanym kanałem (menedżer haseł, szyfrowany pendrive). Nie przez GitHub, e-mail, czat ani folder synchronizowany razem z backupami.
- Backup `.sql.gz` zawiera zaszyfrowane sekrety, ale także całą treść zadań i komentarzy. Folder synchronizowany traktować jako prywatny.
- Po restore sprawdzić na `paperclipai doctor`, czy sekrety się odszyfrowują.
- Sekrety zapisane w Supabase (klucze `SUPABASE_*`, Storage) przestają być potrzebne po migracji. Jeśli któryś klucz API (np. Supabase) był wklejany do czatów lub logów, wymienić go.

## Skrypty (w `docsMe/scripts/`, poza kodem Paperclip)

Nie dotykają repo ani instalacji, więc nie ma konfliktu z upstreamem. **Nie były uruchamiane ani testowane.** Przetestować najpierw na kopii (`~/.paperclip.stare` lub osobny `HOME`).

- `docsMe/scripts/secrets-backup.sh`: jednorazowa kopia kluczy do wskazanego katalogu (np. na pendrive).
- `docsMe/scripts/handoff.sh`: backup bazy i kopia do folderu synchronizowanego jako `latest.sql.gz`.
- `docsMe/scripts/pickup.sh`: sprawdza folder synchronizowany, robi lokalny backup bezpieczeństwa. **Krok restore jest w nim oznaczony jako do uzupełnienia**, bo repo nie ma polecenia CLI do restore (patrz A8).

## Część A. Reset (wykonuje Claude na prośbę)

### A0. Wstępne sprawdzenia

- [ ] `docsMe` skopiowany poza repo (zrobione przez użytkownika).
- [ ] W WSL: `node --version` (potrzeba ≥ 24.11), `which pg_dump psql`.
- [ ] Zdecydować: czy zachować obecne dane z Supabase (firmy, agenci, zadania)? Jeśli NIE, pomiń A1 i A8.

### A1. Zachowanie danych (opcjonalne)

Przy działającym Paperclipie na Supabase:

```bash
cd /home/m-ost/paperclip
pnpm paperclipai db:backup
```

Skopiować poza `~/.paperclip` (np. do `/mnt/c/Users/m-ost/Backup-paperclip/`):

- najnowszy plik z `~/.paperclip/instances/default/data/backups/`
- `~/.paperclip/instances/default/secrets/master.key`
- `~/.paperclip/instances/default/secrets/decision-signing.key`
- `~/.paperclip/instances/default/config.json` (tylko do wglądu; zawiera ustawienia Supabase)
- `.env` NIE kopiować do synchronizowanych folderów (hasła do Supabase).

Pliki z Supabase Storage (załączniki) nie są w backupie bazy. Jeśli są ważne, pobrać je osobno.

### A2. Zatrzymać Paperclip

Ctrl+C w terminalu, w którym działa, lub `paperclipai service stop`, jeśli działa jako usługa.

### A3. Odłożyć stare dane (zamiast kasować)

```bash
mv ~/.paperclip ~/.paperclip.stare
rm -rf /home/m-ost/paperclip
```

Wersja w Windows (`C:\Users\m-ost\Projekty\10_Github\paperclip`) to osobna kopia, można ją usunąć po upewnieniu się, że `docsMe` jest skopiowany. Zatrzymać zadania w tle lub usługi systemowe, które z niej korzystają.

`~/.paperclip.stare` usunąć dopiero po tygodniu poprawnej pracy nowej instancji.

### A4. Instalacja zarządzana

**Wykonano 2026-10-25.** Skrypt `install.sh` ze strony paperclip.ing przekazał do CLI opcję `--no-prompt`, której opublikowany `paperclipai` (2026.1023.0) nie zna (`error: unknown option '--no-prompt'`). Zadziałało bezpośrednie polecenie:

```bash
export PATH=$HOME/.local/bin:$PATH
npx --yes paperclipai@latest install --yes
paperclipai --version
paperclipai onboard --yes
```

`onboard --yes` uruchamia serwer w pierwszym planie i nie kończy się samo. Po starcie `/api/health` zwróciło `status: ok` (tryb `local_trusted`, port 3100).

Położenie: polecenie `~/.local/bin/paperclipai`, program `~/.paperclip/cli/installs/npm/<wersja>`, dane `~/.paperclip/instances/default/`. Z Windows: `\\wsl$\Ubuntu\home\m-ost\.paperclip`. Nie edytować plików bazy (`db/`) z Windows, gdy serwer działa.

W konfiguracji nie ustawiać `DATABASE_URL` (ma zostać wbudowana baza).

### A5. Codex

```bash
npm install -g @openai/codex
codex login
codex login status
```

### A6. Uruchomienie i test

```bash
paperclipai doctor
paperclipai run
curl http://localhost:3100/api/health
```

Port może być inny, sprawdzić wynik `run`. Poprzednia instancja używała 3301.

### A7. Test szybkości

Utworzyć prostego agenta lub zadanie i zmierzyć czas od utworzenia do odpowiedzi. Poprzednio: ok. 106 s na PER-10 po naprawie Supabase (w tym 62 s do startu procesu). Jeśli po przejściu na lokalną bazę nadal są dziesiątki sekund przed startem procesu, to problem jest gdzie indziej (adapter, sieć, Codex) i trzeba osobnej diagnozy.

### A8. Odtworzenie danych (jeśli zachowano w A1)

Do zrobienia przy realizacji: skrypt (poza repo, np. `docsMe/scripts/restore.mjs`) wywołujący `runDatabaseRestore`, albo `psql` na plik `.sql.gz`. Kolejność:

1. Zatrzymać Paperclip.
2. Przywrócić `master.key` i `decision-signing.key` do `~/.paperclip/instances/default/secrets/` (zastąpić wygenerowane, `chmod 600`).
3. Odtworzyć backup do lokalnej bazy.
4. Uruchomić Paperclip i sprawdzić dane.

Ryzyko: backup jest z konkretnej wersji schematu. Restore na nowszej wersji kodu powinien się obyć migracjami, ale należy to sprawdzić na kopii.

## Część B. Synchronizacja między komputerami (na później)

Zasada: **praca naprzemienna, tylko jeden komputer aktywny.** Nie synchronizować katalogu `data/db` (pliki Postgresa) żadnym narzędziem synchronizującym pliki. Synchronizować wyłącznie jeden plik backupu.

### B1. Jednorazowa konfiguracja

- Ten sam kod/wersja Paperclip na obu komputerach (`paperclipai --version`).
- Te same `master.key` i `decision-signing.key` na obu (skopiowane bezpiecznym kanałem, nie przez GitHub ani e-mail).
- Folder synchronizowany (Dropbox/OneDrive/Syncthing), np. `Paperclip-sync/`, z jednym plikiem `latest.sql.gz`. Nie trzymać tam kluczy ani `.env`.
- Zdecydować, gdzie leżą załączniki (storage lokalny na dysku jest poza backupem; trzeba je synchronizować osobno albo nie używać załączników).

### B2. Kończenie pracy na komputerze A (handoff)

1. Zatrzymać agentów i Paperclip.
2. `paperclipai db:backup`.
3. Skopiować najnowszy `.sql.gz` do folderu synchronizowanego jako `latest.sql.gz` (nadpisać).
4. Poczekać, aż synchronizacja się zakończy.

### B3. Rozpoczynanie pracy na komputerze B (pickup)

1. Upewnić się, że A zakończył handoff i plik jest zsynchronizowany.
2. Zatrzymać Paperclip na B, jeśli działał.
3. Zrobić lokalny backup B na wszelki wypadek.
4. Odtworzyć `latest.sql.gz` do pustej lokalnej bazy.
5. Uruchomić Paperclip.

### B4. Do przygotowania (skrypty, poza repo)

- `handoff.sh`: stop, backup, kopia do folderu synchronizowanego.
- `pickup.sh`: sprawdzenie, restore, start.
- Ostrzeżenie w skryptach, jeśli plik `latest` jest starszy niż ostatni lokalny backup (ryzyko rozjechania).

### B5. Ograniczenia i ryzyka

- Jeśli zapomnisz zrobić handoff na A, na B zaczniesz od starego stanu. Dane z A będą osobną gałęzią i nie da się ich łatwo scalić.
- Czas restore rośnie z rozmiarem bazy: dziś sekundy (5 MB), przy ~300 MB szacunkowo kilka–kilkanaście minut. Pomiaru na tym sprzęcie nie wykonano.
- Praca równoległa na dwóch komputerach wymaga wspólnej bazy serwerowej (płatny Supabase lub własny VPS).
- Supabase jako „schowek na plik” działa, ale nie ma przewagi nad folderem synchronizowanym, a darmowe projekty są pauzowane po tygodniu nieaktywności.

## Odwrót

Jeśli nowa instalacja nie działa: `rm -rf ~/.paperclip && mv ~/.paperclip.stare ~/.paperclip`, a kod z forka zainstalować z poprzedniego SHA (`paperclipai install --repo Marcin-LWB/paperclip --ref <SHA>`; poprzedni commit to `785d54636e1c8513ee5503d602daf6a5ee1970d6`).
