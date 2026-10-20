# tests/ps-parse.ps1 — parse scripts/setup-winrm.ps1 (no execution) and check what the guide promises.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile('scripts/setup-winrm.ps1', [ref]$tokens, [ref]$errors)
if ($errors.Count) { $errors | ForEach-Object { "parse error: $($_.Message)" }; exit 1 }
$cmds = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
        ForEach-Object { $_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique
$text = $ast.Extent.Text
$script:rc = 0
function Check([bool]$ok, [string]$msg) { if ($ok) { "ok   $msg" } else { "FAIL $msg"; $script:rc = 1 } }
Check ($cmds -contains 'Enable-PSRemoting')               'calls Enable-PSRemoting'
Check ($text -match "Auth\\Basic'\s+'false'")           'leaves Basic auth off'
Check ($text -match "AllowUnencrypted'\s+'false'")       'keeps AllowUnencrypted off'
Check (($text -split "`n" | Where-Object { $_ -match "Auth\\Basic'|AllowUnencrypted'" } | Where-Object { $_ -notmatch '-Required' }).Count -eq 0) 'Basic/AllowUnencrypted fail closed (-Required)'
Check ($text -match '(-LocalPort\s+|LocalPort\s*=\s*)5986')   'opens TCP 5986'
Check ($text -match 'LocalAccountTokenFilterPolicy\s+-Value\s+1') 'sets LocalAccountTokenFilterPolicy=1 for the local admin'
$params = @(); if ($ast.ParamBlock) { $params = $ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath } }
Check ($params -contains 'ImageRoot')                     'has an -ImageRoot parameter'
foreach ($d in 'Images', 'Images\seeds', 'VHDs', 'VMs') { Check ($text -match [regex]::Escape("'$d'")) "creates <ImageRoot>\$d" }
Check ($text -match 'listener ready on port 5986')        'prints the ready message'
Check ($text -match '405 or 401')                         'explains the curl test result'
if ($script:rc -eq 0) { 'ps-parse: PASS' } else { 'ps-parse: FAIL' }
exit $script:rc
