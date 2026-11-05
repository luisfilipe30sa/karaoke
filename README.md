# Karaokê MVP — pontuação de canto em tempo real

MVP em Python 3.10+ que lê arquivos **`.kar`** (MIDI com letras), toca o
acompanhamento, abre o microfone, detecta o pitch do cantor e compara cada
instante com a melodia guia do arquivo. A interface em Pygame mostra letra
sincronizada com **bolinha de karaokê**, piano roll, nota guia, pitch atual,
combo e pontuação de 0 a 100, com pausa e troca de música por ícones clicáveis.

Há uma tela inicial para **selecionar a música** pelo diálogo nativo do sistema
ou por arrastar-e-soltar, e o projeto já inclui build para gerar um
**executável Windows** com duplo clique.

![Tela de seleção de música](docs/launcher.png)

![Interface do karaokê](docs/screenshot.png)

> O acompanhamento é sintetizado a partir do MIDI ou carregado de um áudio
> irmão do `.kar` (`.wav`, `.ogg` ou `.mp3`). A melodia guia é silenciada; se o
> arquivo só tiver a melodia, ela é usada como base sonora.

---

## 1. Estrutura do projeto

```text
karaoke-mvp/
├── run.py                      # python run.py [arquivo.kar]
├── pyproject.toml              # metadados, dependências e console script
├── requirements.txt            # dependências de execução
├── requirements-dev.txt        # execução + pytest
├── requirements-build.txt      # execução + PyInstaller
├── requirements-aubio.txt      # backend opcional de pitch
├── build_exe.ps1               # gera o app Windows
├── build_exe.bat               # atalho de duplo clique para o build
├── build_installer.ps1         # compila o instalador Inno Setup
├── installer/
│   └── KaraokeMVP.iss
├── README.md
├── karaoke/
│   ├── __main__.py             # python -m karaoke
│   ├── cli.py                  # argparse, launcher, resumo e entrada do app
│   ├── launcher.py             # tela inicial + seletor nativo + drag-and-drop
│   ├── app.py                  # loop principal e relógio da música
│   ├── ui.py                   # janela Pygame, piano roll e letras
│   ├── midi_parser.py          # leitor .kar/MIDI, letras e gabarito
│   ├── models.py               # Song, NoteSpan, LyricEvent, LyricLine
│   ├── pitch.py                # YIN em NumPy, aubio opcional, Hz <-> MIDI
│   ├── audio.py                # PyAudio em thread + histórico de pitch
│   ├── backing.py              # síntese MIDI do acompanhamento
│   ├── playback.py             # reprodução via Pygame mixer
│   ├── metronome.py            # clique da contagem regressiva
│   ├── scoring.py              # comparação, tolerância, combo e score
│   ├── settings.py             # configurações persistentes
│   ├── logging_setup.py        # log em arquivo
│   ├── resources.py            # caminhos no código-fonte e no PyInstaller
│   ├── config.py               # AudioConfig e ScoringConfig
│   └── errors.py               # exceções de domínio
├── assets/
│   ├── karaoke.ico             # ícone do executável
│   └── karaoke.png             # ícone da janela
├── songs/
│   └── noite_de_estrelas.kar   # demo gerada, com letra em português
├── tools/
│   └── generate_demo_kar.py    # recria a demo sem arquivos externos
├── tests/                      # 64 testes sem necessidade de microfone
└── docs/
    ├── finished.png
    ├── launcher.png
    ├── octave.png
    ├── pause.png
    ├── ready.png
    └── screenshot.png
```

### Por que essa separação?

- **`midi_parser` + `models`** não conhecem áudio nem Pygame. Podem ser usados
  em um backend web, CLI ou teste.
- **`pitch` + `audio`** não conhecem pontuação. Produzem uma sequência de
  amostras de pitch com timestamp.
- **`scoring`** não conhece PyAudio nem Pygame. Recebe uma função
  `pitch_provider(tempo_da_música)` e é totalmente testável.
- **`ui`** é somente leitura: desenha um `ScoreSnapshot`; não calcula nada.
- **`launcher`** só seleciona/carrega a música e devolve uma `Song`; não abre
  microfone.
- **`app`** é o único ponto que conhece todos os módulos e o relógio global.

Fluxo de dados:

```text
LauncherApp (Pygame + diálogo nativo)
      │ escolhe .kar
      ▼
.kar ──► KarFileParser ──► Song (notas + letras + gabarito)
                                      │
microfone ──► PyAudio ──► YIN ──► PitchHistory
                                      │
Song.backing ──► synth/áudio irmão ──► BackingPlayer
                                      │
time.perf_counter() ──► KaraokeApp ──► ScoreTracker ──► ScoreSnapshot
                                                         │
                                                    KaraokeUI
```

---

## 2. Instalação

### Pré-requisitos

- Python **3.10+** (recomendado 3.10–3.12 por causa de wheels nativos).
- Microfone funcional e permissão de áudio do sistema.
- Windows: um terminal PowerShell.
- Linux/macOS: PortAudio instalado (necessário para compilar o PyAudio).

### Windows (PowerShell)

```powershell
py -3.10 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Se a política de execução bloquear o `Activate.ps1`, use o Python do venv
diretamente:

```powershell
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe run.py songs\noite_de_estrelas.kar
```

### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y portaudio19-dev python3-dev build-essential
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### macOS

```bash
brew install portaudio
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### Comandos `pip install` exatos

O `requirements.txt` contém:

```bash
pip install "mido==1.3.3" "numpy>=1.24,<3.0" "PyAudio==0.2.14" "pygame==2.6.1"
```

Essas são as únicas dependências obrigatórias. O backend **YIN em NumPy** é o
padrão e não precisa de `aubio`.

### Backend opcional `aubio`

```bash
pip install aubio
python run.py songs/noite_de_estrelas.kar --pitch-backend aubio
```

`aubio` é opcional porque exige binário nativo e pode não ter wheel para toda
versão de Python/plataforma. O padrão da CLI é `--pitch-backend yin`; com
`--pitch-backend auto`, o aubio é preferido quando instalado e o YIN é o
fallback.

### Ambiente de desenvolvimento

```bash
pip install -r requirements-dev.txt
python -m pytest -q
```

---

## 3. Como executar

### Executável Windows

Há duas formas de executar:

**Arquivo único:**

```text
dist\KaraokeMVP-portable.exe
```

Baixe, coloque em uma pasta gravável e dê um duplo clique. A primeira abertura
pode levar alguns segundos, pois as bibliotecas são extraídas internamente.

**Pasta completa (recomendada):**

O build gera a pasta `dist\KaraokeMVP\`:

```text
dist\
├── KaraokeMVP\
│   ├── KaraokeMVP.exe
│   ├── LEIA-ME.txt
│   └── _internal\        # Python, Pygame, Tcl/Tk, SDL, etc.
├── KaraokeMVP-windows.zip
├── KaraokeMVP-portable.exe
└── COMO-ABRIR.txt
```

Dê um duplo clique em:

```text
dist\KaraokeMVP\KaraokeMVP.exe
```

> **Importante:** se estiver usando a pasta, não separe o `.exe` da pasta
> `_internal`. Se estiver usando o ZIP, extraia tudo antes de executar. Se
> recebeu apenas o `.exe` pelo chat, use o `KaraokeMVP-portable.exe`.

Instruções resumidas também estão em [COMO-ABRIR.txt](dist/COMO-ABRIR.txt).

A tela inicial permite:

- clicar em **SELECIONAR MÚSICA** e escolher um `.kar` no diálogo do Windows;
- arrastar e soltar um `.kar` na janela;
- abrir a demonstração incluída;
- clicar em **LETRAS: ...** no canto superior direito para alternar a
  codificação das letras (`AUTOMÁTICO`, `WINDOWS-1252`, `UTF-8`, `LATIN-1`,
  `SHIFT-JIS`) quando os acentos não aparecerem corretamente.

Mantenha o `.exe` junto da pasta `_internal`. Para distribuir, envie o
`KaraokeMVP-windows.zip`; não é necessário Python instalado na máquina de
destino.

### Abrir o seletor pelo código-fonte

```bash
python run.py
```

Também é possível abrir uma música diretamente:

```bash
python run.py songs/noite_de_estrelas.kar
```

### Listar microfones

```bash
python run.py --list-devices
```

Saída de exemplo:

```text
Microfones de entrada:
  1: Microfone (High Definition Audio) (MME, 2 canais) [padrão]
  5: Microfone (High Definition Audio) (Windows DirectSound, 2 canais)
```

### Cantar com a demo

```bash
python run.py songs/noite_de_estrelas.kar
```

O app abre na tela de preparação. Pressione **ENTER** para iniciar a contagem
regressiva e cantar.

### Opções úteis

```bash
# Escolher microfone e tolerância
python run.py song.kar --device 5 --tolerance 0.8

# Forçar pista/canal (1-based para o usuário)
python run.py song.kar --track 2 --channel 1

# Ajustar taxa/bloco e contagem
python run.py song.kar --sample-rate 48000 --block-size 2048 --count-in 4

# Acompanhamento: volume ou desligado
python run.py song.kar --backing-volume 0.65
python run.py song.kar --no-backing

# Exigir a oitava exata (por padrão a mesma nota em outra oitava é aceita)
python run.py song.kar --no-octave-equivalence

# Transpor melodia e acompanhamento MIDI
python run.py song.kar --transpose 2

# Praticar o trecho de 30s a 60s, a 80% da velocidade, repetindo
python run.py song.kar --loop-start 30 --loop-end 60 --speed 0.8 --practice-loop

# Letras em codificação específica
python run.py song.kar --encoding cp1252

# Backend/diagnóstico
python run.py song.kar --pitch-backend yin --debug
```

Também funciona como módulo:

```bash
python -m karaoke songs/noite_de_estrelas.kar
```

### Controles

| Tecla | Ação |
|---|---|
| `ENTER` | iniciar / reiniciar / continuar pausado |
| `P` ou `Espaço` | pausar / continuar |
| `M` | escolher outra música sem fechar o app |
| `R` | reiniciar após o fim ou erro |
| `ESC` | sair |

Durante a pausa, use os botões `−`/`+` para ajustar volume, latência de entrada
e offset da letra. O metrônomo da contagem também pode ser ligado/desligado ali.
Esses valores ficam salvos para as próximas músicas.

Na tela de jogo também há dois ícones clicáveis no canto superior direito:

- **pausa/continuar** (barras ou triângulo);
- **pasta** para escolher outra música.

O menu de pausa tem os botões **CONTINUAR**, **ESCOLHER OUTRA MÚSICA** e
**SAIR**.

### Gerar o `.exe`

Instale as dependências de build e execute:

```powershell
python -m pip install -r requirements-build.txt
.\build_exe.bat
```

Se preferir rodar o PowerShell diretamente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build_exe.ps1
```

Saídas:

- `dist\KaraokeMVP\KaraokeMVP.exe` — versão em pasta, **recomendada**;
- `dist\KaraokeMVP-windows.zip` — pacote pronto para distribuir.

Para tentar um único arquivo:

```powershell
.\build_exe.ps1 -OneFile
```

O onefile gera `dist\KaraokeMVP-portable.exe`, mas extrai DLLs para `%TEMP%` na
primeira execução. Em máquinas com `%TEMP%` restrito ou antivírus agressivo, a
versão em pasta é mais confiável e inicia mais rápido.

### Instalador Windows

Com o [Inno Setup 6](https://jrsoftware.org/isinfo.php) instalado:

```powershell
.\build_installer.ps1
```

O instalador `dist\KaraokeMVP-Setup.exe` cria atalhos, opção de associação de
`.kar` e desinstalador. A assinatura digital precisa de um certificado próprio
e é um passo externo ao build.

Os erros da versão windowed são gravados em
`%APPDATA%\KaraokeMVP\logs\karaoke.log`.

---

## 4. O que o parser `.kar` faz

Arquivos `.kar` são Standard MIDI Files com metadados de letra. O parser:

1. Lê todas as faixas com `mido`.
2. Constrói um **mapa de tempo** com todos os `set_tempo`; assim mudanças de
   BPM são convertidas corretamente para segundos.
3. Pareia `note_on`/`note_off` por `(canal, nota)`, tolerando notas sem
   `note_off` (encerradas no fim da faixa).
4. Trata o **canal 10 MIDI** (índice 9) como percussão: não pode ser voz, mas é
   preservado para o acompanhamento.
5. Escolhe a pista/canal melódico por heurísticas:
   - presença de letra;
   - nome da pista (`vocal`, `melody`, `lead`, `solo`, etc.);
   - quantidade de notas;
   - alinhamento das notas com os eventos de letra.
6. Extrai metadados `lyrics` (ou `text`, como fallback), tratando `\` e `/`
   como quebras de linha e tentando UTF-8/CP1252/Shift-JIS automaticamente.
7. Gera uma timeline **monofônica**: se houver notas simultâneas, a nota mais
   aguda é usada como guia de canto. O piano roll ainda desenha as notas brutas.
8. Separa todas as notas que não são da fonte vocal como **acompanhamento**,
   usado pelo sintetizador/player.

Se o arquivo não tiver uma pista utilizável, o parser lança
`EmptyMelodyError` com uma mensagem clara. Se não houver letra, o app continua
funcionando apenas com o piano roll.

### Forçar pista/canal

A detecção automática cobre a maioria dos arquivos, mas arquivos karaokê são
heterogêneos. Use `--track` e `--channel` quando necessário:

```bash
python run.py song.kar --track 2 --channel 1
```

`--track` é 1-based (primeira pista = 1) e `--channel` é 1–16. O canal 10 é
rejeitado por ser percussão.

---

## 5. DSP de pitch

A cada bloco de áudio:

1. O PyAudio entrega PCM mono `int16` (padrão: 44.100 Hz, 2.048 amostras,
   ≈46 ms por bloco).
2. O sinal é convertido para `float` em `[-1, 1]` e o RMS é calculado.
3. Silêncio, ruído sem periodicidade e sinais com pouca confiança retornam
   `frequency_hz = 0` e `midi = 0` (sentinela de “sem voz”).
4. O detector **YIN** calcula a diferença quadrática por FFT, normaliza com
   CMNDF e escolhe o primeiro vale abaixo do limiar. A interpolação parabólica
   reduz o erro de quantização.
5. A frequência é convertida para MIDI:

```text
Nota_MIDI = 69 + 12 * log2(Hz / 440)
```

O YIN foi validado com senoides de 110–880 Hz, harmônicos, silêncio e ruído.
O erro observado nos sinais sintéticos ficou abaixo de 0,15 semitom.

### Captura em thread

O PyAudio roda em uma thread dedicada. Cada amostra recebe um timestamp de
`time.perf_counter()`, e o histórico circular (`PitchHistory`) permite buscar
o pitch mais recente para um instante da música. A UI nunca bloqueia o driver
de áudio com FFT ou alocações.

---

## 6. Motor de pontuação

A avaliação usa uma **grade fixa de 50 Hz**, independente do FPS da interface:

```text
score_0_100 = 100 * tempo_com_acerto / tempo_com_nota_esperada
```

- Só intervalos com nota-guia entram no denominador; introduções e solos
  instrumentais **não penalizam** o cantor.
- A tolerância padrão é **±0,8 semitom MIDI** (`--tolerance`).
- **Oitavas equivalentes**: por padrão, a mesma nota cantada uma ou mais
  oitavas acima/abaixo também conta como acerto. A UI mostra `8ª acima` ou
  `8ª abaixo` e posiciona o cursor na classe da nota-guia. Use
  `--no-octave-equivalence` para exigir a oitava exata.
- **Pontuação por nota e ataque**: cada nota acumula pitch e mede o atraso do
  primeiro acerto (ataque). O score final combina 85% de pitch e 15% de ritmo
  de ataque, configurável em `ScoringConfig.rhythm_weight`.
- **Score por linha e gráfico de pitch**: o resultado final mostra as linhas
  melhor/pior e um gráfico com gabarito verde e voz branca.
- **Ranking local**: cada resultado é salvo e o top 5 aparece no fim.
- **Gravação da voz**: o áudio do microfone é salvo em
  `%APPDATA%\KaraokeMVP\recordings` ao final da música.
- **Modo prática**: `--loop-start/--loop-end` recortam o trecho,
  `--speed 0.4..1.6` ajusta a velocidade e `--practice-loop` repete.
  O loop/velocidade valem para o acompanhamento MIDI sintetizado;
  áudio externo toca na velocidade original.
- Pitch ausente/ruído conta como erro naquele intervalo.
- Cada acerto incrementa o combo; um erro zera o combo.
- Os pontos são cumulativos e recebem um multiplicador de combo limitado a 2×.
- O resultado é limitado a 0–100 e arredondado para uma casa decimal.

A grade fixa garante que dois computadores cheguem ao mesmo resultado para o
mesmo desempenho, mesmo que um rode a 60 FPS e outro a 144 FPS.

![Canto uma oitava abaixo da guia](docs/octave.png)

### Sincronização

O relógio da música usa `time.perf_counter()` — monotônico e de alta resolução.
`time.time()` pode saltar com ajustes de NTP. A contagem regressiva permite que
o stream de áudio estabilize antes da primeira nota.

> Latência de entrada do sistema (driver, Bluetooth, buffer) não é calibrada
> automaticamente neste MVP. Em casos de atraso perceptível, a tolerância e a
> contagem regressiva ajudam, mas o próximo passo ideal é um assistente de
> calibração de latência.

---

## 7. Música de fundo

A ordem de prioridade é:

1. **Áudio irmão do `.kar`** — mesma pasta e mesmo nome:
   `musica.kar` + `musica.wav`, `musica.ogg` ou `musica.mp3`;
   também aceita `musica.backing.wav` (ou `.ogg`/`.mp3`).
2. **Síntese do MIDI** — as notas de acompanhamento extraídas do próprio
   `.kar`, incluindo baixo, acordes e percussão.
3. **Fallback** — se o arquivo só tiver a melodia, ela é tocada como base.

A fonte melódica escolhida para o gabarito é **silenciada** no acompanhamento;
assim a voz guia não compete com o cantor. O áudio começa quando a contagem
regressiva termina, e o relógio da música é reancorado nesse instante para
manter letra, piano roll e som alinhados.

O áudio irmão precisa estar alinhado ao mapa MIDI (mesma introdução e mesmo
andamento). Para qualidade de estúdio, essa é a melhor opção; a síntese interna
é simples (sem SoundFont), pensada para o MVP.

Na tela de preparação aparece a fonte usada, por exemplo
`Acompanhamento: MIDI sintetizado` ou `Acompanhamento: musica.wav`.

![Preparação com acompanhamento](docs/ready.png)

Controle pela CLI:

```bash
python run.py song.kar --backing-volume 0.7
python run.py song.kar --no-backing
```

O WAV sintetizado é gerado em memória, sem arquivos temporários.

---

## 8. Interface

- **Tela inicial:** seleção de `.kar` pelo diálogo nativo, drag-and-drop, demo,
  seletor de codificação das letras, transposição e biblioteca.
- **Biblioteca:** favoritos e recentes clicáveis; estrela para favoritar;
  atalho `L`.
- **Cabeçalho:** título, nota-guia atual, pontuação, combo, pontos e ícones de
  pausa/troca de música.
- **Pausa:** congela áudio, relógio, letra e pontuação; retoma do ponto exato.
- **Troca de música:** fecha o jogo atual e volta ao seletor sem encerrar o
  processo.
- **Piano roll:** janela de 9 s, notas futuras em azul, notas passadas em verde
  escuro, nota ativa em destaque e linha do tempo no playhead.
- **Cursor de voz:** marcador circular no pitch atual, com nome da nota e
  desvio em cents; fica verde/amarelo/vermelho conforme a distância da guia.
- **Letras:** linha atual grande, próxima linha esmaecida, quebras de linha do
  `.kar` respeitadas e **bolinha** que percorre e pula sobre a sílaba/palavra
  no instante exato em que ela deve ser cantada.
- **Bolinha de karaokê:** usa os timestamps dos eventos de letra do `.kar`;
  o trecho ativo fica destacado e a bolinha faz um arco sobre ele, trocando de
  posição a cada sílaba/palavra.
- **Overlays:** preparação, contagem regressiva, fim da música e erro de
  microfone.
- **Rodapé:** dispositivo, pitch, tempo e controles.
- **Ajustes na pausa:** volume do acompanhamento, latência de entrada, offset
  da letra e metrônomo da contagem, com botões `−`/`+`.
- **Persistência:** dispositivo, volume, offsets, tolerância, oitavas, encoding,
  metrônomo, tamanho da janela e músicas recentes são salvos em
  `%APPDATA%\KaraokeMVP\settings.json`.
- **Carregamento:** a tela “Preparando acompanhamento…” aparece enquanto o
  áudio sintetizado é gerado.

![Menu de pausa](docs/pause.png)

![Resultado final com gráfico de pitch](docs/finished.png)

A janela é redimensionável, com tamanho mínimo de 960×600.

---

## 9. Tratamento de erros

| Situação | Comportamento |
|---|---|
| Arquivo inexistente/corrompido | `MidiParseError`, mensagem na CLI |
| Nenhuma pista/canal com notas | `EmptyMelodyError` com pistas inspecionadas |
| Canal 10 selecionado | erro explicando que é percussão |
| Letra ausente | aviso; piano roll continua |
| PyAudio ausente | instrução de instalação |
| Microfone não encontrado | overlay com `--list-devices` e dica de permissão |
| Taxa de amostragem não suportada | mensagem sugerindo outra taxa |
| Queda da captura em execução | pontuação é finalizada e overlay de erro |
| Arquivo SMF tipo 2 | erro explicando converter para tipo 0/1 |

O modo `--debug` imprime traceback completo e FPS.

---

## 10. Testes

```bash
python -m pytest -q
```

Cobertura atual (64 testes):

- conversão Hz ↔ MIDI e nomes de nota;
- YIN com senoides, harmônicos, silêncio e ruído;
- parser com mapa de tempo/BPM, sobreposição de notas, canal de percussão,
  pista vazia, fallback de letra `text`, acentos, linhas sincronizadas e
  partes de letra cronometradas para a bolinha;
- scoring com pitch perfeito, errado, silencioso, no limite da tolerância,
  oitavas acima/abaixo, modo estrito, gaps instrumentais e independência de FPS;
- métricas por nota, ataque/ritmo, score por linha e traço de pitch;
- histórico de pitch com amostras velhas, silêncio e baixa confiança;
- launcher carregando a demo, erro de arquivo inexistente e caminho do pacote;
- atalho `M` retornando ao seletor sem abrir microfone;
- síntese do acompanhamento em WAV mono, áudio irmão e player Pygame;
- fallback de arquivo só com melodia;
- pausa/retomada do relógio e do canal de áudio;
- persistência e normalização das configurações;
- menu de pausa com volume, latência, offset e metrônomo;
- transposição de melodia/acompanhamento e cache de acompanhamento;
- seletor de encoding do launcher e reparo de mojibake;
- smoke test headless da UI em todos os estados, incluindo pausa, botões e
  renderização da letra com bolinha.

Os testes não abrem microfone. A UI usa `SDL_VIDEODRIVER=dummy` no ambiente de
teste.

---

## 11. Limitações conscientes do MVP

- **Síntese simples**: o acompanhamento MIDI usa senoides/harmônicos e
  percussão, sem SoundFont. Para qualidade de produção, use o áudio irmão.
- **Guia monofônico**: em acordes, a nota mais aguda vira referência.
- **Sem transposição de tonalidade**: o cantor precisa cantar na tonalidade do
  arquivo. Oitavas equivalentes são aceitas, mas não há transposição
  automática da música.
- **Sem calibração de latência** por dispositivo.
- **Sem ranking persistente**, gravação ou exportação de resultado.
- **Heurística de pista**: arquivos muito atípicos podem exigir `--track` e
  `--channel`.
- **Encoding**: o modo `auto` cobre UTF-8/CP1252/Latin-1/Shift-JIS e tenta
  reparar mojibake. Para arquivos com outra codificação, use o chip
  **LETRAS** no launcher ou `--encoding`.
- **Formatos**: `.kar/.mid/.midi`, UltraStar `.txt` e LRC `.lrc` com MIDI
  irmão de mesmo nome para fornecer a melodia.
- **Onefile**: a versão de arquivo único extrai DLLs para `%TEMP%`; a versão em
  pasta é mais robusta em ambientes restritos.

### Próximos passos sugeridos

1. SoundFont/`fluidsynth` e mixer com compressão para acompanhamento sintético
   com timbres mais realistas.
2. Calibração de latência e modo WASAPI de baixa latência no Windows.
3. Transposição de tonalidade e visualização da oitava cantada.
4. Estatísticas por nota, gráfico de pitch e pontuação por sílaba.
5. Ranking local (SQLite), histórico e exportação.
6. Suporte a UltraStar/MusicXML e karaokê em vídeo.

---

## 12. Solução de problemas

### `PyAudio` não instala

- Linux: `sudo apt-get install portaudio19-dev python3-dev build-essential`.
- macOS: `brew install portaudio`.
- Windows: prefira Python 3.10–3.12 com wheel oficial; se compilar do zero,
  instale as Build Tools do Visual Studio.

### Nenhum microfone encontrado

```bash
python run.py --list-devices
```

Verifique as permissões de microfone do sistema (Windows: Configurações →
Privacidade → Microfone). Se houver mais de um dispositivo, escolha com
`--device N`.

### Música sem letra ou pista errada

- O app mostra um aviso quando não encontra letra.
- Use `--track`/`--channel` para apontar a pista vocal correta.

### Pitch oscilando muito

- Aproxime o microfone, reduza ruído ambiente e evite alto-falantes.
- Para vozes mais graves/agudas, o detector cobre 65–1000 Hz por padrão.

### Acentos errados nas letras

1. No launcher, clique no chip **LETRAS: ...** no canto superior direito.
2. Ele alterna `AUTOMÁTICO → WINDOWS-1252 → UTF-8 → LATIN-1 → SHIFT-JIS`.
3. Selecione o arquivo novamente. Para a maioria dos `.kar` brasileiros,
   **WINDOWS-1252** funciona.
4. Se a música já estiver aberta, pressione **M** (ou clique na pasta) para
   voltar ao seletor, troque a codificação e abra de novo.

### O acompanhamento não toca

- Confira o volume do Windows e a saída de áudio padrão.
- A música só começa quando a contagem regressiva termina.
- Para usar um áudio de qualidade, coloque `musica.wav`, `.ogg` ou `.mp3` ao
  lado de `musica.kar`, com o mesmo alinhamento do MIDI.
- Use `--backing-volume 0.8`; `--no-backing` desliga intencionalmente.
- Se a síntese falhar, o app mostra o motivo na tela de preparação.

### O `.exe` não abre ou o Windows mostra SmartScreen

- O executável não é assinado digitalmente. No SmartScreen, use
  **Mais informações → Executar assim mesmo**.
- Não mova `KaraokeMVP.exe` para fora da pasta: ele precisa do `_internal`.
- Prefira a versão em pasta. O modo `-OneFile` extrai DLLs para `%TEMP%` e pode
  falhar em ambientes com essa pasta bloqueada.
- Se o antivírus bloquear, adicione a pasta do aplicativo à lista de exceções.

---

## 13. Recriar a demo

A demo foi gerada sem arquivos externos:

```bash
python tools/generate_demo_kar.py
```

Ela contém melodia no canal 1, baixo no canal 2, acordes no canal 3,
percussão no canal 10 e quatro linhas de letra em português. A melodia guia é
silenciada no acompanhamento; baixo, acordes e bateria são sintetizados.

---

Projeto de estudo/MVP. Sinta-se livre para adaptar a arquitetura, os limiares e
a interface para o seu caso de uso.
