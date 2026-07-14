# ============================================================================
# Plik konfiguracyjny wdrożenia Intel EMA
# Wszystkie skrypty wdrożeniowe odwołują się do tego pliku
# Zmodyfikuj wartości poniżej zgodnie z wymaganiami środowiska
# ============================================================================

@{
    # ========================================================================
    # Konfiguracja domeny Active Directory
    # ========================================================================
    Domain = @{
        # Pełna nazwa domeny (FQDN)
        Name            = 'ema.local'
        # Nazwa NetBIOS domeny
        NetBIOSName     = 'EMA'
        # Poziom funkcjonalności lasu i domeny
        ForestMode      = 'WinThreshold'
        DomainMode      = 'WinThreshold'
        # Ścieżka bazy danych NTDS
        DatabasePath    = 'C:\Windows\NTDS'
        # Ścieżka logów NTDS
        LogPath         = 'C:\Windows\NTDS'
        # Ścieżka SYSVOL
        SysvolPath      = 'C:\Windows\SYSVOL'
    }

    # ========================================================================
    # Konfiguracja sieci
    # ========================================================================
    Network = @{
        # Adres IP kontrolera domeny / serwera EMA
        ServerIP        = '192.168.1.10'
        # Maska podsieci
        SubnetMask      = '255.255.255.0'
        # Prefiks podsieci (CIDR)
        SubnetPrefix    = 24
        # Brama domyślna
        Gateway         = '192.168.1.1'
        # Identyfikator podsieci
        SubnetID        = '192.168.1.0'
        # Sufiks DNS
        DnsSuffix       = 'ema.local'
    }

    # ========================================================================
    # Konfiguracja DHCP
    # ========================================================================
    DHCP = @{
        # Nazwa zakresu DHCP
        ScopeName       = 'Siec-EMA'
        # Opis zakresu
        ScopeDescription = 'Zakres DHCP dla sieci wdrożenia Intel EMA'
        # Początek zakresu adresów IP
        StartRange      = '192.168.1.100'
        # Koniec zakresu adresów IP
        EndRange        = '192.168.1.200'
        # Czas dzierżawy (w dniach)
        LeaseDuration   = 8
        # Adresy IP do wykluczenia z zakresu (np. serwery, drukarki)
        Exclusions      = @(
            @{ Start = '192.168.1.150'; End = '192.168.1.160' }
        )
        # Szablon rezerwacji DHCP dla stacji AMT
        Reservations    = @(
            @{
                Name        = 'AMT-PC-001'
                IPAddress   = '192.168.1.50'
                MACAddress  = '00-00-00-00-00-01'
                Description = 'Stacja robocza AMT nr 1'
            }
            @{
                Name        = 'AMT-PC-002'
                IPAddress   = '192.168.1.51'
                MACAddress  = '00-00-00-00-00-02'
                Description = 'Stacja robocza AMT nr 2'
            }
        )
        # Opcje DHCP
        Options = @{
            # Opcja 6 - Serwer DNS
            DnsServer   = '192.168.1.10'
            # Opcja 3 - Brama domyślna
            Router      = '192.168.1.1'
            # Opcja 15 - Sufiks DNS (nazwa domeny)
            DnsSuffix   = 'ema.local'
        }
    }

    # ========================================================================
    # Struktura jednostek organizacyjnych (OU)
    # ========================================================================
    OUStructure = @{
        # Bazowa OU dla wdrożenia EMA
        BaseOU              = 'OU=Intel-EMA,DC=ema,DC=local'
        # OU dla komputerów zarządzanych przez AMT
        ComputersOU         = 'OU=Komputery-AMT,OU=Intel-EMA,DC=ema,DC=local'
        # OU dla kont serwisowych
        ServiceAccountsOU   = 'OU=Konta-Serwisowe,OU=Intel-EMA,DC=ema,DC=local'
        # OU dla grup zabezpieczeń
        SecurityGroupsOU    = 'OU=Grupy-Zabezpieczen,OU=Intel-EMA,DC=ema,DC=local'
        # OU dla serwerów EMA
        ServersOU           = 'OU=Serwery-EMA,OU=Intel-EMA,DC=ema,DC=local'
    }

    # ========================================================================
    # Konta serwisowe
    # ========================================================================
    ServiceAccounts = @(
        @{
            Name            = 'svc-ema-server'
            DisplayName     = 'Konto serwisowe EMA Server'
            Description     = 'Konto do uruchamiania usług Intel EMA Server'
            PasswordLength  = 24
        }
        @{
            Name            = 'svc-ema-agent'
            DisplayName     = 'Konto serwisowe EMA Agent'
            Description     = 'Konto do wdrażania agentów EMA na stacjach'
            PasswordLength  = 24
        }
        @{
            Name            = 'svc-amt-provision'
            DisplayName     = 'Konto serwisowe AMT Provisioning'
            Description     = 'Konto do provisioningu AMT na stacjach roboczych'
            PasswordLength  = 24
        }
    )

    # ========================================================================
    # Grupy zabezpieczeń
    # ========================================================================
    SecurityGroups = @(
        @{
            Name        = 'GRP-EMA-Admins'
            Description = 'Administratorzy platformy Intel EMA'
            Scope       = 'Global'
            Category    = 'Security'
        }
        @{
            Name        = 'GRP-EMA-Operators'
            Description = 'Operatorzy platformy Intel EMA'
            Scope       = 'Global'
            Category    = 'Security'
        }
        @{
            Name        = 'GRP-AMT-Computers'
            Description = 'Komputery z obsługą Intel AMT'
            Scope       = 'Global'
            Category    = 'Security'
        }
        @{
            Name        = 'GRP-EMA-CertEnroll'
            Description = 'Grupa z uprawnieniami do rejestracji certyfikatów EMA'
            Scope       = 'Global'
            Category    = 'Security'
        }
    )

    # ========================================================================
    # Konfiguracja GPO (Group Policy Objects)
    # ========================================================================
    GPO = @{
        # Nazwa GPO do provisioningu AMT
        AMTProvisioningGPO  = 'GPO-AMT-Provisioning'
        # Nazwa GPO dla ustawień zabezpieczeń EMA
        EMASecurityGPO      = 'GPO-EMA-Security'
        # Nazwa GPO do wdrażania agenta EMA
        EMAAgentDeployGPO   = 'GPO-EMA-Agent-Deploy'
    }

    # ========================================================================
    # Konfiguracja ADCS (Active Directory Certificate Services)
    # ========================================================================
    ADCS = @{
        # Nazwa urzędu certyfikacji (CA)
        CAName              = 'EMA-Enterprise-Root-CA'
        # Typ CA (EnterpriseRootCA / EnterpriseSubordinateCA)
        CAType              = 'EnterpriseRootCA'
        # Algorytm kryptograficzny
        CryptoProvider      = 'RSA#Microsoft Software Key Storage Provider'
        # Długość klucza (w bitach)
        KeyLength           = 4096
        # Algorytm skrótu (hash)
        HashAlgorithm       = 'SHA256'
        # Okres ważności certyfikatu CA (w latach)
        ValidityPeriod      = 10
        # Ścieżka bazy danych CA
        DatabaseDirectory   = 'C:\Windows\system32\CertLog'
        # Ścieżka logów CA
        LogDirectory        = 'C:\Windows\system32\CertLog'
    }

    # ========================================================================
    # Szablony certyfikatów
    # ========================================================================
    CertTemplates = @{
        # Szablon certyfikatu dla Intel AMT
        AMT = @{
            Name            = 'Intel-AMT-Certificate'
            DisplayName     = 'Intel AMT Certificate'
            Description     = 'Szablon certyfikatu do provisioningu Intel AMT'
            ValidityYears   = 2
            RenewalDays     = 60
            KeyLength       = 2048
            KeyUsage        = 'DigitalSignature, KeyEncipherment'
            # OID rozszerzenia dla AMT (2.16.840.1.113741.1.2.3)
            AMTOID          = '2.16.840.1.113741.1.2.3'
        }
        # Szablon certyfikatu TLS dla serwera EMA
        EMATLS = @{
            Name            = 'EMA-Server-TLS'
            DisplayName     = 'EMA Server TLS Certificate'
            Description     = 'Szablon certyfikatu TLS dla serwera Intel EMA'
            ValidityYears   = 2
            RenewalDays     = 60
            KeyLength       = 2048
            KeyUsage        = 'DigitalSignature, KeyEncipherment'
            EKU             = '1.3.6.1.5.5.7.3.1'  # Server Authentication
        }
    }

    # ========================================================================
    # Konfiguracja serwera EMA
    # ========================================================================
    EMAServer = @{
        # Ścieżka instalacji EMA
        InstallPath         = 'C:\Program Files\Intel\EMA'
        # Ścieżka do instalatora EMA (dostosuj do środowiska)
        InstallerPath       = 'C:\Instalki\EMA\EMAServerInstaller.msi'
        # Ścieżka do instalatora agenta EMA
        AgentInstallerPath  = 'C:\Instalki\EMA\EMAAgentInstaller.msi'
        # Port HTTPS serwera EMA
        HttpsPort           = 443
        # Port usługi EMA
        ServicePort         = 9971
        # URL serwera EMA
        ServerUrl           = 'https://ema.ema.local'
        # Nazwa instancji SQL Server
        SqlInstance         = '.\SQLEXPRESS'
        # Nazwa bazy danych EMA
        SqlDatabase         = 'IntelEMA'
    }

    # ========================================================================
    # Porty zapory sieciowej
    # ========================================================================
    Firewall = @{
        # Reguły zapory dla usług Intel AMT i EMA
        Rules = @(
            @{
                Name        = 'Intel-AMT-HTTP'
                Port        = 16992
                Protocol    = 'TCP'
                Direction   = 'Inbound'
                Description = 'Intel AMT - komunikacja HTTP (nieszyfrowana)'
            }
            @{
                Name        = 'Intel-AMT-HTTPS'
                Port        = 16993
                Protocol    = 'TCP'
                Direction   = 'Inbound'
                Description = 'Intel AMT - komunikacja HTTPS (szyfrowana TLS)'
            }
            @{
                Name        = 'Intel-AMT-Redirection'
                Port        = 16994
                Protocol    = 'TCP'
                Direction   = 'Inbound'
                Description = 'Intel AMT - przekierowanie IDE/SOL (IDE-R, Serial over LAN)'
            }
            @{
                Name        = 'Intel-AMT-Redirection-TLS'
                Port        = 16995
                Protocol    = 'TCP'
                Direction   = 'Inbound'
                Description = 'Intel AMT - przekierowanie IDE/SOL z szyfrowaniem TLS'
            }
            @{
                Name        = 'Intel-EMA-Service'
                Port        = 9971
                Protocol    = 'TCP'
                Direction   = 'Inbound'
                Description = 'Intel EMA - port usługi serwera EMA'
            }
            @{
                Name        = 'Intel-EMA-HTTPS'
                Port        = 443
                Protocol    = 'TCP'
                Direction   = 'Inbound'
                Description = 'Intel EMA - interfejs webowy HTTPS'
            }
        )
    }

    # ========================================================================
    # Konfiguracja wdrożenia agenta EMA
    # ========================================================================
    AgentDeployment = @{
        # Lista docelowych stacji roboczych (nazwy komputerów lub adresy IP)
        TargetComputers     = @(
            'AMT-PC-001'
            'AMT-PC-002'
        )
        # Ścieżka udziału sieciowego z instalatorem agenta
        NetworkSharePath    = '\\ema\EMA-Deploy$'
        # Lokalny katalog tymczasowy na stacji docelowej
        LocalTempPath       = 'C:\Temp\EMA-Agent'
        # Parametry instalacji cichej agenta
        SilentInstallArgs   = '/quiet /norestart'
        # Timeout instalacji (w sekundach)
        InstallTimeout      = 300
    }

    # ========================================================================
    # Konfiguracja logowania
    # ========================================================================
    Logging = @{
        # Katalog logów wdrożenia
        LogDirectory        = 'C:\Logs\EMA-Deployment'
        # Maksymalny rozmiar pliku logu (w MB)
        MaxLogSizeMB        = 50
        # Czy włączyć szczegółowe logowanie
        VerboseLogging      = $true
    }
}
