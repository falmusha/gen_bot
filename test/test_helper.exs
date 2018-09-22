Code.require_file("support/smokefreed_case.ex", __DIR__)

Mox.defmock(GenBot.Test.SingleStateMock, for: [GenBot, GenBot.BotState])
Mox.defmock(GenBot.Test.MultiStateMock, for: GenBot)
Mox.defmock(GenBot.Test.FooStateMock, for: GenBot.BotState)
Mox.defmock(GenBot.Test.BarStateMock, for: GenBot.BotState)
Mox.defmock(GenBot.Test.QuxStateMock, for: GenBot.BotState)

ExUnit.start()
