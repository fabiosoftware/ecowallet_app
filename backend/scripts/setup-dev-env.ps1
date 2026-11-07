<#
 Instala Go e Docker Desktop via winget e configura PATH/GOROOT/GOPATH (escopo usuário).
 Uso: powershell -ExecutionPolicy Bypass -File backend\scripts\setup-dev-env.ps1 [-SkipDocker]
#>
param([switch]$SkipDocker)
$ErrorActionPreference = 'Stop'

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')
}

# Go (MSI em Program Files) e Docker Desktop exigem elevação.
if (-not (Test-Admin)) {
    Write-Host 'Solicitando elevação (UAC)...'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($SkipDocker) { $argList += '-SkipDocker' }
    $p = Start-Process powershell -Verb RunAs -ArgumentList $argList -Wait -PassThru
    exit $p.ExitCode
}

function Install-WingetPackage([string]$Id) {
    Write-Host "Instalando $Id ..."
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
    # -1978335189 = já instalado / sem atualização disponível
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget falhou para $Id ($LASTEXITCODE)" }
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

Install-WingetPackage 'GoLang.Go'
if (-not $SkipDocker) { Install-WingetPackage 'Docker.DockerDesktop' }

# Variáveis de ambiente (escopo usuário)
$goRoot = 'C:\Program Files\Go'
$goPath = Join-Path $env:USERPROFILE 'go'
New-Item -ItemType Directory -Force $goPath | Out-Null
[Environment]::SetEnvironmentVariable('GOROOT', $goRoot, 'User')
[Environment]::SetEnvironmentVariable('GOPATH', $goPath, 'User')

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = @() + ($userPath -split ';' | Where-Object { $_ })
foreach ($e in "$goRoot\bin", "$goPath\bin") {
    if ($entries -notcontains $e) { $entries += $e }
}
[Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')

Update-SessionPath
$env:GOROOT = $goRoot; $env:GOPATH = $goPath

Write-Host "`n== Verificação =="
& "$goRoot\bin\go.exe" version
if (-not $SkipDocker) {
    $d = "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
    if (Test-Path $d) { & $d --version } else { Write-Warning 'docker.exe não encontrado.' }
    Write-Host 'Docker Desktop pode exigir reinicialização do Windows e WSL2 habilitado.'
}
Write-Host "`nPronto. Feche e reabra o terminal do VS Code (ou: Developer: Reload Window)."
