# Paperclip na drugim komputerze — prostsza instalacja i aktualizacje

Instrukcja dla pracy na dwóch komputerach **naprzemiennie**, ze wspólną bazą i plikami w Supabase projektu `paperclip-v1`. Nie uruchamiaj obu instancji jednocześnie.

## TL;DR

Nie trzeba ręcznie klonować repozytorium i wykonywać `pnpm build`. Oficjalny zarządzany instalator pobierze i przygotuje wskazany commit z Twojego forka. Na obu komputerach trzeba zainstalować **ten sam commit** i skonfigurować te same prywatne ustawienia Supabase.

1. Na LAPTOP wybierz commit kodu, który chcesz uruchamiać, i wypchnij go do forka `Marcin-LWB/paperclip`.
2. Na drugim komputerze z Ubuntu WSL zainstaluj Paperclip z dokładnego SHA tego commita. W poleceniu zastąp tekst `SHA_COMMITU` pełnym identyfikatorem, bez nawiasów ostrych:

   ```bash
   npx paperclipai install --repo Marcin-LWB/paperclip --ref SHA_COMMITU
   ```

3. Bezpiecznie przenieś pliki konfiguracyjne z sekcji poniżej.
4. W Ubuntu sprawdź konfigurację i uruchom:

   ```bash
   paperclipai doctor
   paperclipai run
   ```

## 1. Przygotuj drugi komputer

Najprostsza zgodna z LAPTOP konfiguracja to **Ubuntu w WSL 2**. W Ubuntu przygotuj Git, Node.js 24.11 lub nowszy oraz pnpm 9.15.4 (tak jak na LAPTOP). Na LAPTOP użyto Volta; instrukcja instalacji WSL i Volta jest w pliku [20261024-01](20261024-01-Instalacja-Paperclip-LAPTOP-WSL-Supabase.md).

Instalator Paperclip wymaga Node.js 24.11 lub nowszego. Instalacja z `--ref` pobiera wskazany kod i uruchamia jego skrypty instalacji oraz buildu. Używaj wyłącznie własnego, zaufanego forka. Nie musisz samodzielnie utrzymywać kopii repozytorium ani ręcznie uruchamiać buildu.

## 2. Wybierz tę samą wersję kodu

Na komputerze, którego wersja aplikacji ma być wzorcem, sprawdź commit w repozytorium Paperclip:

```bash
cd /home/m-ost/paperclip
git rev-parse HEAD
```

Zanim użyjesz SHA na drugim komputerze, upewnij się, że ten commit jest dostępny w forku `Marcin-LWB/paperclip` na GitHubie. Jeśli zawiera Twoje zmiany, najpierw zrób commit i `Push origin` w GitHub Desktop.

SHA to długi identyfikator commita, np. `785d54636e1c8513ee5503d602daf6a5ee1970d6`. W komendzie instalacyjnej wstaw pełny SHA w miejsce `SHA_COMMITU`. Dzięki temu oba komputery dostaną dokładnie tę samą wersję, nawet jeśli później zmieni się gałąź `master`.

## 3. Zainstaluj Paperclip bez ręcznego klonowania

W terminalu Ubuntu na drugim komputerze wykonaj:

```bash
npx paperclipai install --repo Marcin-LWB/paperclip --ref SHA_COMMITU
```

Instalator może zapytać o zgodę na pobranie kodu z forka i uruchomienie jego skryptów. Potwierdź tylko wtedy, gdy SHA wskazuje sprawdzony commit Twojego repozytorium. Jeśli instalator zapyta o dodanie `~/.local/bin` do `PATH`, zaakceptuj albo wykonaj wyświetloną instrukcję i otwórz nowy terminal Ubuntu.

Sprawdź, czy polecenie jest dostępne:

```bash
paperclipai --version
```

Ta instalacja przechowuje program osobno od ustawień i danych Paperclip. Ponowne zainstalowanie nowego commita nie powinno usuwać katalogu instancji `~/.paperclip/instances/default`.

## 4. Skonfiguruj połączenie z tym samym Supabase

Sama instalacja programu nie zna Twojego projektu Supabase. W Ubuntu na drugim komputerze trzeba bezpiecznie przenieść poniższe cztery pliki z LAPTOP do odpowiadających im ścieżek:

| Plik na LAPTOP | Miejsce na drugim komputerze | Zawartość / zastosowanie |
| --- | --- | --- |
| `/home/m-ost/.paperclip/instances/default/config.json` | `/home/m-ost/.paperclip/instances/default/config.json` | Port, ustawienia instancji oraz ścieżki. |
| `/home/m-ost/.paperclip/instances/default/.env` | `/home/m-ost/.paperclip/instances/default/.env` | Adres i hasło bazy Supabase, klucze Supabase Storage oraz sekrety instancji. |
| `/home/m-ost/.paperclip/instances/default/secrets/master.key` | `/home/m-ost/.paperclip/instances/default/secrets/master.key` | Klucz potrzebny do odszyfrowania sekretów Paperclip zapisanych w Supabase. |
| `/home/m-ost/.paperclip/instances/default/secrets/decision-signing.key` | `/home/m-ost/.paperclip/instances/default/secrets/decision-signing.key` | Klucz weryfikujący podpisane decyzje. |

Przenieś je bezpiecznym, zaszyfrowanym kanałem. **Nie wysyłaj ich przez GitHub, e-mail ani czat.** `.env` zawiera hasła i klucze dostępu. Nie udostępniaj ich osobom trzecim. Przed kopiowaniem na drugim komputerze utwórz katalogi docelowe:

```bash
mkdir -p /home/m-ost/.paperclip/instances/default/secrets
```

Ta tabela zakłada nazwę użytkownika Ubuntu `m-ost`, jak na LAPTOP. Jeśli na drugim komputerze użytkownik Ubuntu ma inną nazwę, popraw w `config.json` ścieżkę do `master.key` na właściwą. Zachowaj prywatne uprawnienia do plików:

```bash
chmod 700 /home/m-ost/.paperclip/instances/default /home/m-ost/.paperclip/instances/default/secrets
chmod 600 /home/m-ost/.paperclip/instances/default/config.json /home/m-ost/.paperclip/instances/default/.env
chmod 600 /home/m-ost/.paperclip/instances/default/secrets/master.key /home/m-ost/.paperclip/instances/default/secrets/decision-signing.key
```

Nie kopiuj katalogu `db/`: współdzielona baza jest w Supabase. Pliki załączników są w Supabase Storage.

## 5. Zaloguj lokalnie Codex i uruchom

Na drugim komputerze trzeba osobno zainstalować i zalogować Codex CLI. Logowanie z LAPTOP nie przenosi się automatycznie:

```bash
npm install -g @openai/codex
codex login
codex login status
```

Potem sprawdź konfigurację Paperclip i uruchom serwer:

```bash
paperclipai doctor
paperclipai run
```

Otwórz adres podany przez program. Przy obecnej konfiguracji instancja LAPTOP używa portu `3301`; jeśli drugi komputer ma ten sam plik `config.json`, użyje tego samego portu lokalnie.

## 6. Jak aktualizować wersję na obu komputerach

Aktualizacja programu nie oznacza tworzenia nowej bazy. Dane firm, agentów i zadań zostają w Supabase. Nowa wersja może jednak uruchomić migracje bazy, więc wykonuj aktualizację świadomie:

1. Zakończ zadania agentów. Gdy aktualny Paperclip nadal działa, utwórz kopię bazy:

   ```bash
   cd /home/m-ost/paperclip
   pnpm paperclipai db:backup
   ```

   To polecenie jest dla obecnego uruchomienia z repozytorium na LAPTOP. Jeśli używasz już zarządzanej instalacji, wykonaj `paperclipai db:backup`. Poczekaj na potwierdzenie, że kopia się udała.
2. Wyłącz Paperclip na obu komputerach.
3. Na komputerze z kodem przygotuj commit aktualizacji i wypchnij go do `origin`.
4. Zapisz pełny SHA nowego commita:

   ```bash
   git rev-parse HEAD
   ```

5. Na każdym komputerze zainstaluj ten sam nowy commit:

   ```bash
   paperclipai install --repo Marcin-LWB/paperclip --ref NOWY_SHA
   ```

   Zastąp `NOWY_SHA` pełnym SHA nowego commita, bez nawiasów ostrych.

6. Sprawdź wersję poleceniem `paperclipai --version`. Uruchom nową wersję na jednym komputerze i sprawdź `paperclipai doctor` oraz `/api/health`.

Ponieważ instalacja jest przypięta do SHA, zwykłe `paperclipai update` nie przesunie jej na nowy commit. Do aktualizacji Twojego forka ponownie użyj `paperclipai install` z nowym SHA. **Po migracji bazy nie uruchamiaj starej wersji kodu na drugim komputerze** — najpierw zainstaluj na nim ten sam nowy SHA.

Używaj Paperclip na komputerach naprzemiennie. Wspólna baza Supabase nie synchronizuje lokalnych katalogów roboczych agentów ani logowania Codex CLI.

## Ważne rozróżnienie

- `~/.paperclip/cli/` — program i jego zainstalowane wersje.
- `~/.paperclip/instances/default/` — konfiguracja instancji, sekrety, logi i lokalne kopie zapasowe.
- Supabase PostgreSQL — wspólne dane firmy i Paperclip.
- Supabase Storage — wspólne załączniki.

Oficjalna dokumentacja: [instalowanie CLI i wskazanie forka/commita](https://docs.paperclip.ing/reference/cli/installation/), [aktualizacje i wycofanie wersji](https://github.com/paperclipai/paperclip/blob/master/doc/INSTALLING.md).
