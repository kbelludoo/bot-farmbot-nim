import std/[asyncdispatch, json, os, strutils, times, math]
import types, supervisor, dashboard

# ==============================================================================
# MEDIÇÃO NATIVA DE MEMÓRIA (LINUX & WINDOWS)
# ==============================================================================
when defined(windows):
  type
    PROCESS_MEMORY_COUNTERS = object
      cb: uint32
      PageFaultCount: uint32
      PeakWorkingSetSize: uint
      WorkingSetSize: uint
      QuotaPeakPagedPoolUsage: uint
      QuotaPagedPoolUsage: uint
      QuotaPeakNonPagedPoolUsage: uint
      QuotaNonPagedPoolUsage: uint
      PagefileUsage: uint
      PeakPagefileUsage: uint

  proc GetCurrentProcess(): pointer {.stdcall, dynlib: "kernel32", importc.}
  proc GetProcessMemoryInfo(hProcess: pointer, ppsmps: ptr PROCESS_MEMORY_COUNTERS, cb: uint32): int32 {.stdcall, dynlib: "psapi", importc.}

  proc getRealMemoryMB(): (float, float) =
    var pmc: PROCESS_MEMORY_COUNTERS
    pmc.cb = uint32(sizeof(pmc))
    let hProc = GetCurrentProcess()
    if GetProcessMemoryInfo(hProc, addr pmc, pmc.cb) != 0:
      let wsMB = float(pmc.WorkingSetSize) / 1024.0 / 1024.0
      let peakMB = float(pmc.PeakWorkingSetSize) / 1024.0 / 1024.0
      return (wsMB, peakMB)
    return (0.0, 0.0)

elif defined(linux):
  proc getRealMemoryMB(): (float, float) =
    try:
      let statm = readFile("/proc/self/statm").strip().split()
      if statm.len >= 2:
        # statm[1] é o resident set size em páginas (geralmente 4KB)
        let pages = parseBiggestInt(statm[1])
        let mb = float(pages * 4096) / 1024.0 / 1024.0
        return (mb, mb)
    except CatchableError:
      discard
    return (0.0, 0.0)
else:
  proc getRealMemoryMB(): (float, float) =
    return (0.0, 0.0)

# ==============================================================================
# TICKER DE CONSOLE
# ==============================================================================
proc startConsoleTicker(sup: Supervisor, port: int) {.async.} =
  var tick = 0
  while true:
    await sleepAsync(4000)
    inc tick

    var totalKills = 0
    var totalGold: int64 = 0
    var totalExp: int64 = 0
    let (wsMB, _) = getRealMemoryMB()

    for b in sup.bots:
      totalKills += b.kills
      totalGold += b.gold
      totalExp += b.exp

    let memStr = if wsMB > 0.0: " | RAM Real: " & $(round(wsMB, 2)) & " MB" else: ""
    echo "[Console Ticker #", tick, "] Contas: ", sup.bots.len,
         " | Kills: ", totalKills,
         " | Gemas & Ouro: ", formatNumber(totalGold),
         " | Exp: ", formatNumber(totalExp),
         memStr

# ==============================================================================
# MAIN
# ==============================================================================
proc main() =
  echo "================================================================================"
  echo "       ⚡ FARM RICOCHET NATIVE NIM BOT (ZERO-GC & ALTA PERFORMANCE) ⚡        "
  echo "================================================================================"

  let configPath = "accounts.json"
  if not fileExists(configPath):
    echo "Aviso: accounts.json não encontrado. Criando modelo padrão..."
    writeFile(configPath, """[
  {
    "id": "farm-1",
    "name": "kbelludoo",
    "enabled": true,
    "credentials": {
      "cookie": "",
      "email": ""
    },
    "settings": {
      "autoHunt": true,
      "autoAdvancePhase": true,
      "autoChests": true,
      "autoMissions": true,
      "autoTransmute": false,
      "autoDismantle": true,
      "speedMultiplier": 2.5
    }
  }
]""")

  let content = readFile(configPath)
  let rootNode = parseJson(content)

  let targetAcc = getEnv("ACCOUNT", "")
  var activeConfigs: seq[AccountConfig] = @[]

  for item in rootNode:
    let cfg = parseAccountConfig(item)
    if not cfg.enabled and cfg.id != targetAcc:
      continue
    if targetAcc.len > 0 and cfg.id != targetAcc:
      continue
    activeConfigs.add(cfg)

  if activeConfigs.len == 0:
    echo "⚠️ Nenhuma conta com 'enabled: true' encontrada em accounts.json."
    echo "Edite accounts.json e habilite sua conta para iniciar o bot."

  let supervisor = newSupervisor(activeConfigs)
  asyncCheck supervisor.startAll()

  var port = 3013
  let portEnv = getEnv("PORT", "")
  if portEnv.len > 0:
    try:
      port = parseInt(portEnv)
    except ValueError:
      discard

  let webServer = newWebServer(supervisor, port)
  asyncCheck webServer.start()
  asyncCheck startConsoleTicker(supervisor, port)

  runForever()

when isMainModule:
  main()
