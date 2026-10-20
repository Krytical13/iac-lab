# download-images.ps1 — Download cloud images for Hyper-V lab VMs
# Run on the Windows host. Downloads Ubuntu, Rocky, and converts to VHDX.

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$ImageDir = "C:\HyperV\Images"
if (-not (Test-Path $ImageDir)) {
    New-Item -ItemType Directory -Path $ImageDir -Force | Out-Null
}

$images = @(
    @{
        Name    = "ubuntu-24.04-cloudimg"
        Url     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
        OutFile = "$ImageDir\ubuntu-24.04-cloudimg-amd64.img"
        Vhdx    = "$ImageDir\ubuntu-24.04-cloudimg-amd64.vhdx"
    },
    @{
        Name    = "rocky-9-cloudimg"
        Url     = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
        OutFile = "$ImageDir\rocky-9-cloudimg-amd64.qcow2"
        Vhdx    = "$ImageDir\rocky-9-cloudimg-amd64.vhdx"
    }
)

foreach ($img in $images) {
    Write-Host "`nDownloading $($img.Name)..." -ForegroundColor Cyan

    if (Test-Path $img.Vhdx) {
        Write-Host "  VHDX already exists, skipping." -ForegroundColor Yellow
        continue
    }

    # Download
    if (-not (Test-Path $img.OutFile)) {
        Invoke-WebRequest -Uri $img.Url -OutFile $img.OutFile -UseBasicParsing
        Write-Host "  Downloaded: $($img.OutFile)" -ForegroundColor Green
    }

    # Convert to VHDX using qemu-img (must be installed)
    Write-Host "  Converting to VHDX..." -ForegroundColor Cyan
    & qemu-img convert -f qcow2 -O vhdx -o subformat=dynamic $img.OutFile $img.Vhdx
    Write-Host "  Created: $($img.Vhdx)" -ForegroundColor Green
}

Write-Host "`nAll images ready in $ImageDir" -ForegroundColor Green
Write-Host "Note: qemu-img is required for conversion. Install via: winget install qemu" -ForegroundColor Gray