# Krok 7: [Opcjonalnie] Wdrożenie 802.1X z Intel AMT

> [!WARNING]
> Zgodnie z ustaleniami z projektu: Pełne 802.1X PEAP-MSCHAPv2 z certyfikatami EAP-TLS dla samej komunikacji środowiska sprzętowego **jest opcjonalne na ten moment**. W tym trybie priorytetowe jest podnoszenie stacji po Remote Desktop po zawieszeniu (urządzenie włączone), i wybudzanie na w pełni czystym Ethernecie. Postępuj w ramach tego poradnika, jeżeli zdecydujesz się na wdrażanie tego kroku (gdy np. stacja po kablu w Port Security odmówi podniesienia przez serwer DHCP z portu przełącznika z powodu spania AMT). 

Jeżeli chcesz skorzystać ze startowania stacji całkowicie wyłączonej z poziomu vPro (Wake from S5 state), a sieć Twoja (switche warstwy 2/3) blokują ruch sieciowy przed uwierzytelnieniem 802.1X - ten krok jest dla Ciebie. 

## 1. Uwierzytelnienie sprzętowe jako oddzielne "Konto Sieciowe"
AMT gdy jest stacją "Uśpioną", a zasilacz w obudowie komputera podaje tylko stan prądowy niski (Standby), posługuje się własną macówką (często tą samą wspólną warstwy zintegrowanej dla Windowsa) i własnym mikrokontrolerem sieciowym. Musisz stworzyć dla każdej floty maszyn (lub odseparowanych serwerów OOB) włączających się dedykowane konto domenowe AD na którym te mikrokontrolery "wpuszczą się" do sieci z wyłączonym OS'em. 

1. Zaloguj się w `spi.lab` i wejdź do Active Directory Users and Computers (ADUC). 
2. Załóż Service Account, np. `svc-amt-8021x@spi.lab` i zahasłuj bezwygaszającym się, mocnym hasłem. Będzie to "Konto wspólne" z ramienia maszyn vPro logujących się do switchy.

## 2. Podpięcie Polityki 802.1x na Switchu/Routerze do konta w NPS
Twój PEAP na 802.1X opiera się teraz o kontroler NPS z Twojej infrastruktury serwerowej:
1. W Serwerze Windowsa na roli **Network Policy Server (NPS)** utwórz i wyodrębnij polisy tak, by PEAP w protokołach był otwarty i weryfikowany o utworzoną grupę do której wpiszesz to konto ze środowiska AD. 
2. Przepuść profil serwisu NPS pod `Client / Radius / 802.1X` odpowiednią regułą w zaporach Switcha, aby po odpytaniu tego mac-adresu (uśpionej stacji z uruchomionym vPro/AMT) i konta, autentykator przepuścił ten pakiet po EAP-Response.

## 3. Konfiguracja PEAP na profilu ACM w Intel EMA
Samo urządzenie OOB musi dostać to konto by móc je propagować do Twoich węzłów i przełączników:

1. Przejdź w serwerze EMA w przeglądarce pod **Endpoint Groups**. 
2. Edytuj profil `Desktop-vPro-ACM`. 
3. Podczas przesuwania okien konfiguracji znajdź sekcję o nazwie: **Intel AMT Network Properties**. Tam widnieją zakładki do profili bezprzewodowych oraz konfiguracji dla polityki **802.1X Settings**. 
4. Odznacz domyślne braki konfiguracji i dopisz protokół jako `PEAPv0/EAP-MSCHAPv2`. 
5. Podaj w polu użytkownika nazwę: `svc-amt-8021x`. Wklej tam Twoje super tajne hasło do serwisu. W konfiguracji w systemie podaj odwołanie do roota certyfikatu (np. wcześniej dodany Provisioning) lub "Trust Any CA" (niezalecane, ale przyspiesza debbug).
6. Po zapisaniu profilu upewnij się o wyeksportowaniu ustawień i uaktualnieniu profilu we wszystkich stacjach agentów (Update Configuration z poziomu Endpointów serwera web).

### Weryfikacja:
Zamknij system. Połóż stację. Uderz z serwera w power-up Remote OOB i posłuchaj logów po stronie Switcha w radiusie / eapie, czy maszyna została "wciagnięta" po mac-adresie z profilem `svc-amt-8021x` i przepuszczona przez port jako stan "Up / Auth". Jeżeli odpytywanie serwera nie widzi stacji w zgaszonym komputerze - 802.1X blokuje Ci port przed uwarunkowaniami Radius / Switch, prawdopodobnie blokując certyfikat, lub PEAP zgłosił błąd hasła. W tym trybie logi przełączników Cisco / HP mogą być koniecznością z włączonym sys-logiem na `debug`.
