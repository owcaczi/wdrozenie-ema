<#
.SYNOPSIS
    Instalacja i konfiguracja roli DHCP Server.

.DESCRIPTION
    Skrypt instaluje rolę DHCP, autoryzuje serwer w Active Directory,
    tworzy zakres adresów, konfiguruje opcje zakresu (w tym opcję 15 - sufiks DNS),
    dodaje wykluczenia i rezerwacje zgodnie z plikiem konfiguracyjnym.

.PARAMETER ConfigPath
    Ścieżka do pliku konfiguracyjnego wdrożenia (deployment-config.psd1).

.PARAMETER SkipAuthorization
    Pomija autoryzację serwera DHCP w Active Directory.

.EXAMPLE
    .\02-Configure-DHCP.ps1

.EXAMPLE
    .\02-Configure-DHCP.ps1 -ConfigPath 'C:\Config\custom-config.psd1'

.NOTES
    Autor:  Administrator
    Wersja: 1.0
    Data:   2026-07-14
    Wymagania: Windows Server 2016+, rola AD DS musi być zainstalowana, uprawnienia administratora
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\..\config\deployment-config.psd1'),

    [Parameter(Mandatory = $false)]
    [switch]$SkipAuthorization
)

# ============================================================================
# Region: Funkcje pomocnicze
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Zapisuje wpis do pliku logu oraz wyświetla komunikat na konsoli.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
    }

    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
    }
}

# ============================================================================
# Region: Główna logika skryptu
# ============================================================================

try {
    # --- Wczytanie konfiguracji ---
    $config = Import-PowerShellDataFile -Path $ConfigPath
    $dhcpConfig = $config.DHCP
    $networkConfig = $config.Network

    # --- Inicjalizacja logowania ---
    $logDir = $config.Logging.LogDirectory
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    $script:LogFile = Join-Path $logDir "02-Configure-DHCP_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    Write-Log -Message '============================================================' -Level INFO
    Write-Log -Message 'Rozpoczęcie instalacji i konfiguracji DHCP Server' -Level INFO
    Write-Log -Message '============================================================' -Level INFO

    # --- Krok 1: Instalacja roli DHCP Server ---
    Write-Log -Message 'Krok 1: Sprawdzanie i instalacja roli DHCP Server...' -Level INFO

    $dhcpFeature = Get-WindowsFeature -Name DHCP
    if ($dhcpFeature.Installed) {
        Write-Log -Message 'Rola DHCP Server jest już zainstalowana.' -Level WARNING
    }
    else {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Instalacja roli DHCP Server')) {
            $installResult = Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop

            if ($installResult.Success) {
                Write-Log -Message 'Rola DHCP Server zainstalowana pomyślnie.' -Level SUCCESS
            }
            else {
                Write-Log -Message "Instalacja roli DHCP nie powiodła się: $($installResult.ExitCode)" -Level ERROR
                exit 1
            }
        }
    }

    # --- Krok 2: Konfiguracja grup zabezpieczeń DHCP ---
    Write-Log -Message 'Krok 2: Konfiguracja grup zabezpieczeń DHCP...' -Level INFO

    try {
        # Dodanie grup lokalnych DHCP (DHCP Administrators, DHCP Users)
        netsh dhcp add securitygroups 2>$null
        Write-Log -Message 'Grupy zabezpieczeń DHCP skonfigurowane.' -Level SUCCESS
    }
    catch {
        Write-Log -Message "Ostrzeżenie podczas konfiguracji grup DHCP: $_" -Level WARNING
    }

    # Ponowne uruchomienie usługi DHCP po dodaniu grup
    Restart-Service -Name DHCPServer -Force -ErrorAction SilentlyContinue
    Write-Log -Message 'Usługa DHCP Server uruchomiona ponownie.' -Level INFO

    # --- Krok 3: Autoryzacja serwera DHCP w Active Directory ---
    if (-not $SkipAuthorization) {
        Write-Log -Message 'Krok 3: Autoryzacja serwera DHCP w Active Directory...' -Level INFO

        try {
            $serverIP = $networkConfig.ServerIP
            $dnsName = "$env:COMPUTERNAME.$($config.Domain.Name)"

            Add-DhcpServerInDC -DnsName $dnsName -IPAddress $serverIP -ErrorAction Stop
            Write-Log -Message "Serwer DHCP '$dnsName' ($serverIP) autoryzowany w AD pomyślnie." -Level SUCCESS
        }
        catch {
            if ($_.Exception.Message -like '*already exists*') {
                Write-Log -Message 'Serwer DHCP jest już autoryzowany w AD.' -Level WARNING
            }
            else {
                Write-Log -Message "Błąd autoryzacji serwera DHCP: $($_.Exception.Message)" -Level ERROR
                throw
            }
        }

        # Wyłączenie powiadomienia o konieczności autoryzacji w Server Manager
        try {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12' -Name 'ConfigurationState' -Value 2 -ErrorAction SilentlyContinue
            Write-Log -Message 'Powiadomienie Server Manager wyłączone.' -Level INFO
        }
        catch {
            Write-Log -Message 'Nie udało się wyłączyć powiadomienia Server Manager (to nie jest błąd krytyczny).' -Level WARNING
        }
    }
    else {
        Write-Log -Message 'Krok 3: Autoryzacja DHCP w AD pominięta (parametr -SkipAuthorization).' -Level WARNING
    }

    # --- Krok 4: Tworzenie zakresu DHCP ---
    Write-Log -Message 'Krok 4: Tworzenie zakresu DHCP...' -Level INFO

    $existingScope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -eq $dhcpConfig.ScopeName }

    if ($existingScope) {
        Write-Log -Message "Zakres '$($dhcpConfig.ScopeName)' już istnieje. Pomijanie tworzenia." -Level WARNING
    }
    else {
        if ($PSCmdlet.ShouldProcess($dhcpConfig.ScopeName, 'Tworzenie zakresu DHCP')) {
            Add-DhcpServerv4Scope `
                -Name $dhcpConfig.ScopeName `
                -Description $dhcpConfig.ScopeDescription `
                -StartRange $dhcpConfig.StartRange `
                -EndRange $dhcpConfig.EndRange `
                -SubnetMask $networkConfig.SubnetMask `
                -LeaseDuration (New-TimeSpan -Days $dhcpConfig.LeaseDuration) `
                -State Active `
                -ErrorAction Stop

            Write-Log -Message "Zakres DHCP '$($dhcpConfig.ScopeName)' utworzony: $($dhcpConfig.StartRange) - $($dhcpConfig.EndRange)" -Level SUCCESS
        }
    }

    # Pobranie identyfikatora zakresu (Scope ID) do dalszej konfiguracji
    $scopeID = $networkConfig.SubnetID

    # --- Krok 5: Konfiguracja opcji zakresu DHCP ---
    Write-Log -Message 'Krok 5: Konfiguracja opcji zakresu DHCP...' -Level INFO

    # Opcja 3 - Router (brama domyślna)
    try {
        Set-DhcpServerv4OptionValue -ScopeId $scopeID -OptionId 3 `
            -Value $dhcpConfig.Options.Router -ErrorAction Stop
        Write-Log -Message "Opcja 3 (Router): $($dhcpConfig.Options.Router)" -Level SUCCESS
    }
    catch {
        Write-Log -Message "Błąd ustawiania opcji 3 (Router): $($_.Exception.Message)" -Level ERROR
    }

    # Opcja 6 - Serwer DNS
    try {
        Set-DhcpServerv4OptionValue -ScopeId $scopeID -OptionId 6 `
            -Value $dhcpConfig.Options.DnsServer -ErrorAction Stop
        Write-Log -Message "Opcja 6 (DNS Server): $($dhcpConfig.Options.DnsServer)" -Level SUCCESS
    }
    catch {
        Write-Log -Message "Błąd ustawiania opcji 6 (DNS): $($_.Exception.Message)" -Level ERROR
    }

    # Opcja 15 - Sufiks DNS (nazwa domeny) - kluczowa dla AMT
    try {
        Set-DhcpServerv4OptionValue -ScopeId $scopeID -OptionId 15 `
            -Value $dhcpConfig.Options.DnsSuffix -ErrorAction Stop
        Write-Log -Message "Opcja 15 (DNS Suffix): $($dhcpConfig.Options.DnsSuffix) - wymagana dla Intel AMT" -Level SUCCESS
    }
    catch {
        Write-Log -Message "Błąd ustawiania opcji 15 (DNS Suffix): $($_.Exception.Message)" -Level ERROR
    }

    # --- Krok 6: Dodawanie wykluczeń z zakresu ---
    Write-Log -Message 'Krok 6: Dodawanie wykluczeń z zakresu DHCP...' -Level INFO

    foreach ($exclusion in $dhcpConfig.Exclusions) {
        try {
            Add-DhcpServerv4ExclusionRange -ScopeId $scopeID `
                -StartRange $exclusion.Start `
                -EndRange $exclusion.End `
                -ErrorAction Stop
            Write-Log -Message "Wykluczenie dodane: $($exclusion.Start) - $($exclusion.End)" -Level SUCCESS
        }
        catch {
            if ($_.Exception.Message -like '*already exists*') {
                Write-Log -Message "Wykluczenie $($exclusion.Start) - $($exclusion.End) już istnieje." -Level WARNING
            }
            else {
                Write-Log -Message "Błąd dodawania wykluczenia: $($_.Exception.Message)" -Level ERROR
            }
        }
    }

    # --- Krok 7: Dodawanie rezerwacji DHCP ---
    Write-Log -Message 'Krok 7: Dodawanie rezerwacji DHCP dla stacji AMT...' -Level INFO

    foreach ($reservation in $dhcpConfig.Reservations) {
        try {
            # Sprawdzenie, czy rezerwacja już istnieje
            $existingRes = Get-DhcpServerv4Reservation -ScopeId $scopeID -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -eq $reservation.IPAddress }

            if ($existingRes) {
                Write-Log -Message "Rezerwacja dla $($reservation.Name) ($($reservation.IPAddress)) już istnieje." -Level WARNING
                continue
            }

            Add-DhcpServerv4Reservation -ScopeId $scopeID `
                -IPAddress $reservation.IPAddress `
                -ClientId ($reservation.MACAddress -replace '-', '') `
                -Name $reservation.Name `
                -Description $reservation.Description `
                -ErrorAction Stop

            Write-Log -Message "Rezerwacja dodana: $($reservation.Name) -> $($reservation.IPAddress) ($($reservation.MACAddress))" -Level SUCCESS
        }
        catch {
            Write-Log -Message "Błąd dodawania rezerwacji '$($reservation.Name)': $($_.Exception.Message)" -Level ERROR
        }
    }

    # --- Krok 8: Włączenie aktualizacji DNS przez DHCP ---
    Write-Log -Message 'Krok 8: Konfiguracja aktualizacji DNS przez DHCP...' -Level INFO

    try {
        Set-DhcpServerv4DnsSetting -ScopeId $scopeID `
            -DynamicUpdates 'Always' `
            -DeleteDnsRROnLeaseExpiry $true `
            -ErrorAction Stop
        Write-Log -Message 'Aktualizacja dynamiczna DNS włączona dla zakresu.' -Level SUCCESS
    }
    catch {
        Write-Log -Message "Błąd konfiguracji aktualizacji DNS: $($_.Exception.Message)" -Level ERROR
    }

    Write-Log -Message 'Konfiguracja DHCP Server zakończona pomyślnie.' -Level SUCCESS
}
catch {
    Write-Log -Message "Wystąpił krytyczny błąd: $($_.Exception.Message)" -Level ERROR
    Write-Log -Message "Szczegóły: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
}
finally {
    Write-Log -Message '============================================================' -Level INFO
    Write-Log -Message 'Zakończenie skryptu konfiguracji DHCP' -Level INFO
    Write-Log -Message "Plik logu: $($script:LogFile)" -Level INFO
    Write-Log -Message '============================================================' -Level INFO
}
