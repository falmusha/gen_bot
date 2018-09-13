Mox.defmock(GenBot.SingleStateMock, for: [GenBot, GenBot.BotState])
Mox.defmock(GenBot.MultiStateMock, for: GenBot)
Mox.defmock(GenBot.FooStateMock, for: GenBot.BotState)
Mox.defmock(GenBot.BarStateMock, for: GenBot.BotState)
Mox.defmock(GenBot.QuxStateMock, for: GenBot.BotState)

ExUnit.start()
