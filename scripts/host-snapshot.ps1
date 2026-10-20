<#
.SYNOPSIS
  Snapshot a host network adapter's identity and settings before/after creating an External switch.

.DESCRIPTION
  Creating an External virtual switch rebinds the physical adapter: the host's IP moves to a
  new "vEthernet (<switch>)" adapter and some drivers reset advanced or power settings.
  Run this before and after, then compare the two files (tests/host-switch.sh does).

    powershell -ExecutionPolicy Bypass -File .\host-snapshot.ps1 -Adapter 'Ethernet' -Out C:\HyperV\host-before.txt

.PARAMETER Adapter
  Name of the physical adapter (Get-NetAdapter).

.PARAMETER Out
  File to write. The same text is also printed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Adapter,
    [Parameter(Mandatory)][string]$Out
)
$ErrorActionPreference = 'Stop'

$a = Get-NetAdapter -Name $Adapter
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Adapter: $($a.Name) | $($a.InterfaceDescription) | Status=$($a.Status) | LinkSpeed=$($a.LinkSpeed)")
$lines.Add("MAC: $($a.MacAddress)")

$lines.Add('--- IPv4 addresses (every interface except loopback)')
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike 'Loopback*' } |
    Sort-Object InterfaceAlias | ForEach-Object { $lines.Add("$($_.InterfaceAlias): $($_.IPAddress)/$($_.PrefixLength) ($($_.PrefixOrigin))") }

$lines.Add('--- IPv4 default routes')
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    ForEach-Object { $lines.Add("$($_.InterfaceAlias): via $($_.NextHop) metric $($_.RouteMetric)") }

$lines.Add('--- DNS servers (IPv4)')
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses |
    Sort-Object InterfaceAlias | ForEach-Object { $lines.Add("$($_.InterfaceAlias): $($_.ServerAddresses -join ', ')") }

$lines.Add("--- Advanced properties of $Adapter")
Get-NetAdapterAdvancedProperty -Name $Adapter | Sort-Object DisplayName |
    ForEach-Object { $lines.Add("$($_.DisplayName) = $($_.DisplayValue)") }

$lines.Add("--- Power management of $Adapter")
$pm = Get-NetAdapterPowerManagement -Name $Adapter
foreach ($p in 'AllowComputerToTurnOffDevice', 'ArpOffload', 'NSOffload', 'WakeOnMagicPacket', 'WakeOnPattern', 'DeviceSleepOnDisconnect', 'SelectiveSuspend') {
    $lines.Add("$p = $($pm.$p)")
}

$lines | Set-Content -Path $Out -Encoding UTF8
$lines
