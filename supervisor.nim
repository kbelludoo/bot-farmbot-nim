import std/asyncdispatch
import types, bot

type
  Supervisor* = ref object
    bots*: seq[BotInstance]

proc newSupervisor*(configs: seq[AccountConfig]): Supervisor =
  new(result)
  result.bots = @[]
  for cfg in configs:
    result.bots.add(newBotInstance(cfg))

proc startAll*(self: Supervisor) {.async.} =
  for b in self.bots:
    asyncCheck b.runLoop()
