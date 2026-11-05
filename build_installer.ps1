# Compila o instalador Inno Setup 6.
# Requer Inno Setup 6 instalado (https://jrsoftware.org/isinfo.php).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
)
$iscc = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $iscc) {
    throw "Inno Setup 6 nao encontrado. Instale em https://jrsoftware.org/isinfo.php e rode novamente."
}

if (-not (Test-Path -LiteralPath "dist\KaraokeMVP\KaraokeMVP.exe")) {
    throw "Gere primeiro o app com .\build_exe.bat"
}

& $iscc "installer\KaraokeMVP.iss"
if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar o instalador." }
Write-Host "Instalador gerado em dist\KaraokeMVP-Setup.exe" -ForegroundColor Green
