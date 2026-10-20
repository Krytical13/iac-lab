# setup-winrm.ps1 — Configure WinRM HTTPS listener for Terraform
# Run as Administrator on the Hyper-V host

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

Write-Host "[1/4] Creating self-signed certificate..." -ForegroundColor Cyan
$cert = New-SelfSignedCertificate `
    -DnsName $env:COMPUTERNAME `
    -CertStoreLocation Cert:\LocalMachine\My `
    -NotAfter (Get-Date).AddYears(3)

Write-Host "[2/4] Configuring WinRM HTTPS listener..." -ForegroundColor Cyan
# Remove existing HTTPS listener if present
Get-ChildItem WSMan:\localhost\Listener | Where-Object {
    $_.Keys -contains 'Transport=HTTPS'
} | ForEach-Object { Remove-Item $_.PSPath -Recurse -Force }

New-Item -Path WSMan:\localhost\Listener -Transport HTTPS `
    -Address * -CertificateThumbPrint $cert.Thumbprint -Force

Write-Host "[3/4] Configuring WinRM settings..." -ForegroundColor Cyan
Set-Item WSMan:\localhost\Service\Auth\Basic $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted $false
Set-Item WSMan:\localhost\MaxTimeoutms 1800000

Write-Host "[4/4] Opening firewall port 5986..." -ForegroundColor Cyan
$ruleName = "WinRM-HTTPS-In"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existing) {
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound -Protocol TCP -LocalPort 5986 `
        -Action Allow -Profile Any
    Write-Host "  Firewall rule created." -ForegroundColor Green
} else {
    Write-Host "  Firewall rule already exists." -ForegroundColor Yellow
}

Restart-Service WinRM
Write-Host "`nWinRM HTTPS listener ready on port 5986." -ForegroundColor Green
Write-Host "Test from Linux: curl -k https://$($env:COMPUTERNAME):5986/wsman" -ForegroundColor Gray