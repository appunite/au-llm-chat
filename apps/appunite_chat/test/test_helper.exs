import Mox

defmock(AppuniteChat.TavilyMock, for: AppuniteChat.TavilyBehaviour)

defmock(AppuniteChat.WebSearchStateTrackerMock,
  for: AppuniteChat.Agents.Tools.WebSearchStateTrackerBehaviour
)

ExUnit.start()
