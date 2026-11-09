<#
  audit-retea.ps1 - audit READ-ONLY al retelei de acasa (Windows PowerShell 5.1+)
  Nu modifica nicio setare. Singura actiune optionala este instalarea nmap (winget),
  si doar daca raspunzi "da" la intrebare.

  Rulare (recomandat ca Administrator, pentru firewall + scanari nmap complete):
    powershell -ExecutionPolicy Bypass -File .\audit-retea.ps1
  Rezultat: audit-retea-<data>.txt pe Desktop.
#>

$ErrorActionPreference = 'Continue'
$Subnet   = '192.168.0'
$Infra    = [ordered]@{ 'Router AX55' = "$Subnet.1"; 'AX53 (cablu)' = "$Subnet.2"; 'RE305 (extender)' = "$Subnet.74" }
$PingCnt  = 100
$Out      = Join-Path ([Environment]::GetFolderPath('Desktop')) ("audit-retea-{0:yyyyMMdd-HHmm}.txt" -f (Get-Date))
$IsAdmin  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function W {
  param([Parameter(ValueFromPipeline=$true)]$o)
  begin { $buf = New-Object System.Collections.Generic.List[object] }
  process { $buf.Add($o) }
  end { $s = ($buf | Out-String -Width 300).TrimEnd(); Write-Host $s; Add-Content -Path $Out -Value $s -Encoding UTF8 }
}
function H { param($t) W ""; W ("=" * 90); W "== $t"; W ("=" * 90) }

"Audit retea - $(Get-Date)  | Admin: $IsAdmin | PC: $env:COMPUTERNAME" | Set-Content -Path $Out -Encoding UTF8
$os = Get-CimInstance Win32_OperatingSystem
W "OS: $($os.Caption) build $($os.BuildNumber)"

# ---------------------------------------------------------------- 3 (pornit in fundal, dureaza ~2 min)
$pingBlock = {
  param($name, $target, $count)
  $p = New-Object System.Net.NetworkInformation.Ping
  $rtt = New-Object System.Collections.Generic.List[double]; $lost = 0
  for ($i = 0; $i -lt $count; $i++) {
    try { $r = $p.Send($target, 1000) } catch { $r = $null }
    if ($r -and $r.Status -eq 'Success') { $rtt.Add([double]$r.RoundtripTime) } else { $lost++ }
    Start-Sleep -Milliseconds 200
  }
  $j = 0; if ($rtt.Count -gt 1) { $d = for ($k = 1; $k -lt $rtt.Count; $k++) { [math]::Abs($rtt[$k] - $rtt[$k-1]) }; $j = ($d | Measure-Object -Average).Average }
  $s = $rtt | Sort-Object
  [pscustomobject]@{
    Tinta = "$name ($target)"; Trimise = $count; Pierdute = $lost; 'Pierderi%' = [math]::Round(100*$lost/$count,1)
    MinMs = if ($s) { $s[0] } else { $null }; MedMs = if ($s) { [math]::Round(($s | Measure-Object -Average).Average,1) } else { $null }
    P95Ms = if ($s) { $s[[math]::Min($s.Count-1,[int]([math]::Ceiling($s.Count*0.95))-1)] } else { $null }
    MaxMs = if ($s) { $s[-1] } else { $null }; JitterMs = [math]::Round($j,1)
  }
}
$pingTargets = [ordered]@{}; foreach ($k in $Infra.Keys) { $pingTargets[$k] = $Infra[$k] }; $pingTargets['Cloudflare'] = '1.1.1.1'
$jobs = foreach ($k in $pingTargets.Keys) { Start-Job -ScriptBlock $pingBlock -ArgumentList $k, $pingTargets[$k], $PingCnt }

# ---------------------------------------------------------------- 1
H "1. CONFIGURATIE RETEA PC"
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, MediaType, PhysicalMediaType, LinkSpeed, MacAddress, DriverVersion | Format-Table -AutoSize | W
Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | ForEach-Object {
  [pscustomobject]@{ Interfata = $_.InterfaceAlias; IPv4 = ($_.IPv4Address.IPAddress -join ','); Gateway = ($_.IPv4DefaultGateway.NextHop -join ','); DNS = ($_.DNSServer | Where-Object AddressFamily -eq 2 | ForEach-Object { $_.ServerAddresses } ) -join ',' }
} | Format-Table -AutoSize | W
Get-NetConnectionProfile | Select-Object InterfaceAlias, Name, NetworkCategory, IPv4Connectivity | Format-Table -AutoSize | W
W "--- netsh wlan show interfaces (banda, canal, semnal, viteza Rx/Tx)"
netsh wlan show interfaces | W
W "--- Traseu spre internet (detectie dublu NAT)"
tracert -d -h 6 -w 500 1.1.1.1 | W

# ---------------------------------------------------------------- 2
H "2. RETELE WI-FI DIN JUR (netsh wlan show networks mode=bssid)"
W "(Pe Windows 11 24H2+ trebuie permisiunea de Locatie activa pentru ca aceasta lista sa nu fie goala.)"
$scan = netsh wlan show networks mode=bssid
$scan | W
$rows = @(); $ssid = ''; $sig = $null
foreach ($l in $scan) {
  if ($l -match '^\s*SSID\s+\d+\s*:\s*(.*)$') { $ssid = $Matches[1].Trim(); if (-not $ssid) { $ssid = '<ascuns>' } }
  elseif ($l -match '^\s*(Signal|Semnal)\s*:\s*(\d+)%') { $sig = [int]$Matches[2] }
  elseif ($l -match '^\s*(Channel|Canal)\s*:\s*(\d+)') { $rows += [pscustomobject]@{ SSID = $ssid; Canal = [int]$Matches[2]; Semnal = $sig; Banda = if ([int]$Matches[2] -le 14) { '2.4 GHz' } else { '5 GHz' } } }
}
W "--- Sumar ocupare canale (nr. BSSID-uri, semnal maxim)"
$rows | Group-Object Banda, Canal | ForEach-Object { [pscustomobject]@{ Banda = $_.Group[0].Banda; Canal = $_.Group[0].Canal; BSSIDuri = $_.Count; SemnalMax = ($_.Group | Measure-Object Semnal -Maximum).Maximum; SSIDuri = (($_.Group.SSID | Select-Object -Unique) -join ', ') } } |
  Sort-Object Banda, Canal | Format-Table -AutoSize -Wrap | W

# ---------------------------------------------------------------- 4
H "4. COMPARATIE TIMPI DNS"
$dnsSrv = [ordered]@{}
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique | ForEach-Object { $dnsSrv["Sistem/ISP $_"] = $_ }
$dnsSrv['Cloudflare'] = '1.1.1.1'; $dnsSrv['Google'] = '8.8.8.8'; $dnsSrv['Quad9'] = '9.9.9.9'
$domains = 'google.com','youtube.com','facebook.com','wikipedia.org','emag.ro','digi24.ro','olx.ro','anaf.ro','github.com','microsoft.com','netflix.com','amazon.de'
$dnsRes = foreach ($n in $dnsSrv.Keys) {
  $srv = $dnsSrv[$n]; $cold = @(); $warm = @(); $fail = 0
  foreach ($round in 1..3) { foreach ($d in $domains) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $null = Resolve-DnsName -Name $d -Server $srv -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop; $sw.Stop(); if ($round -eq 1) { $cold += $sw.Elapsed.TotalMilliseconds } else { $warm += $sw.Elapsed.TotalMilliseconds } }
    catch { $fail++ }
  } }
  $egress = try { (Resolve-DnsName whoami.akamai.net -Server $srv -Type A -DnsOnly -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1).IPAddress } catch { '?' }
  $med = { param($a) if (-not $a) { return $null }; $s = $a | Sort-Object; [math]::Round($s[[int][math]::Floor(($s.Count-1)/2)],1) }
  [pscustomobject]@{ Server = "$n ($srv)"; 'Rece_medianMs' = (& $med $cold); 'Cache_medianMs' = (& $med $warm); 'MaxMs' = [math]::Round((($cold+$warm) | Measure-Object -Maximum).Maximum,1); Esecuri = $fail; 'IP resolver vazut' = $egress }
}
$dnsRes | Format-Table -AutoSize | W

# ---------------------------------------------------------------- 3 (rezultate)
H "3. PING ($PingCnt pachete / tinta, interval 200 ms; <1 ms apare ca 0)"
$jobs | Wait-Job | Receive-Job | Select-Object Tinta, Trimise, Pierdute, 'Pierderi%', MinMs, MedMs, P95Ms, MaxMs, JitterMs | Format-Table -AutoSize | W
$jobs | Remove-Job

# ---------------------------------------------------------------- 5 + 6
H "5. INVENTAR DISPOZITIVE $Subnet.0/24"
$nmap = (Get-Command nmap -ErrorAction SilentlyContinue).Source
if (-not $nmap) { $nmap = @("${env:ProgramFiles(x86)}\Nmap\nmap.exe", "$env:ProgramFiles\Nmap\nmap.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $nmap) {
  $ans = Read-Host "nmap nu este instalat. Il instalez acum cu winget (Insecure.Nmap, include Npcap)? [da/nu]"
  if ($ans -match '^(d|da|y|yes)$') {
    winget install -e --id Insecure.Nmap --accept-source-agreements --accept-package-agreements
    $nmap = @("${env:ProgramFiles(x86)}\Nmap\nmap.exe", "$env:ProgramFiles\Nmap\nmap.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
  } else { W "nmap refuzat - folosesc ping sweep + tabel ARP si test TCP pe porturi uzuale." }
}

# Ping sweep (umple si tabela ARP)
$tasks = 1..254 | ForEach-Object { (New-Object System.Net.NetworkInformation.Ping).SendPingAsync("$Subnet.$_", 700) }
try { [Threading.Tasks.Task]::WaitAll($tasks) } catch {}
Start-Sleep -Seconds 1
$neigh = Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "$Subnet.*" -and $_.State -notin 'Unreachable','Incomplete' -and $_.LinkLayerAddress -notmatch '^(00-00-00-00-00-00|FF-FF-FF-FF-FF-FF)$' -and $_.IPAddress -ne "$Subnet.255" }
$myIPs = (Get-NetIPAddress -AddressFamily IPv4).IPAddress
$hosts = @($neigh.IPAddress) + @($myIPs | Where-Object { $_ -like "$Subnet.*" }) | Select-Object -Unique | Sort-Object { [version]$_ }
$hosts | ForEach-Object {
  $ip = $_; $n = $neigh | Where-Object IPAddress -eq $ip | Select-Object -First 1
  $hn = try { [Net.Dns]::GetHostEntry($ip).HostName } catch { '' }
  [pscustomobject]@{ IP = $ip; MAC = if ($ip -in $myIPs) { '(acest PC)' } else { $n.LinkLayerAddress }; OUI = if ($n) { ($n.LinkLayerAddress -split '-')[0..2] -join ':' } else { '' }; Hostname = $hn; Rol = ($Infra.GetEnumerator() | Where-Object Value -eq $ip).Key }
} | Format-Table -AutoSize | W

if ($nmap) {
  W "--- nmap -sn (descoperire + producator dupa MAC)"
  & $nmap -sn -T4 "$Subnet.0/24" | W
}

H "6. PORTURI DESCHISE"
if ($nmap) {
  $tcpType = if ($IsAdmin) { '-sS' } else { '-sT' }
  W "--- Router / AX53 / RE305: top 1000 TCP + versiuni servicii"
  & $nmap $tcpType -sV --version-light -T4 -Pn --open --top-ports 1000 @($Infra.Values) | W
  if ($IsAdmin) { W "--- Router: UDP uzuale (DNS, DHCP, TFTP, NTP, SNMP, UPnP/SSDP, NAT-PMP, mDNS)"; & $nmap -sU -T4 -Pn --open -p 53,67,69,123,161,1900,5351,5353 "$Subnet.1" | W }
  else { W "(UDP sarit - necesita Administrator)" }
  $others = $hosts | Where-Object { $_ -notin $Infra.Values -and $_ -notin $myIPs }
  if ($others) { W "--- Celelalte dispozitive: top 200 TCP"; & $nmap $tcpType -sV --version-light -T4 -Pn --open --top-ports 200 @($others) | W }
} else {
  $ports = 21,22,23,53,80,139,443,445,515,554,631,1883,1900,3389,5000,5357,7547,8000,8008,8009,8080,8443,8888,9100,20005,49152,62078
  foreach ($ip in ($hosts | Where-Object { $_ -notin $myIPs })) {
    $open = foreach ($p in $ports) { $c = New-Object Net.Sockets.TcpClient; try { if ($c.ConnectAsync($ip, $p).Wait(400) -and $c.Connected) { $p } } catch {} finally { $c.Close() } }
    W ("{0,-15} TCP deschise: {1}" -f $ip, ($(if ($open) { $open -join ', ' } else { '-' })))
  }
}

# ---------------------------------------------------------------- 7
H "7. SECURITATE PC: FIREWALL, PARTAJARI, SERVICII EXPUSE"
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, AllowInboundRules, LogBlocked | Format-Table -AutoSize | W
try { Get-CimInstance -Namespace root/SecurityCenter2 -ClassName FirewallProduct -ErrorAction Stop | Select-Object displayName | W } catch {}
try { Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | Select-Object displayName, productState | Format-Table -AutoSize | W } catch {}

W "--- Grupuri firewall: Network Discovery / File and Printer Sharing (reguli inbound active)"
foreach ($g in '@FirewallAPI.dll,-32752','@FirewallAPI.dll,-28502') {
  Get-NetFirewallRule -Group $g -Direction Inbound -ErrorAction SilentlyContinue | Where-Object Enabled -eq 'True' | Select-Object DisplayGroup, DisplayName, Profile | Format-Table -AutoSize | W
}
W "--- Reguli inbound ALLOW active care includ profilul Public/Any (max 80)"
Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True | Where-Object { $_.Profile -match 'Any|Public' } | Select-Object -First 80 DisplayName, Profile, Program | Format-Table -AutoSize | W

W "--- Partajari SMB"
try { Get-SmbShare | Select-Object Name, Path, Description, CurrentUsers | Format-Table -AutoSize | W } catch { W "Get-SmbShare: $_" }
try { Get-SmbShare | Where-Object { $_.Name -notmatch '\$$' } | ForEach-Object { Get-SmbShareAccess -Name $_.Name } | Format-Table -AutoSize | W } catch {}
try { Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, RequireSecuritySignature, EncryptData | Format-List | W } catch {}

W "--- RDP"
$ts = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction SilentlyContinue
$nla = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -ErrorAction SilentlyContinue
W ("RDP activ: {0}  | NLA: {1}" -f ($ts.fDenyTSConnections -eq 0), ($nla.UserAuthentication -eq 1))

W "--- NetBIOS / LLMNR"
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=true' | Select-Object Description, @{n='NetBIOS';e={ switch ($_.TcpipNetbiosOptions) { 0 {'Default(DHCP)'} 1 {'Activ'} 2 {'Dezactivat'} } }} | Format-Table -AutoSize | W
$ll = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -ErrorAction SilentlyContinue).EnableMulticast
W ("LLMNR: {0}" -f $(if ($ll -eq 0) { 'Dezactivat prin politica' } else { 'Activ (implicit)' }))

W "--- Porturi TCP in ascultare pe interfete non-loopback"
$proc = @{}; Get-Process | ForEach-Object { $proc[$_.Id] = $_.ProcessName }
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalAddress -notin '127.0.0.1','::1' } |
  Select-Object LocalAddress, LocalPort, @{n='Proces';e={$proc[[int]$_.OwningProcess]}}, OwningProcess | Sort-Object LocalPort -Unique | Format-Table -AutoSize | W
W "--- Porturi UDP pe interfete non-loopback"
Get-NetUDPEndpoint | Where-Object { $_.LocalAddress -notin '127.0.0.1','::1' } |
  Select-Object LocalAddress, LocalPort, @{n='Proces';e={$proc[[int]$_.OwningProcess]}} | Sort-Object LocalPort -Unique | Format-Table -AutoSize | W

W "--- Servicii relevante"
Get-Service -Name RemoteRegistry, SSDPSRV, upnphost, WinRM, sshd, TermService, LanmanServer, FTPSVC, W3SVC, Spooler, TlntSvr, FDResPub -ErrorAction SilentlyContinue |
  Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize | W

H "GATA"
W "Raport salvat in: $Out"
