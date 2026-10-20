<#
.SYNOPSIS
  Prepare a Windows Hyper-V host for Terraform over WinRM (HTTPS, NTLM).

.DESCRIPTION
  Run once, as Administrator, on the Hyper-V host:

    powershell -ExecutionPolicy Bypass -File .\setup-winrm.ps1 -ImageRoot D:\HyperV

  1. Enable-PSRemoting: WinRM service, HTTP listener, built-in firewall rules
  2. Self-signed certificate + HTTPS listener on 5986 (an existing HTTPS listener is replaced)
  3. Authentication: Basic stays OFF (Terraform uses NTLM), unencrypted traffic refused
  4. Firewall: allow TCP 5986 inbound (optionally only from -AllowFrom addresses)
  5. Lab directories: <ImageRoot>\Images, \Images\seeds, \VHDs, \VMs

.PARAMETER ImageRoot
  Folder that will hold golden images, seeds, VM disks and VM configs. Default C:\HyperV.

.PARAMETER AllowFrom
  Optional list of addresses or subnets allowed to reach 5986 (e.g. 192.168.1.10 or
  192.168.1.0/24). Without it the rule allows any remote address.
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$ImageRoot = 'C:\HyperV',
    [string[]]$AllowFrom
)
$ErrorActionPreference = 'Stop'

Write-Host "[1/5] Enabling PowerShell remoting (WinRM service + HTTP listener)..." -ForegroundColor Cyan
Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null

Write-Host "[2/5] Creating a self-signed certificate and the HTTPS listener on 5986..." -ForegroundColor Cyan
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME `
    -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(3)
Get-ChildItem WSMan:\localhost\Listener |
    Where-Object { $_.Keys -contains 'Transport=HTTPS' } |
    ForEach-Object { Remove-Item $_.PSPath -Recurse -Force }
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * `
    -CertificateThumbPrint $cert.Thumbprint -Force | Out-Null

Write-Host "[3/5] Authentication: NTLM only (Basic off), encryption required..." -ForegroundColor Cyan
Set-Item WSMan:\localhost\Service\Auth\Basic $false
Set-Item WSMan:\localhost\Service\AllowUnencrypted $false
Set-Item WSMan:\localhost\MaxTimeoutms 1800000

Write-Host "[4/5] Firewall: allow TCP 5986 inbound..." -ForegroundColor Cyan
$ruleName = 'WinRM-HTTPS-In'
if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
    Write-Host "      rule '$ruleName' already exists" -ForegroundColor Yellow
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
Write-Host "WinRM HTTPS listener ready on port 5986" -ForegroundColor Green
Write-Host "Test it from the control node (405 or 401 = listener up; 000 = blocked or not listening):"
Write-Host "  curl -sk -o /dev/null -w '%{http_code}\n' https://<host>:5986/wsman"
