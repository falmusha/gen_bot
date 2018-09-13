Mox.defmock(BotKit.SingleMock, for: [BotKit.Bot, BotKit.BotState])
Mox.defmock(BotKit.MultiMock, for: BotKit.Bot)
Mox.defmock(BotKit.MultiFooStateMock, for: BotKit.BotState)
Mox.defmock(BotKit.MultiBarStateMock, for: BotKit.BotState)
Mox.defmock(BotKit.MultiQuxStateMock, for: BotKit.BotState)

ExUnit.start()
