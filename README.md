# Farm Ricochet Native Nim Bot (Ultra-Light)

Bot autônomo de alta performance para o jogo **Farm Ricochet**, reescrito em **Nim 2.2** com gerenciamento de memória ORC (`--mm:orc`), consumo ultra-baixo de RAM (< 15MB) e 100% de paridade com as versões em Go e Rust.

## Funcionalidades
- **Campanha Automática**: Progressão de fases com cálculo dinâmico de tempo e multiplicador de velocidade.
- **Gestão de Sessão**: Acquire e heartbeat periódico de lease de sessão.
- **Dashboard e API HTTP**: Endpoint `/api/status` na porta 3013 com métricas em tempo real e interface web integrada.
- **Furtividade Anti-Detecção**: Jitter orgânico contínuo em todos os loops e pausas de pacing humano.
- **Multi-Contas**: Suporte a execução de múltiplas contas simultâneas via `accounts.json`.

## Compilação

### Linux (Cross-compilação com Zig):
```bash
nim c --os:linux --cpu:amd64 --gcc.exe:zigcc-linux-gnu.bat --gcc.linkerexe:zigcc-linux-gnu.bat -d:ssl -d:release -o:farmbot-linux-nim main.nim
```

### Windows:
```bash
nim c -d:ssl -d:release -o:farmbot-nim.exe main.nim
```
