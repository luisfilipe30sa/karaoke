# Gera o aplicativo Windows.
#
# Padrao (recomendado): pasta dist\KaraokeMVP\ com KaraokeMVP.exe + _internal\
# e um .zip pronto para distribuir.
#
# Uso:
#   .\build_exe.ps1
#   .\build_exe.ps1 -OneFile      # um unico .exe portatil
#
# O modo -OneFile extrai DLLs para %TEMP% na primeira execucao; em ambientes
# com %TEMP% bloqueado, prefira o modo pasta.
# (Este script usa apenas ASCII para funcionar no Windows PowerShell 5.1.)
param(
    [switch]$OneFile
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    throw "Ambiente .venv nao encontrado. Crie com: py -3.12 -m venv .venv"
}

Write-Host "[1/3] Verificando dependencias de build..."
& $python -c "import PyInstaller" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    & $python -m pip install --disable-pip-version-check --no-input -r requirements-build.txt
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao instalar as dependencias de build."
    }
} else {
    Write-Host "PyInstaller ja instalado."
}

$icon = Join-Path $root "assets\karaoke.ico"
if (-not (Test-Path -LiteralPath $icon)) {
    throw "Icone ausente: $icon"
}

$name = if ($OneFile) { "KaraokeMVP-portable" } else { "KaraokeMVP" }
$modeArgs = if ($OneFile) { @("--onefile") } else { @("--onedir") }

Write-Host "[2/3] Gerando $name com PyInstaller..."
# Caminhos absolutos: com --specpath, o PyInstaller resolve add-data
# relativos a partir da pasta do .spec, nao da raiz do projeto.
$songsData = "$root\songs;songs"
$assetsData = "$root\assets;assets"
$entry = Join-Path $root "run.py"
$arguments = @(
    "-m", "PyInstaller",
    "--noconfirm", "--clean", "--windowed", "--noupx",
    "--name", $name,
    "--icon", $icon,
    "--add-data", $songsData,
    "--add-data", $assetsData,
    "--hidden-import", "tkinter",
    "--hidden-import", "tkinter.filedialog",
    "--specpath", "build",
    "--workpath", "build",
    "--distpath", "dist",
    "--log-level", "INFO"
) + $modeArgs + @($entry)

& $python @arguments
if ($LASTEXITCODE -ne 0) { throw "Falha no PyInstaller." }

if ($OneFile) {
    $exe = Join-Path $root "dist\$name.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "O executavel nao foi gerado."
    }
    $sizeMb = [math]::Round((Get-Item -LiteralPath $exe).Length / 1MB, 1)
    Write-Host "[3/3] Pronto: $exe ($sizeMb MB)" -ForegroundColor Green
    Write-Host "Onefile: mantenha %TEMP% gravavel para a extracao inicial."
    exit 0
}

$appDir = Join-Path $root "dist\KaraokeMVP"
$exe = Join-Path $appDir "KaraokeMVP.exe"
if (-not (Test-Path -LiteralPath $exe)) {
    throw "O executavel nao foi gerado."
}

$leiaMe = @"
Karaoke MVP 1.0.0
=================

1. De um duplo clique em KaraokeMVP.exe.
2. Clique em "SELECIONAR MUSICA" ou arraste um arquivo .kar para a janela.
3. Pressione ENTER para comecar a cantar.

Controles:
  ENTER    iniciar / reiniciar / continuar pausado
  P/ESPACO pausar ou continuar
  M        escolher outra musica sem fechar o app
  R        reiniciar apos o fim ou erro
  ESC      sair

No canto superior direito ha icones clicaveis de pausa e de troca de musica.
O menu de pausa tambem tem botoes para continuar, trocar de musica e sair.

Se os acentos das letras aparecerem errados, clique no chip
"LETRAS: ..." no canto superior direito do seletor de musicas.

A mesma nota cantada uma ou mais oitavas acima/abaixo conta como acerto.
O marcador mostra "8a acima" ou "8a abaixo".

Na letra, uma bolinha pula sobre a silaba/palavra que deve ser cantada
no momento, como nos karaokes tradicionais.

Na pausa, ajuste volume do acompanhamento, latencia de entrada,
offset da letra e metronomo da contagem. As configuracoes sao salvas.

O chip TOM transpõe a proxima musica. A biblioteca (L) mostra
favoritos e recentes. O acompanhamento sintetizado fica em cache.

O resultado final mostra recordes locais. A voz e gravada em
%%APPDATA%%\KaraokeMVP\recordings.

O acompanhamento toca automaticamente. Ele e sintetizado do MIDI.
Para usar um audio de qualidade, coloque musica.wav, .ogg ou .mp3
ao lado de musica.kar, com o mesmo alinhamento da musica.

Importante: mantenha a pasta _internal junto do executavel.
Esta pasta contem Python, Pygame, Tcl/Tk e as bibliotecas necessarias.

A captura usa automaticamente o microfone padrao do Windows.
Se nao houver audio, verifique as permissoes de microfone do sistema.
"@
Set-Content -LiteralPath (Join-Path $appDir "LEIA-ME.txt") -Value $leiaMe -Encoding UTF8

$zip = Join-Path $root "dist\KaraokeMVP-windows.zip"
if (Test-Path -LiteralPath $zip) {
    Remove-Item -LiteralPath $zip -Force
}
Compress-Archive -Path $appDir -DestinationPath $zip -CompressionLevel Optimal

$exeMb = [math]::Round((Get-Item -LiteralPath $exe).Length / 1MB, 1)
$zipMb = [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)
Write-Host "[3/3] Pronto:" -ForegroundColor Green
Write-Host "  Executavel: $exe ($exeMb MB)"
Write-Host "  Pacote ZIP: $zip ($zipMb MB)"
Write-Host "Mantenha a pasta _internal junto do .exe."
