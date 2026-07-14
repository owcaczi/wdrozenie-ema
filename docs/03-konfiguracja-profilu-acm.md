# Krok 3: Konfiguracja Profilu ACM i Certyfikatu Provisioning

> [!NOTE]
> Tryb Admin Control Mode (ACM) w przeciwieństwie do Client Control Mode (CCM), daje pełne uprawnienia (KVM, Remote Power bez zgody użytkownika). Wymaga on jednak, aby Intel AMT zaufało serwerowi EMA poprzez łańcuch certyfikatów i tzw. **Provisioning Certificate**.

## 1. Wygenerowanie Certyfikatu Provisioning w AD CS

Potrzebujemy certyfikatu wystawionego przez Twoje Enterprise Root CA, w którym zdefiniujemy "Intel AMT" i właściwe OID.

1. Na serwerze certyfikatów otwórz konsolę `certtmpl.msc` (Szablony Certyfikatów).
2. Skopiuj szablon **Serwer sieci Web** (Web Server).
3. W zakładce **Ogólne** (General):
   - Zmień nazwę na `Intel AMT Provisioning`.
4. W zakładce **Rozszerzenia** (Extensions):
   - Edytuj "Zasady aplikacji" (Application Policies).
   - Dodaj nowe OID (Zasady aplikacji -> Nowe):
     - Nazwa: `Intel AMT Provisioning`
     - Identyfikator obiektu (OID): `2.16.840.1.113741.1.2.3`
   - Zatwierdź.
5. W zakładce **Zabezpieczenia** (Security):
   - Nadaj swojemu kontu administratora uprawnienia `Zapis` i `Rejestracja` (Enroll).
6. W zakładce **Nazwa podmiotu** (Subject Name):
   - Pozostaw "Dostarcz we wniosku" (Supply in the request).
7. Zapisz szablon i opublikuj go w konsoli `certsrv.msc` (Urząd certyfikacji -> Szablony certyfikatów -> Nowy -> Szablon certyfikatu do wydania -> wybierz utworzony szablon).

## 2. Wydanie i Eksport Certyfikatu Provisioning

Na stacji z dostępem do domeny `spi.lab`:

1. Otwórz menedżera certyfikatów lokalnego komputera `certlm.msc`.
2. Kliknij prawym przyciskiem myszy na **Osobiste** (Personal) -> Wszystkie zadania -> **Żądaj nowego certyfikatu**.
3. Wybierz szablon `Intel AMT Provisioning`.
4. Kliknij link "Wymagane są dodatkowe informacje...".
5. W zakładce **Podmiot** (Subject):
   - Typ: Niestandardowa nazwa (Common Name) lub Nazwa podmiotu (Subject).
   - Wartość: **Krytyczne:** MUSI to być DNS suffix, którego szuka AMT, na przykład `OU=Intel AMT, O=MojaFirma, CN=spi.lab`. Najważniejsze to obecność domeny jako CN lub domeny głównej certyfikatu zgodnej ze `spi.lab`.
6. Wygeneruj certyfikat.
7. Następnie wyeksportuj ten certyfikat do pliku **.PFX** (zaznaczając "Tak, eksportuj klucz prywatny"). Ustaw hasło dla pliku PFX.

> [!WARNING]
> Ten plik PFX to klucz do królestwa AMT. Przechowuj go bezpiecznie i podaj go tylko w konsoli EMA.

## 3. Import Certyfikatu do Intel EMA

1. Zaloguj się do webowej konsoli Intel EMA.
2. Przejdź do **Settings** (ikona zębatki) -> **Intel AMT Certificates**.
3. Kliknij **Add Certificate**.
4. Wybierz wyeksportowany plik PFX, podaj hasło.
5. Upewnij się, że certyfikat się wczytał, jest oznaczony statusem "Valid" (Ważny) i pokrywa domenę `spi.lab`.

## 4. Konfiguracja Profilu Intel AMT (Endpoint Group)

Teraz stworzymy grupę endpointów i profil ACM.

1. W EMA przejdź do zakładki **Endpoint Groups**.
2. Kliknij **New Endpoint Group**.
3. Podaj nazwę: np. `Desktop-vPro-ACM`.
4. Przejdź kreator:
   - **Group Policy**: Ustaw hasło administratora w EMA (będzie potrzebne do zarządzania i instalacji Agenta).
   - **Intel AMT Auto-Setup**: Ustaw "Enabled".
   - **Activation Method**: Zmień z *Client Control Mode (CCM)* na **Admin Control Mode (ACM)**.
   - **Provisioning Certificate**: Wybierz z listy rozwijanej certyfikat zaimportowany w Kroku 3.
   - **AMT Password**: Zdefiniuj silne hasło, które zostanie zepchnięte do AMT po aktywacji. (Może wygenerować losowe).
   - **CIRA Setup**: Włącz (pozwala na zarządzanie maszynami przez internet z EMA serwera, nawet poza siecią lokalną).
   - **Features**: Włącz **KVM**, **IDE-R**, **SOL** (Serial-Over-LAN), **WebUI** itp., według preferencji.
5. Zapisz profil grupy.

Po zapisaniu profilu upewnij się, że wygenerujesz i pobierzesz **EMA Agent** specyficzny dla tej grupy urządzeń. Instalator Agenta jest podpisany i zawiera informację, do której grupy dołącza stacje robocze.
