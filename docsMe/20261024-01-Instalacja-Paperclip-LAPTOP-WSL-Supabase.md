# Paperclip na LAPTOP i odtworzenie na drugim komputerze

Stan sprawdzony 2026-10-24. Ten dokument dotyczy **maszyny LAPTOP** i drugiej maszyny, która ma korzystać naprzemiennie z tej samej bazy i plików. Nie jest to instrukcja tworzenia nowego projektu Supabase.

## 1. Co faktycznie działa na LAPTOP

- Właściwe środowisko: dystrybucja **Ubuntu w WSL 2**. `wsl --status` pokazuje domyślną dystrybucję `Ubuntu` i WSL w wersji `2`. Nazwa hosta Linux: `LapTop`.
- Właściwy katalog źródłowy: `/home/m-ost/paperclip` w systemie plików Ubuntu. Kopia w `C:\Users\m-ost\Projekty\10_Github\paperclip` służy do pracy z Windows; nie uruchamiać z niej drugiego serwera ani instalacji `node_modules` dla tej instancji.
- Linux: Node 24 i pnpm zgodny z polem `packageManager` w bieżącym `package.json`, zainstalowane przez Volta. Kod źródłowy jest na gałęzi `master`; przed przejściem między komputerami porównaj bieżące rewizje, zamiast polegać na numerze zapisanym w dokumencie.
- `origin`: `https://github.com/Marcin-LWB/paperclip.git` (własny fork); `upstream`: `https://github.com/paperclipai/paperclip.git`; domyślne miejsce push: `origin`.
- Instancja Paperclip: `default`, tryb `local_trusted`, dostęp tylko z `127.0.0.1`, port **3301**. Start z katalogu Linux: `pnpm dev`. W Windows: <http://127.0.0.1:3301/>. Kontrola: <http://127.0.0.1:3301/api/health> zwraca `status: ok`.
- PostgreSQL: projekt Supabase **`paperclip-v1`**, identyfikator `lqkonqpdaragzpuxcedn`, region `eu-west-2`. Adres bazy wskazuje **session pooler, port 5432** (`aws-0-eu-west-2.pooler.supabase.com`). Nie używać portu 6543 bez osobnej konfiguracji trybu transakcyjnego. Działające dane agenta i rozmowy zostały potwierdzone bezpośrednim odczytem tej bazy.
- Pliki/załączniki: prywatny bucket Supabase Storage `paperclip` przez interfejs S3, endpoint `https://lqkonqpdaragzpuxcedn.storage.supabase.co/storage/v1/s3`, region `eu-west-2`, path-style włączony. Zapis i odczyt plików były sprawdzone.
- Agent `Chief` ma adapter `codex_local`, połączenie OpenAI subskrypcją ChatGPT; jego działanie zostało sprawdzone zadaniem testowym. Na nowej maszynie trzeba osobno sprawdzić logowanie lokalnego Codex CLI i połączenie agenta.
- Na dysku LAPTOP pozostała dawna lokalna baza `~/.paperclip/instances/default/db/`; **nie usuwać jej**. Obecny `DATABASE_URL` kieruje aplikację do Supabase. Katalog ten nie jest źródłem aktualnych danych współdzielonych.

## 2. Hasła, klucze i pliki wymagane na drugiej maszynie

Nie ma haseł ani kluczy w tym dokumencie ani w repozytorium. Na LAPTOP prywatna konfiguracja znajduje się w Ubuntu, poza Git:

| Plik | Po co jest potrzebny |
| --- | --- |
| `/home/m-ost/.paperclip/instances/default/config.json` | Port 3301, lokalny tryb dostępu i ścieżki instancji. |
| `/home/m-ost/.paperclip/instances/default/.env` | `DATABASE_URL`, ustawienia S3, klucze S3 i lokalne sekrety podpisujące. Uprawnienia `0600`. |
| `/home/m-ost/.paperclip/instances/default/secrets/master.key` | Odszyfrowanie sekretów zapisanych przez Paperclip w **tej samej** bazie Supabase. Bez odpowiadającego klucza część połączeń/sekretów nie zadziała. |
| `/home/m-ost/.paperclip/instances/default/secrets/decision-signing.key` | Weryfikacja podpisanych decyzji zapisanych w tej instancji. |

Najprościej przenieść te **cztery pliki** zaszyfrowanym kanałem na drugą maszynę, zachowując ich zawartość i uprawnienia. Nie wysyłać ich przez Git, nie wklejać do czatu ani do zgłoszenia. `config.json` zawiera ścieżki `/home/m-ost/...`; poniższa procedura zakłada taką samą nazwę użytkownika Ubuntu: `m-ost`. Jeśli nazwa będzie inna, agent ma poprawić ścieżki w konfiguracji przed uruchomieniem. Nie kopiować katalogu `db/` jako sposobu synchronizacji bazy.

Gdy przeniesienie `.env` nie jest możliwe, dane trzeba pobrać z właściwego konta i projektu Supabase `paperclip-v1`:

1. **Hasło bazy PostgreSQL** — to hasło projektu bazy, a nie hasło logowania do supabase.com, Windows ani hasło użytkownika Ubuntu. Jest częścią `DATABASE_URL` dla użytkownika `postgres.lqkonqpdaragzpuxcedn`. Jeśli nie jest znane, zresetować je w ustawieniach **tego projektu** i uaktualnić `DATABASE_URL` na obu komputerach. Hasło w URL trzeba poprawnie zakodować jako składnik URL.
2. **S3 Access Key ID i Secret Access Key** — para kluczy dostępu do Supabase Storage S3 dla projektu `paperclip-v1`. Sekret może nie być ponownie pokazywany; wtedy utworzyć nową parę i uaktualnić oba komputery. Te klucze mają szeroki dostęp do bucketów projektu, dlatego przechowywać je tylko w prywatnej konfiguracji.
3. **`master.key`** — należy skopiować z LAPTOP; utworzenie nowego klucza nie odszyfruje starych sekretów zapisanych w bazie. Podobnie przenieść `decision-signing.key`.
4. **OpenAI/ChatGPT** — odrębne konto od Supabase. Na LAPTOP połączone jest konto potwierdzone przez użytkownika podczas konfiguracji. Na drugiej maszynie przejść lokalne logowanie Codex i w razie potrzeby odświeżyć połączenie w Paperclip. Nie przenosić kodów urządzenia ani haseł przez ten dokument.

W `.env` na LAPTOP występują klucze: `DATABASE_URL`, `PAPERCLIP_STORAGE_PROVIDER`, `PAPERCLIP_STORAGE_S3_BUCKET`, `PAPERCLIP_STORAGE_S3_ENDPOINT`, `PAPERCLIP_STORAGE_S3_REGION`, `PAPERCLIP_STORAGE_S3_FORCE_PATH_STYLE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `PAPERCLIP_AGENT_JWT_SECRET`, `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET`. Wartości konfiguracji Storage: `s3`, `paperclip`, powyższy endpoint, `eu-west-2`, `true`. `config.json` może nadal mieć zapasowe domyślne ustawienia lokalnej bazy i plików; **zmienne z `.env` są aktywnymi nadpisaniami**. Nie usuwać `DATABASE_URL` ani ustawień S3.

## 3. Odtworzenie na drugim komputerze Windows

### Przygotuj Ubuntu w WSL 2

W PowerShell jako administrator, jeśli WSL/Ubuntu nie jest jeszcze zainstalowane:

```powershell
wsl --install -d Ubuntu
```

Po ewentualnym restarcie utwórz użytkownika Ubuntu `m-ost` i jego **osobne hasło Linux** (służy m.in. do `sudo`, nie jest hasłem Supabase). Sprawdź:

```powershell
wsl --list --verbose
wsl --status
```

Wynik dla `Ubuntu` ma pokazywać `VERSION 2`. Jeśli istniejąca dystrybucja ma wersję 1, zmiana to `wsl --set-version Ubuntu 2`; przy nowej instalacji zwykle nie jest potrzebna. W razie potrzeby ustaw `Ubuntu` jako domyślną dystrybucję przez `wsl --set-default Ubuntu`. Na LAPTOP oba ustawienia są już prawidłowe. [Instrukcja Microsoft WSL](https://learn.microsoft.com/windows/wsl/install).

### Narzędzia i repozytorium — wykonuj wewnątrz Ubuntu

Otwórz `wsl -d Ubuntu`, a następne komendy wykonuj w powłoce **Linux**, nie w PowerShell i nie pod `/mnt/c`:

```bash
sudo apt update
sudo apt install -y git curl ca-certificates build-essential
curl https://get.volta.sh | bash
exec bash -l
volta install node@24
volta install pnpm@9.15.4
node --version
pnpm --version
cd /home/m-ost
git clone https://github.com/Marcin-LWB/paperclip.git
cd paperclip
git remote add upstream https://github.com/paperclipai/paperclip.git
git config remote.pushDefault origin
git rev-parse HEAD
pnpm install --frozen-lockfile
```

Wersja pnpm w poleceniu odpowiada obecnemu `packageManager`; jeśli repozytorium zostało zaktualizowane, odczytaj to pole z `package.json` i użyj podanej tam wersji. Przed uruchomieniem na współdzielonej bazie porównaj wynik `git rev-parse HEAD` z aktualnym wynikiem tej samej komendy na LAPTOP. Jeśli rewizje się różnią, najpierw wyrównaj wersje kodu na obu maszynach i oceń migracje bazy; nie uruchamiaj starszego kodu na nowszym schemacie. Upstream służy do późniejszych aktualizacji, a własne zmiany trafiają do forka `origin`.

Zainstaluj Codex CLI w Ubuntu z oficjalnego pakietu npm:

```bash
npm install -g @openai/codex@latest
codex --version
codex login
codex login status
```

Logowanie `codex login` wymaga działania użytkownika na jego koncie OpenAI. Na LAPTOP było to logowanie ChatGPT, a w zabezpieczeniach konta włączono logowanie kodem urządzenia dla Codex. Nigdy nie podawać kodu urządzenia innej osobie. Jeśli drugi komputer nie ma dostępu do subskrypcji, sprawdzić konto i połączenie w UI Paperclip.

### Przenieś prywatną konfigurację

Zatrzymaj Paperclip na LAPTOP (`cd /home/m-ost/paperclip && pnpm dev:stop`) **po zakończeniu aktywnych zadań agenta**. Bezpiecznie przenieś cztery pliki z tabeli powyżej do identycznych ścieżek na drugiej maszynie. W Ubuntu ustaw prywatne uprawnienia:

```bash
mkdir -p /home/m-ost/.paperclip/instances/default/secrets
chmod 700 /home/m-ost/.paperclip /home/m-ost/.paperclip/instances /home/m-ost/.paperclip/instances/default /home/m-ost/.paperclip/instances/default/secrets
chmod 600 /home/m-ost/.paperclip/instances/default/.env /home/m-ost/.paperclip/instances/default/config.json /home/m-ost/.paperclip/instances/default/secrets/master.key /home/m-ost/.paperclip/instances/default/secrets/decision-signing.key
```

Przed startem sprawdź **bez wypisywania sekretów**, że `.env` ma `DATABASE_URL` kierujący na `aws-0-eu-west-2.pooler.supabase.com:5432`, a Storage używa `s3` i bucketu `paperclip`. Nie korzystaj z projektu Supabase należącego do innego konta.

### Start i test

W Ubuntu:

```bash
cd /home/m-ost/paperclip
pnpm dev
```

Lub później jedną komendą z PowerShell (okno pozostaje otwarte):

```powershell
wsl -d Ubuntu -- bash -lc 'cd /home/m-ost/paperclip && pnpm dev'
```

Otwórz <http://127.0.0.1:3301/>. Sprawdź `/api/health` oraz znane, aktualne dane firmy, agenta i rozmowy z LAPTOP (w dniu sporządzenia dokumentu: `Percept` i `Chief`); to potwierdza, że używasz **wspólnej bazy**, a nie świeżej lokalnej bazy. Otwórz istniejący załącznik i sprawdź odczyt z bucketu; potem wykonaj mały test zapisu, jeśli to potrzebne. Sprawdź `codex login status` i uruchom krótkie, nieinwazyjne zadanie dla agenta, aby potwierdzić rzeczywistą pracę modelu. Jeśli połączenie OpenAI jest nieaktywne, ponownie połącz konto w Paperclip na tej maszynie.

Do zarządzania usługą: `pnpm dev:list`, `pnpm dev:stop`. Współdzielona baza i bucket mają być używane **naprzemiennie**; przed przejściem na drugi komputer zakończ aktywne przebiegi agentów i zatrzymaj poprzednią instancję. Obie maszyny muszą mieć zgodną wersję kodu i migracji.

## 4. Granice synchronizacji i uwagi

- W Supabase PostgreSQL są firmy, agenci, zadania, komentarze/rozmowy prowadzone w zadaniach i metadane. W Supabase Storage są załączniki objęte konfiguracją S3. Historia czatów w samym ChatGPT nie jest kopiowana do tej bazy.
- Lokalnie pozostają repozytorium, `node_modules`, logowanie Codex, katalogi robocze agentów, część sesji/przebiegów i prywatne klucze instancji. Samo podłączenie drugiej maszyny do Supabase nie synchronizuje tych plików. Pracę nad kodem przenoś przez Git; ważne pliki robocze agenta przenoś osobno lub dołączaj jako artefakty/załączniki Paperclip. Długiej rozpoczętej sesji agenta nie zakładać jako przenośnej między komputerami.
- Baza Supabase **nie zastępuje** kopii `master.key`. Bez tego klucza nie da się odczytać zaszyfrowanych sekretów zapisanych w bazie. Zorganizuj osobny, bezpieczny backup bazy, Storage i kluczy; bieżący stan backupu sprawdzaj w `/api/health`.
- Pierwszy nieudany natywny start z Windows napotkał `EPERM` przy symlinku plugin SDK, bo Windows nie miał uprawnienia do symlinków ani trybu deweloperskiego. **WSL 2 rozwiązał to bez zmiany ustawień Windows i bez przeróbek kodu.** Nie wracać do tamtej instalacji Windows przy odtwarzaniu.

Źródła w repozytorium: `doc/DEVELOPING.md` (start i katalog instancji), `doc/DATABASE.md` (Supabase, migracje i klucz master), `doc/connections/AI-CONNECTIONS.md` (lokalne logowanie AI). [Oficjalny przewodnik Volta](https://docs.volta.sh/guide/getting-started) opisuje instalację dla WSL jak dla Linux.
