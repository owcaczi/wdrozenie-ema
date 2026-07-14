# Krok 5: Intel EMA Provisioning i Testy Koncowe

Zainstalowałeś certyfikaty, zdefiniowałeś Endpoint Group i przygotowałeś komputery przez wgranie zaufanego hasha Root CA. Czas na wykonanie samego provisioningu ze środowiska Windows.

## 1. Wykonanie Provisioningu Agenta

Dzięki przeniesieniu maszyny vPro do domeny `spi.lab`, nie ma niezgodności domenowej. Możemy zacząć proces zarządzania.

1. Na maszynie docelowej pobierz Agenta EMA przypisanego do wcześniej stworzonej grupy. Zaloguj się w konsoli Intel EMA Server i przejdź do: **Endpoint Groups** -> rozwiń listę grupy `Desktop-vPro-ACM` -> **Install/Deploy Agent**. Zazwyczaj są do pobrania `.exe` dla Windowsa.
2. Zainstaluj EMA Agent na stacji vPro (wymaga praw Administratora).
3. Na serwerze EMA przejdź do zakładki **Endpoints**. Maszyna po chwili powinna pojawić się na liście jako nowa stacja "Connected".

Jeżeli w Endpoint Group miałeś ustawioną opcję "Intel AMT Auto-Setup: Enabled", po zainstalowaniu agenta serwer powinen w ciągu 1-5 minut spróbować "przepchnąć" (provisionować) certyfikaty i podnieść uprawnienia AMT tej stacji do trybu ACM.
- Status AMT powinien zmienić się z **"Pending"** lub "CCM" w pełny tryb **ACM** z opisem "Provisioned".
- Prawidłowe wdrożenie oznacza, że komunikacja szyfrowana 16992/16993 przeszła z sukcesem.

> [!NOTE]
> Jeżeli instalujesz Agenta po raz pierwszy, agent może po 1 minucie samodzielnie podjąć próbę połączenia CIRA/AMT bez ingerencji administratora.

## 2. Test Funkcjonalności: Remote Power

Jeżeli maszyna figuruje jako `ACM` na serwerze EMA:

1. W EMA, przejdź do zakładki **Endpoints**, kliknij na wybraną maszynę.
2. Z głównego panelu, zrób prosty wyłącz komputera "Power Action -> Power Off (Soft lub Hard)".
3. Maszyna zgaśnie. Poczekaj 1-2 minuty upewniając się, że jest totalnie odłączona i stacja jest w stanie S5 (Power Off).
4. Kliknij ponownie z EMA "Power Action -> Power On".
5. Komputer vPro, pomimo wyłączenia systemu operacyjnego, sprzętowo wyśle żądanie podniesienia zasilania z interfejsu sieciowego dzięki AMT. Stacja powinna się włączyć.

## 3. Test Funkcjonalności: KVM (Keyboard, Video, Mouse)

Możliwość dostępu KVM "Over the network" z poziomu BIOS i podczas awarii systemu to potęga AMT ACM.

1. Zamknij lub zatrzymaj krytyczną usługę systemu Windows na stacji vPro (symulacja Blue Screen lub awarii systemu).
2. Przejdź w przeglądarce EMA na stację i kliknij przycisk **KVM** / **Remote Desktop**.
3. Obraz BIOSu lub Błędu Windowsa na ekranie powinien się pojawić pomimo braku aktywnej warstwy RDP z Windowsa. 
4. **Rozdzielczość**: EMA pozwala na podstawowe sterowanie do natywnej wielkości matrycy. Może opóźniać w sieciach zdalnych, w lokalnym Ethernecie (jak Twoim) powinno działać sprawnie (do 30 FPS).
5. Podczas połączenia stacja, o ile wprost nie odblokowano ukrywania tego komunikatu w profilu EMA/AMT, będzie miała w prawym górnym i dolnym brzegu czerwono-żółtą obwódkę informującą zdalnego użytkownika, że administracyjne połączenie KVM jest ustanowione. W ACM nie ma przymusu "pytania" o kod pin, tak jak ma to miejsce w CCM.

## 4. Test Funkcjonalności: IDE-R (CD/ISO redirect)

Ostatnim etapem jest wdrożenie nowego Windowsa z pliku ISO za pomocą EMA.

1. Będąc połączonym w konsoli w oknie terminalu na platformie KVM, przygotuj sobie w konsoli EMA opcję **IDE-R / Storage redirection**.
2. Wskaż dysk twardy ze swoim gotowym obrazem instalatora Windows.
3. Potwierdź proces startowy i wybierz w Power Actions "Restart to IDE-R / Restart to redirected ISO".
4. Maszyna vPro automatycznie powtórnie zbootuje się, omijając lokalny dysk SSD na rzecz napędu CD, z którego odczyta obraz i pozwoli wejść instalatorowi z Twojego pliku iso.
