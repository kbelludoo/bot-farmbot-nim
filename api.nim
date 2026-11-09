import std/[asyncdispatch, httpclient, json, strutils, random, sysrand]
import types

type
  FarmClient* = ref object
    client*: AsyncHttpClient
    baseUrl*: string
    cookie*: string

proc toHexStr(s: openArray[byte]): string =
  result = ""
  for b in s:
    result.add(toHex(int(b), 2).toLowerAscii)

proc newUUID4*(): string =
  var bytes: array[16, byte]
  if not urandom(bytes):
    randomize()
    for i in 0 .. 15:
      bytes[i] = byte(rand(255))
  bytes[6] = (bytes[6] and 0x0F) or 0x40 # Version 4
  bytes[8] = (bytes[8] and 0x3F) or 0x80 # Variant RFC 4122
  result = toHexStr(bytes[0..3]) & "-" &
           toHexStr(bytes[4..5]) & "-" &
           toHexStr(bytes[6..7]) & "-" &
           toHexStr(bytes[8..9]) & "-" &
           toHexStr(bytes[10..15])

proc newFarmClient*(config: AccountConfig): FarmClient =
  new(result)
  result.baseUrl = if config.credentials.origin.len > 0:
                     config.credentials.origin.strip(chars = {'/'})
                   else:
                     "https://api.farmricochet.com"
  result.cookie = config.credentials.cookie
  result.client = newAsyncHttpClient()

  var headers = newHttpHeaders([
    ("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"),
    ("Origin", "https://farmricochet.com"),
    ("Referer", "https://farmricochet.com/play"),
    ("Content-Type", "application/json")
  ])
  if result.cookie.len > 0:
    headers.add("Cookie", result.cookie)
  result.client.headers = headers

proc acquireSessionLease*(self: FarmClient, holderId: string): Future[SessionLeaseResponse] {.async.} =
  let url = self.baseUrl & "/api/v1/game-session"
  let body = $(%*{"holderId": holderId, "force": true})
  try:
    let resp = await self.client.post(url, body)
    let text = await resp.body
    if resp.code.is1xx or resp.code == Http200 or resp.code == Http201:
      let node = parseJson(text)
      result.success = true
      result.holderId = node{"holderId"}.getStr("")
      result.expiresAt = node{"expiresAt"}.getStr("")
    else:
      result.success = false
  except CatchableError as e:
    result.success = false

proc heartbeatSessionLease*(self: FarmClient, holderId: string): Future[bool] {.async.} =
  let url = self.baseUrl & "/api/v1/game-session"
  let body = $(%*{"holderId": holderId, "force": false})
  try:
    let resp = await self.client.request(url, httpMethod = HttpPut, body = body)
    result = resp.code == Http200 or resp.code == Http204
  except CatchableError:
    result = false

proc getBootstrap*(self: FarmClient): Future[BootstrapResponse] {.async.} =
  let url = self.baseUrl & "/api/v1/bootstrap?mapImages=cdn"
  try:
    let resp = await self.client.get(url)
    let text = await resp.body
    if resp.code == Http200:
      let node = parseJson(text)
      let acc = node{"account"}
      if acc != nil:
        result.hasAccount = true
        result.account.id = acc{"id"}.getStr("")
        result.account.username = acc{"username"}.getStr("")
        result.account.level = acc{"level"}.getInt(1)
        result.account.gold = acc{"gold"}.getBiggestInt(0)
        result.account.gems = acc{"gems"}.getBiggestInt(0)
      let lvl = node{"activeLevel"}
      if lvl != nil:
        result.hasActiveLevel = true
        result.activeLevel.code = lvl{"code"}.getStr("level-1")
        result.activeLevel.name = lvl{"name"}.getStr("Campanha")
  except CatchableError:
    discard

proc startRun*(self: FarmClient, levelCode: string): Future[RunStartResponse] {.async.} =
  let url = self.baseUrl & "/api/v1/runs/start"
  let body = $(%*{"levelCode": levelCode, "clientRequestId": newUUID4()})
  try:
    let resp = await self.client.post(url, body)
    let text = await resp.body
    if resp.code == Http200 or resp.code == Http201:
      let node = parseJson(text)
      result.success = true
      result.runId = node{"runId"}.getStr("")
      result.seed = node{"seed"}.getBiggestInt(0)
    else:
      result.success = false
  except CatchableError:
    result.success = false

proc completeRun*(self: FarmClient, runId: string): Future[RunCompleteResponse] {.async.} =
  let url = self.baseUrl & "/api/v1/runs/" & runId & "/complete"
  let body = $(%*{"durationMs": 4500, "result": "victory"})
  try:
    let resp = await self.client.post(url, body)
    let text = await resp.body
    if resp.code == Http200:
      let node = parseJson(text)
      result.success = node{"success"}.getBool(true)
      result.xp = node{"xp"}.getBiggestInt(0)
      result.gold = node{"gold"}.getBiggestInt(0)
    else:
      result.success = false
  except CatchableError:
    result.success = false

proc claimRunLoot*(self: FarmClient): Future[bool] {.async.} =
  let url = self.baseUrl & "/api/v1/run-loot/claim"
  let body = $(%*{"idempotencyKey": newUUID4()})
  try:
    let resp = await self.client.post(url, body)
    result = resp.code == Http200 or resp.code == Http204
  except CatchableError:
    result = false

proc openChest*(self: FarmClient, code: string): Future[bool] {.async.} =
  let url = self.baseUrl & "/api/v1/chests/" & code & "/open"
  let body = $(%*{"clientRequestId": newUUID4()})
  try:
    let resp = await self.client.post(url, body)
    result = resp.code == Http200 or resp.code == Http204
  except CatchableError:
    result = false
