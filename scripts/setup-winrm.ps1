<#
.SYNOPSIS
  Prepare a Windows Hyper-V host for Terraform over WinRM (HTTPS, NTLM).

.DESCRIPTION
  Run once, as Administrator, on the Hyper-V host (safe to run again):

    powershell -ExecutionPolicy Bypass -File .\setup-winrm.ps1 -ImageRoot D:\HyperV

  1. Enable-PSRemoting: WinRM service and its firewall rules. If the host had no
     HTTP listener before, the one Enable-PSRemoting adds is removed again: this
     lab speaks HTTPS only.
  2. Self-signed certificate + HTTPS listener on 5986 (an existing, still-valid
     HTTPS listener is kept)
  3. Authentication: Basic stays OFF (Terraform uses NTLM), unencrypted traffic
     refused, local admins get a full token over WinRM
  4. Firewall: allow TCP 5986 inbound (optionally only from -AllowFrom addresses)
  5. Lab directories: <ImageRoot>\Images, \Images\seeds, \VHDs, \VMs

.PARAMETER ImageRoot
  Folder that will hold golden images, seeds, VM disks and VM configs. Default C:\HyperV.

.PARAMETER AllowFrom
  Optional list of addresses or subnets allowed to reach 5986 (e.g. 192.168.1.10 or
  192.168.1.0/24). Without it the rule allows any remote address. Applied to an
  existing rule too.
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$ImageRoot = 'C:\HyperV',
    [string[]]$AllowFrom
)
$ErrorActionPreference = 'Stop'

function Get-Listeners([string]$Transport) {
    Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue |
        Where-Object { $_.Keys -contains "Transport=$Transport" }
}

Write-Host "[1/5] Enabling PowerShell remoting (WinRM service + firewall rules)..." -ForegroundColor Cyan
$hadHttp = [bool](Get-Listeners HTTP)
Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
if (-not $hadHttp) {
    Get-Listeners HTTP | ForEach-Object { Remove-Item $_.PSPath -Recurse -Force }
    Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP*' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
    Write-Host "      removed the plain-HTTP listener (5985); this lab uses HTTPS only"
}

Write-Host "[2/5] HTTPS listener on 5986..." -ForegroundColor Cyan
$keep = $false
$https = Get-Listeners HTTPS | Select-Object -First 1
if ($https) {
    $thumb = (Get-ChildItem $https.PSPath | Where-Object Name -eq 'CertificateThumbprint').Value
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object Thumbprint -eq $thumb
    if ($cert -and $cert.NotAfter -gt (Get-Date).AddDays(30)) { $keep = $true }
}
if ($keep) {
    Write-Host "      keeping the existing HTTPS listener (certificate valid until $($cert.NotAfter.ToString('yyyy-MM-dd')))"
} else {
    $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -FriendlyName 'IaC lab WinRM' `
        -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(3)
    Get-Listeners HTTPS | ForEach-Object { Remove-Item $_.PSPath -Recurse -Force }
    New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * `
        -CertificateThumbPrint $cert.Thumbprint -Force | Out-Null
    Write-Host "      created a self-signed certificate and the HTTPS listener"
}

Write-Host "[3/5] Authentication: NTLM only (Basic off), encryption required..." -ForegroundColor Cyan
# Only change a setting that differs: WinRM refuses to change service settings while any
# network connection is in the Public profile, so an unneeded Set-Item would just fail.
$script:warned = $false
function Ensure-WSManValue([string]$Path, [string]$Value, [string]$What) {
    $current = (Get-Item $Path).Value
    if ("$current" -ieq $Value) { Write-Host "      $What already $Value"; return }
    try { Set-Item $Path $Value -Force; Write-Host "      $What set to $Value" }
    catch {
        Write-Warning "could not set $What to $Value. A network connection on this host is in the Public profile; run 'Set-NetConnectionProfile -NetworkCategory Private' for it (or leave it and accept the current value $current)."
        $script:warned = $true
    }
}
Ensure-WSManValue 'WSMan:\localhost\Service\Auth\Basic'      'false'   'Basic auth'
Ensure-WSManValue 'WSMan:\localhost\Service\AllowUnencrypted' 'false'   'AllowUnencrypted'
Ensure-WSManValue 'WSMan:\localhost\MaxTimeoutms'              '1800000' 'MaxTimeoutms'
# A local administrator connecting remotely gets a filtered (non-admin) token unless this is 1;
# Enable-PSRemoting sets it on workgroup machines, but be explicit so Hyper-V cmdlets work for tfadmin.
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord

Write-Host "[4/5] Firewall: allow TCP 5986 inbound..." -ForegroundColor Cyan
$ruleName = 'WinRM-HTTPS-In'
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    if ($AllowFrom) { $existingRule | Set-NetFirewallRule -RemoteAddress $AllowFrom; Write-Host "      rule '$ruleName' now limited to $($AllowFrom -join ', ')" }
    else { Write-Host "      rule '$ruleName' already exists" -ForegroundColor Yellow }
} else {
    $rule = @{ DisplayName = $ruleName; Direction = 'Inbound'; Protocol = 'TCP'
               LocalPort = 5986; Action = 'Allow'; Profile = 'Any' }
    if ($AllowFrom) { $rule.RemoteAddress = $AllowFrom }
    New-NetFirewallRule @rule | Out-Null
    Write-Host "      rule '$ruleName' created" -ForegroundColor Green
}

Write-Host "[5/5] Creating lab directories under $ImageRoot..." -ForegroundColor Cyan
foreach ($d in 'Images', 'Images\seeds', 'VHDs', 'VMs') {
    $p = Join-Path $ImageRoot $d
    if (Test-Path $p) { Write-Host "      exists  $p" }
    else { New-Item -ItemType Directory -Path $p | Out-Null; Write-Host "      created $p" }
}

Restart-Service WinRM
Write-Host ""
if ($script:warned) { Write-Host "Finished with warnings (see above)." -ForegroundColor Yellow }
Write-Host "WinRM HTTPS listener ready on port 5986" -ForegroundColor Green
Write-Host "Test it from the control node (405 or 401 = listener up; 000 = blocked or not listening):"
Write-Host "  curl -sk -o /dev/null -w '%{http_code}\n' https://<host>:5986/wsman"
