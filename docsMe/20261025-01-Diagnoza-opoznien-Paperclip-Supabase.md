# Świeża diagnoza powolnego Paperclip — 2026-10-25

Stan: diagnoza w toku, naprawa niepotwierdzona. Czasy z panelu podano w Europe/Warsaw (UTC+2 w chwili pomiarów).

## Środowisko i stan początkowy

- Kod wykonywany w WSL: `/home/m-ost/paperclip`, czysty commit `785d54636e1c8513ee5503d602daf6a5ee1970d6`.
- Node 24.18.0, pnpm 9.15.4, uruchomienie `pnpm --filter @paperclipai/server exec tsx dist/index.js`, port 3301.
- Na początku brak serwera Node i Codex; `/api/health` odrzucało połączenie. Nie przyjęto poprzedniego stanu `starting` za aktualny.
- `.env` instancji wskazuje session pooler `aws-0-eu-west-2.pooler.supabase.com:5432`, brak jawnych zmiennych strojenia puli. Wartości sekretów nie były wypisywane.
- WSL: 9375 MiB dostępnej pamięci, swap 0. To nie jest dowód dotyczący pamięci zdalnej bazy.
- Supabase: właściwy projekt `paperclip-v1`, `lqkonqpdaragzpuxcedn`, eu-west-2, Free / t4g.nano, do 0,5 GB pamięci. Panel odczytano w zalogowanej przeglądarce. Nie użyto projektów z niewłaściwego konta konektora.

## PER-8

- Zadanie `4106c168-55da-4ae0-a587-ec87f6f922b1` pozostaje `in_progress`.
- Ostatni run `e5cf1e82-0055-4746-bb6b-3e59f1ea5c56`: `failed`, `process_lost`, finished 2026-10-24 23:00:04.525 UTC; execution_stage=`preparing`, process_pid i log_ref NULL. Nie doszedł do procesu dostawcy.
- Przy pierwszym odczycie baza zawierała 24 succeeded, 4 failed, 3 cancelled; brak queued/running.
- Run `e4760a21-f387-4f6f-936d-867d7fd8f4f7` ma zapisane `EMAXCONNSESSION`, limit session poolera 15. To potwierdzony dodatkowy problem, nie dowód głównej przyczyny wszystkich opóźnień.
- Rozwiązana akcja recovery `386631cf-6106-4706-9adf-c272f40402d8` zachowuje dowód wcześniejszego niedispatchowanego przebiegu i wskazuje dostarczoną kontynuację e5cf… . Nie uruchomiono duplikatu ani nie zmieniono statusu ręcznie na done.
- Ostatnia odpowiedź agenta nadal błędnie twierdzi, że GitHub capability uniemożliwiło odczyt lokalnych dokumentów. Poprzedni komentarz korygujący jest zapisany. Rzeczywisty poprawny odczyt i zakończenie zadania pozostają do weryfikacji.

## Dowody dotyczące opóźnień

1. Osobny klient postgres.js, przy wyłączonym Paperclip: typowe SELECT 1 około 30–74 ms, nowe połączenie 0,2–1 s; były też 9,7 s oraz timeouty 8–55 s. Połączenie diagnostyczne nie używa puli serwera aplikacji.
2. Zrzuty pg_stat_activity nie wykazały blokujących PID ani oczekiwania na blokady. Większość backendów była idle/ClientRead. To migawki, a nie wykluczenie wszystkich historycznych blokad. pg_stat_database.deadlocks=0.
3. EXPLAIN ANALYZE odczytu 31 heartbeat_runs z sortowaniem: Execution Time 499,479 ms; 17 shared hits, zero shared reads i zero temp blocks. Późniejszy mały odczyt: 0,035 ms wykonania. Zmienność występuje wewnątrz PostgreSQL, nie tylko w kliencie.
4. pg_stat_statements analizowano z userid, dbid, toplevel i queryid. Historyczne maksimum DISCARD ALL 84,28 s; prosty odczyt taska 80,50 s. Te statystyki nie są pomiarem jednego PER-8.
5. Kontrolny test pipeline: jedna sesja, prepare=true, 3 partie po 40 prostych SELECT. max_pipeline=1: 709/633/641 ms; max_pipeline=100: 135/71/72 ms. Nie odtworzono zacięcia pipeline; brak podstaw do przypisania mu przyczyny.
6. TCP podczas zacięć: RTT około 26–43 ms, Send-Q i Recv-Q zero. Oba adresy poolera wykazywały timeouty. TLS z weryfikacją CA/hostname również potrafił utknąć; później oba adresy odpowiadały w około 30 ms na ciepłym połączeniu. TLS nie potwierdził naprawy. Nie zmieniono DATABASE_URL ani portu aplikacji.

## Logi Supabase i metryki — kluczowe ustalenia

Źródła: panel właściwego projektu:
- https://supabase.com/dashboard/project/lqkonqpdaragzpuxcedn/logs
- https://supabase.com/dashboard/project/lqkonqpdaragzpuxcedn/observability/database
- https://supabase.com/dashboard/project/lqkonqpdaragzpuxcedn/advisors/health?id=db_not_reachable

- PostgreSQL 01:03:49: odczyt companies po kluczu głównym trwał 56784,389 ms.
- PostgreSQL 01:07:45: zliczenie native_run_finalizations trwało 27356,239 ms.
- PostgreSQL 01:13:10: odczyt recovery trwał 71221,719 ms. Wiele wpisów statement timeout.
- Supavisor 01:12–01:13: `DbHandler: Authentication timeout after 15000ms`, ECHECKOUTFAILED i ECHECKOUTTIMEOUT. Obejmuje session i transaction mode. Pool checkout 10230 ms.
- PgBouncer 01:16:03: połączenie do własnego PostgreSQL `[::1]:5432` zamknięte z `connect timeout (age=15s)`. Ten odcinek nie przechodzi przez laptop ani Internet klienta.
- CPU report: 96,28%, na wykresie dominuje IOwait. Widoczne liczne wysokie skoki oczekiwania I/O, również po zatrzymaniu Paperclip. Nie należy nazywać tej liczby zużyciem CPU na obliczenia.
- Memory usage około 400,8 MB, Memory commitment 1,36 GB z ostrzeżeniem SEVERE. Sam commitment nie dowodzi OOM ani swap thrash.
- Infrastructure: CPU 87%, memory 65%, baza 62,4 MB, WAL 80 MB, system 170,2 MB, zajęte około 16% dysku. Brak dowodu na pełny dysk.
- Health Advisor: **Database not usable** — `Connection failed at the TCP layer (CONNECT_TIMEOUT) after 5000ms: timeout expired.` To niezależna kontrola Supabase.
- Globalny baner incydentu dotyczy Management API; nie jest samodzielnym dowodem przyczyny awarii PostgreSQL tego projektu: https://status.supabase.com/ .

Wniosek: potwierdzono degradację samej zdalnej instancji bazy, z dominującym oczekiwaniem I/O i timeoutami również wewnątrz infrastruktury Supabase. Zapełnienie puli aplikacji jest co najmniej skutkiem długich operacji/połączeń. Nie ustalono jeszcze, czy podłożem jest presja pamięci/swap, ograniczenia lub awaria storage/hosta. Sam plan Free nie rozstrzyga przyczyny.

## Próby naprawy i aktualny wynik

- Uruchomienie bez zmian: listener 01:09:56, status starting/recovering utrzymywał się; API companies przekraczało 4 s, health około 0,14 s. Pracę zakończono sygnałem SIGTERM, nie restartowano WSL.
- Próba procesowa `DATABASE_POOL_MAX=4`, bez zapisu do .env: start zakończył się o 01:18:01 błędem ECHECKOUTTIMEOUT podczas inspectMigrations, zanim uruchomiono właściwą pulę aplikacji. Nie jest to skuteczna naprawa; nie utrwalono ustawienia.
- Brak zmian kodu, schematu, dostawcy bazy, instalacji, instrukcji agenta i sekretów.
- Nie wykonano ponownego buildu/typecheck/testów kodu: brak zmian aplikacji. Wykonano opisane rzeczywiste próby połączeń, SQL i startu.

## Granice ustaleń i dalsze czynności

Przed nowym przebiegiem agenta trzeba przywrócić stabilne działanie tej samej bazy. Następnie: pomiar API, kolejki i etapów przygotowania adaptera; kontrolowane wznowienie istniejącego zadania z zachowaniem wiadomości; dowód odczytu lokalnych plików oraz właściwego zakończenia. Historyczny run fed8… ma około 147 s od started_at do procesu Codex, ale brak zachowanych szczegółowych pomiarów wszystkich podetapów przygotowania. Nie przypisano całego czasu jednej funkcji bez dowodu.

Logi lokalne: `/home/m-ost/.paperclip/diagnostics/20261025-PER-8/server-fresh-diagnosis.log` i `server-pool4-diagnosis.log`. Certyfikat publiczny użyty wyłącznie w próbie TLS: `supabase-ca.crt`. Skrypty prób są poza repo w katalogu tymczasowym Windows.

Raport pozostaje w docsMe zgodnie z poleceniem użytkownika. Publikacja przez API Paperclip jest obecnie niemożliwa, bo serwer nie może wystartować z niedostępną bazą. Nie oznaczono incydentu ani PER-8 jako naprawionych.
## Weryfikacja po zatwierdzonym restarcie — 2026-10-25 01:27 Europe/Warsaw

Restart potwierdzony przez pg_postmaster_start_time: 2026-10-24T23:24:44.299Z (01:24:44 lokalnie), poprzednio 13:15:35.803Z. Dashboard projektu pokazuje Healthy. Dwie serie po 5 zapytań (prepare false/true): pierwsze połączenie 242/173 ms, kolejne zapytania 31–40 ms, bez błędów. To potwierdza poprawę w krótkim pomiarze, nie gwarantuje trwałości.

Uruchomiono ponownie Paperclip bez zmiany konfiguracji puli, na porcie 3301. Log: /home/m-ost/.paperclip/diagnostics/20261025-PER-8/server-after-restart.log. API companies HTTP 200 w 130 ms (wcześniej przekraczało 4 s); health HTTP 200 w 107 ms, jeszcze status starting/recovering podczas pierwszego pomiaru. PER-8 nadal wymaga osobnej weryfikacji wykonania; nie oznaczono zadania jako naprawionego.

Kolejny odczyt health: status ok, startupRecovery ready od 2026-10-24T23:27:17.975Z (01:27:17 lokalnie). Start aplikacji zakonczony.

## PER-10 i Supabase — pomiar 2026-10-25 ok. 01:31

PER-10 (70c2f128-c60f-4ae3-b3c2-1806c0e8f9b2), run 1bffc389-7910-46ae-952a-ce9ffdea95ee: created 23:28:54.772Z; started 23:29:06.781Z; proces 23:29:57.120Z; komentarz z odpowiedzia 23:30:25.243Z; done 23:30:33.260Z; finished 23:30:41.034Z. Potwierdzono komentarz, done oraz checkoutRunId/executionRunId null. Utworzenie do konca runu 106.262 s; do procesu 62.348 s. ACP handshake 1484 ms, ensure_session 3603 ms, prepare_turn 688 ms, turn (model oraz narzedzia) 35056 ms, sync_back 693 ms. Nie restartowano ani nie powielano wykonania.

Supabase Health Advisor: 0 errors, 0 warnings. Raport bazy pokazuje CPU 27.89%, Memory usage 403.25 MB, commitment 1.42 GB SEVERE (samo commitment nie dowodzi swap/OOM). Czesc wykresow nie zaladowala danych. Probe SQL: po nawiazaniu polaczenia 30–113 ms; pozniejszy activity 871 ms lacznie z nawiazaniem, nastepne SQL 52–53 ms, brak blokujacych PID i deadlocks=0. Odczyt rozbudowanego API runu 0.78–0.84 s, pozniej 3.279 s. Brak dowodu powrotu poprzedniej awarii polaczen; pozostaje narzut startu Paperclip i zmienne czasy API. Nie przypisano calej minuty przygotowania bazie bez szczegolowego trace.