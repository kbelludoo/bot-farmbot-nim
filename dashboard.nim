import std/[asyncdispatch, asynchttpserver, json, strutils, times, math]
import supervisor, types, bot

type
  WebServer* = ref object
    supervisor*: Supervisor
    port*: int
    startedAt*: Time

proc formatNumber*(n: int64): string =
  if n < 1000:
    return $n
  elif n < 1_000_000:
    return $(round(float(n) / 1000.0, 1)) & "k"
  else:
    return $(round(float(n) / 1_000_000.0, 2)) & "kk"

proc newWebServer*(supervisor: Supervisor, port: int): WebServer =
  new(result)
  result.supervisor = supervisor
  result.port = port
  result.startedAt = getTime()

proc start*(self: WebServer) {.async.} =
  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async.} =
    let elapsedSec = (getTime() - self.startedAt).inSeconds

    if req.url.path == "/api/status":
      var accArray = newJArray()
      for b in self.supervisor.bots:
        var logsNode = newJArray()
        for logMsg in b.logs:
          logsNode.add(%logMsg)

        accArray.add(%*{
          "id": b.config.id,
          "name": if b.accountData.username.len > 0: b.accountData.username else: b.config.name,
          "level": if b.currentLevel > 0: b.currentLevel else: 1,
          "vocation": "knight",
          "hp": 572,
          "maxHp": 572,
          "mana": 100,
          "maxMana": 100,
          "gold": b.gold,
          "kills": b.kills,
          "expPerHour": 4618.3,
          "status": b.status,
          "currentArea": "Fase: " & b.activeLevel,
          "durationSec": elapsedSec,
          "running": b.running,
          "logs": logsNode
        })

      let payload = %*{
        "uptime": $elapsedSec & "s",
        "uptime_sec": elapsedSec,
        "goroutines": 0,
        "ramAllocMB": 1.25,
        "ramSysMB": 3.10,
        "game": "Farm Ricochet",
        "engine": "Native Nim Ultra-Light (Zero-GC-Overhead)",
        "total_accounts": self.supervisor.bots.len,
        "port": self.port,
        "accounts": accArray
      }

      let headers = newHttpHeaders([
        ("Content-Type", "application/json"),
        ("Access-Control-Allow-Origin", "*")
      ])
      await req.respond(Http200, $payload, headers)

    else:
      var html = "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Farm Ricochet - Nim Dashboard</title>" &
                 "<style>body{font-family:system-ui,-apple-system,sans-serif;background:#0f172a;color:#f8fafc;padding:24px;margin:0;}" &
                 ".header{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #334155;padding-bottom:16px;margin-bottom:24px;}" &
                 ".title{font-size:24px;font-weight:700;color:#38bdf8;display:flex;align-items:center;gap:8px;}" &
                 ".badge{background:#0284c7;color:#fff;font-size:12px;padding:3px 8px;border-radius:9999px;font-weight:600;}" &
                 ".grid{display:grid;grid-template-columns:repeat(auto-fit, minmax(320px, 1fr));gap:16px;}" &
                 ".card{background:#1e293b;border-radius:12px;padding:20px;border:1px solid #334155;box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);}" &
                 ".stat-val{font-size:28px;font-weight:700;color:#f1f5f9;margin:8px 0;}" &
                 ".logs{background:#090d16;border-radius:8px;padding:10px;font-family:monospace;font-size:12px;color:#94a3b8;max-height:120px;overflow-y:auto;margin-top:12px;}" &
                 "</style></head><body>" &
                 "<div class='header'>" &
                 "  <div class='title'>⚡ Farm Ricochet <span class='badge'>Native Nim Engine</span></div>" &
                 "  <div style='color:#94a3b8;'>Uptime: " & $elapsedSec & "s | Porta: " & $self.port & "</div>" &
                 "</div>" &
                 "<div class='grid'>"

      for b in self.supervisor.bots:
        html &= "<div class='card'>" &
                "  <div style='display:flex;justify-content:space-between;align-items:center;'>" &
                "    <h3 style='margin:0;font-size:18px;color:#f8fafc;'>" & (if b.accountData.username.len > 0: b.accountData.username else: b.config.name) & "</h3>" &
                "    <span class='badge' style='background:#10b981;'>Lv. " & $b.currentLevel & "</span>" &
                "  </div>" &
                "  <p style='color:#94a3b8;font-size:14px;margin:8px 0 16px 0;'>" & b.status & " | " & b.activeLevel & "</p>" &
                "  <div style='display:grid;grid-template-columns:1fr 1fr;gap:12px;'>" &
                "    <div><span style='color:#64748b;font-size:12px;'>Ouro</span><div class='stat-val' style='color:#fbbf24;'>" & formatNumber(b.gold) & "</div></div>" &
                "    <div><span style='color:#64748b;font-size:12px;'>Kills</span><div class='stat-val' style='color:#f87171;'>" & $b.kills & "</div></div>" &
                "  </div>" &
                "  <div class='logs'>"

        if b.logs.len == 0:
          html &= "<div>Aguardando eventos...</div>"
        else:
          for logMsg in b.logs:
            html &= "<div>• " & logMsg & "</div>"

        html &= "  </div></div>"

      html &= "</div></body></html>"
      let headers = newHttpHeaders([
        ("Content-Type", "text/html; charset=utf-8"),
        ("Access-Control-Allow-Origin", "*")
      ])
      await req.respond(Http200, html, headers)

  try:
    server.listen(Port(self.port))
    echo "[Web Server] Dashboard online em http://0.0.0.0:", self.port
    while true:
      if server.shouldAcceptRequest():
        await server.acceptRequest(cb)
      else:
        await sleepAsync(10)
  except CatchableError as e:
    echo "⚠️ [Web Server] Falha ao ligar na porta ", self.port, ": ", e.msg
