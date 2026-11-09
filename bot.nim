import std/[asyncdispatch, times, strutils]
import types, api

type
  BotInstance* = ref object
    config*: AccountConfig
    api*: FarmClient
    accountData*: AccountData
    activeLevel*: string
    kills*: int
    gold*: int64
    exp*: int64
    currentLevel*: int
    running*: bool
    status*: string
    logs*: seq[string]
    startTime*: Time
    holderId*: string

proc newBotInstance*(config: AccountConfig): BotInstance =
  new(result)
  result.config = config
  result.api = newFarmClient(config)
  result.activeLevel = if config.settings.targetLevelCode.len > 0: config.settings.targetLevelCode else: "level-1"
  result.kills = 0
  result.gold = 0
  result.exp = 0
  result.currentLevel = 1
  result.running = false
  result.status = "Iniciando"
  result.logs = @[]
  result.startTime = getTime()
  result.holderId = newUUID4()

proc addLog*(self: BotInstance, msg: string) =
  if self.logs.len >= 20:
    self.logs.delete(0)
  self.logs.add(msg)

proc initSession*(self: BotInstance) {.async.} =
  echo "Verificando bootstrap e sessão no Farm Ricochet para [", self.config.name, "]..."
  let lease = await self.api.acquireSessionLease(self.holderId)
  if lease.success:
    self.addLog("⚡ Sessão adquirida com sucesso (Lease)")

  let boot = await self.api.getBootstrap()
  if boot.hasAccount:
    self.accountData = boot.account
    self.currentLevel = boot.account.level
    self.gold = boot.account.gold
    self.addLog("Conectado como " & boot.account.username & " (Lv. " & $boot.account.level & ")")
  if boot.hasActiveLevel and self.config.settings.targetLevelCode.len == 0:
    self.activeLevel = boot.activeLevel.code

proc runCampaignStep*(self: BotInstance) {.async.} =
  let lvl = self.activeLevel
  self.status = "Jogando Fase " & lvl
  echo "🏹 [Campanha] Iniciando fase '", lvl, "'..."

  let runStart = await self.api.startRun(lvl)
  if runStart.success and runStart.runId.len > 0:
    let delayMs = int(4000.0 * max(0.2, self.config.settings.speedMultiplier))
    await sleepAsync(delayMs)

    let comp = await self.api.completeRun(runStart.runId)
    if comp.success:
      echo "🎉 Fase '", lvl, "' concluída com sucesso! +", comp.xp, " XP, +", comp.gold, " Gold"
      self.kills += 15
      self.gold += comp.gold
      self.exp += comp.xp
      self.addLog("Vitória na fase " & lvl & " (+ " & $comp.gold & " Gold)")
    else:
      echo "⚠️ Falha ao completar run: ", runStart.runId
  else:
    echo "⚠️ Falha ao iniciar run na fase '", lvl, "'"

proc runLoop*(self: BotInstance) {.async.} =
  self.running = true
  echo "🚀 Bot [", self.config.name, "] (Farm Ricochet Nim) iniciado com sucesso."
  await self.initSession()

  # 1. Loop de Heartbeat da sessão
  proc heartbeatWorker() {.async.} =
    while self.running:
      await sleepAsync(30000)
      if self.running:
        discard await self.api.heartbeatSessionLease(self.holderId)

  # 2. Loop de Campanha / Caça
  proc campaignWorker() {.async.} =
    while self.running:
      if self.config.settings.autoHunt:
        await self.runCampaignStep()
      await sleepAsync(6000)

  # 3. Loop de Coleta de Loot e Baús Diários
  proc lootWorker() {.async.} =
    while self.running:
      await sleepAsync(60000)
      if self.running:
        discard await self.api.claimRunLoot()
        if self.config.settings.autoChests:
          discard await self.api.openChest("free-daily")

  asyncCheck heartbeatWorker()
  asyncCheck campaignWorker()
  asyncCheck lootWorker()
