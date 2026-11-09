import std/json

type
  GameCredentials* = object
    cookie*: string
    sessionToken*: string
    email*: string
    origin*: string

  FarmBotSettings* = object
    autoHunt*: bool
    targetLevelCode*: string
    autoAdvancePhase*: bool
    autoChests*: bool
    autoMissions*: bool
    autoTransmute*: bool
    autoDismantle*: bool
    speedMultiplier*: float
    maxCampaignLevel*: int
    safetyMarginPhases*: int

  AccountConfig* = object
    id*: string
    name*: string
    enabled*: bool
    credentials*: GameCredentials
    settings*: FarmBotSettings

  AccountData* = object
    id*: string
    username*: string
    level*: int
    gold*: int64
    gems*: int64

  ActiveLevel* = object
    code*: string
    name*: string

  BootstrapResponse* = object
    hasAccount*: bool
    account*: AccountData
    hasActiveLevel*: bool
    activeLevel*: ActiveLevel

  SessionLeaseResponse* = object
    success*: bool
    holderId*: string
    expiresAt*: string

  RunStartResponse* = object
    success*: bool
    runId*: string
    seed*: int64

  RunCompleteResponse* = object
    success*: bool
    xp*: int64
    gold*: int64

proc parseAccountConfig*(item: JsonNode): AccountConfig =
  result.id = item{"id"}.getStr("bot-1")
  result.name = item{"name"}.getStr("Hunter")
  result.enabled = item{"enabled"}.getBool(true)

  let creds = item{"credentials"}
  if creds != nil:
    result.credentials.cookie = creds{"cookie"}.getStr("")
    result.credentials.sessionToken = creds{"sessionToken"}.getStr("")
    result.credentials.email = creds{"email"}.getStr("")
    result.credentials.origin = creds{"origin"}.getStr("")

  let sett = item{"settings"}
  if sett != nil:
    result.settings.autoHunt = sett{"autoHunt"}.getBool(true)
    result.settings.targetLevelCode = sett{"targetLevelCode"}.getStr("")
    result.settings.autoAdvancePhase = sett{"autoAdvancePhase"}.getBool(true)
    result.settings.autoChests = sett{"autoChests"}.getBool(true)
    result.settings.autoMissions = sett{"autoMissions"}.getBool(true)
    result.settings.autoTransmute = sett{"autoTransmute"}.getBool(false)
    result.settings.autoDismantle = sett{"autoDismantle"}.getBool(true)
    result.settings.speedMultiplier = sett{"speedMultiplier"}.getFloat(1.0)
    result.settings.maxCampaignLevel = sett{"maxCampaignLevel"}.getInt(514)
    result.settings.safetyMarginPhases = sett{"safetyMarginPhases"}.getInt(6)
  else:
    result.settings.autoHunt = true
    result.settings.speedMultiplier = 1.0
    result.settings.autoChests = true
    result.settings.autoMissions = true
