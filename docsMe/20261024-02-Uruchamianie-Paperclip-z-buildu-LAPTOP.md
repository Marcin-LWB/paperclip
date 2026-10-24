# Uruchamianie zbudowanego Paperclip na LAPTOP

## TL;DR — włączanie i wyłączanie

**Włączanie — w PowerShell:**

```powershell
wsl -d Ubuntu -- bash -lc 'cd /home/m-ost/paperclip && pnpm --filter @paperclipai/server exec tsx dist/index.js'
```

Zostaw terminal otwarty i wejdź na <http://127.0.0.1:3301/>.

**Wyłączanie:** poczekaj na koniec zadań agentów, naciśnij **`Ctrl+C`** w tym terminalu. Zamknięcie Chrome nie wyłącza serwera.

**Awaryjnie, bez dostępu do terminala:** `wsl --terminate Ubuntu` w PowerShell — zatrzymuje wszystkie programy w Ubuntu.

Ta instrukcja dotyczy maszyny **LAPTOP** i instalacji źródłowej w **Ubuntu na WSL 2**: `/home/m-ost/paperclip`. Aplikacja używa bazy PostgreSQL i plików w projekcie Supabase `paperclip-v1`; prywatna konfiguracja jest w `/home/m-ost/.paperclip/instances/default/` poza repozytorium. Adres aplikacji to <http://127.0.0.1:3301/>.

## Co pozostaje po wyłączeniu komputera

Build przygotowuje gotowe pliki interfejsu i serwera. Te pliki pozostają na dysku po restarcie Windows. Nie trzeba budować ponownie po dodaniu zadania, agenta, rozmowy, załącznika ani pliku Markdown w `docsMe`.

Proces serwera nie uruchamia się automatycznie po starcie Windows. Po każdym restarcie trzeba uruchomić go poniższą komendą i zostawić otwarte okno terminala. Automatyczny start Windows **nie jest skonfigurowany**.

## Budowanie po aktualizacji kodu aplikacji

Polecenia wykonuj w Ubuntu WSL, w kopii repozytorium znajdującej się w linuxowym `/home/m-ost/paperclip`:

```bash
cd /home/m-ost/paperclip
pnpm build
```

Build całego monorepo może potrwać i zużywa dużo RAM. Na LAPTOP WSL 2 ma w `C:\Users\m-ost\.wslconfig` ustawione `memory=10GB` i `swap=8GB`. Podczas pierwszego buildu przy niższym limicie WSL zawiesił się; po zwiększeniu limitu dokończono build serwera poleceniem `NODE_OPTIONS=--max-old-space-size=7168 pnpm --filter @paperclipai/server build`. Pliki pozostałych pakietów i interfejsu powstały wcześniej. Całe `pnpm build` nie zakończyło się wtedy pomyślnie jako jedna komenda, dlatego po aktualizacji kodu trzeba sprawdzić jego wynik. Sam build nie uruchamia serwera.

Powtarzaj build po zmianie kodu Paperclip lub pobraniu aktualizacji z `origin`/`upstream`. Jeśli zmieniasz tylko `docsMe`, nie trzeba go powtarzać.

## Uruchamianie na co dzień

Najpierw zakończ trwające zadania agentów i zatrzymaj serwer deweloperski, jeśli działa. Nie uruchamiaj równocześnie `pnpm dev` i zbudowanego serwera na porcie 3301.

W Ubuntu:

```bash
cd /home/m-ost/paperclip
pnpm --filter @paperclipai/server exec tsx dist/index.js
```

To samo z PowerShell w Windows:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /home/m-ost/paperclip && pnpm --filter @paperclipai/server exec tsx dist/index.js'
```

W tej kopii źródłowej `tsx` jest potrzebny do odczytu wewnętrznych pakietów monorepo. Samo `pnpm --filter @paperclipai/server start` zakończyło się błędem brakującego `packages/db/src/client.js`; podana powyżej komenda działa z zbudowanym wejściem serwera i zbudowanym interfejsem.

Otwórz <http://127.0.0.1:3301/>. Stan serwera sprawdzisz pod <http://127.0.0.1:3301/api/health> (`status: ok`). Aby zatrzymać serwer uruchomiony w tym oknie, naciśnij `Ctrl+C`. Nie zamykaj okna podczas pracy agentów.

Build zmniejsza liczbę osobnych plików interfejsu pobieranych przy pełnym odświeżeniu strony. Nie usuwa opóźnienia zapytań do bazy Supabase. Jeżeli serwer zgłasza zajęty port 3301, sprawdź aktywny proces przed uruchomieniem kolejnej kopii.

## Wyłączanie Paperclip

Poczekaj, aż Chief i pozostali agenci zakończą aktywne zadania. W terminalu, w którym uruchomiono Paperclip, naciśnij **`Ctrl+C`** i poczekaj na zakończenie procesu. Potem możesz zamknąć terminal.

Zamknięcie karty lub całego Chrome zamyka tylko widok strony. Serwer Paperclip nadal działa w WSL.

Jeśli nie masz dostępu do terminala serwera, możesz awaryjnie zakończyć całe Ubuntu z PowerShell:

```powershell
wsl --terminate Ubuntu
```

To polecenie zatrzymuje Paperclip oraz wszystkie inne programy działające w tej dystrybucji Ubuntu. Używaj go po zakończeniu pracy agentów, gdy zwykłe `Ctrl+C` jest niedostępne.

Wyłączenie serwera nie usuwa buildu ani danych zapisanych w Supabase. Aby wrócić do pracy, wykonaj ponownie komendę z sekcji „Uruchamianie na co dzień”.

## `docsMe` i commity

Tak, można nadal dodawać pliki `.md` w `docsMe` i robić commity. Build i serwer nie blokują Git. Pliki `docsMe` nie wpływają na działanie aplikacji i ich zmiana nie wymaga nowego buildu ani restartu serwera.

Na LAPTOP istnieją **dwie oddzielne kopie repozytorium**:

- Windows: `C:\Users\m-ost\Projekty\10_Github\paperclip` — w niej znajdują się obecne pliki `docsMe` i stąd można je dodać do commita.
- Ubuntu WSL: `/home/m-ost/paperclip` — stąd aplikacja jest budowana i uruchamiana.

Commit w kopii Windows nie pojawi się sam w kopii Ubuntu ani na drugim komputerze. Po wypchnięciu zmiany do własnego forka `origin` trzeba ją pobrać w drugiej kopii. `upstream` jest oficjalnym repozytorium Paperclip; własnych notatek nie wypychaj tam. Nie dodawaj do commita `.env`, haseł, kluczy S3 ani katalogu `~/.paperclip`.

Powiązana instrukcja: [instalacja WSL i Supabase](20261024-01-Instalacja-Paperclip-LAPTOP-WSL-Supabase.md).
