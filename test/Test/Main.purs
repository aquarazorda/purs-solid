module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Class.Console (log)
import Test.AdvancedUtility as AdvancedUtility
import Test.ComponentApi as ComponentApi
import Test.Context as Context
import Test.Control as Control
import Test.EventAdapters as EventAdapters
import Test.Lifecycle as Lifecycle
import Test.Meta as Meta
import Test.Resource as Resource
import Test.Secondary as Secondary
import Test.Signal as Signal
import Test.Start.Core as StartCore
import Test.Start.Entry as StartEntry
import Test.Start.Manifest as StartManifest
import Test.Start.MetaAssets as StartMetaAssets
import Test.Start.Middleware as StartMiddleware
import Test.Start.RequestEvent as StartRequestEvent
import Test.Start.Router as StartRouter
import Test.Start.Routing as StartRouting
import Test.Start.Runtime as StartRuntime
import Test.Start.Server as StartServer
import Test.Start.ServerFunction as StartServerFunction
import Test.Start.Session as StartSession
import Test.Store as Store
import Test.UI as UI
import Test.Utility as Utility
import Test.Web as Web
import Test.WebSSR as WebSSR

runSuite :: String -> Effect Unit -> Effect Unit
runSuite label suite = do
  log (label <> " tests starting")
  suite

main :: Effect Unit
main = do
  runSuite "Signal" Signal.run
  log "Signal tests passed"
  runSuite "Component API" ComponentApi.run
  runSuite "Advanced utility" AdvancedUtility.run
  runSuite "Utility" Utility.run
  runSuite "Lifecycle" Lifecycle.run
  runSuite "Secondary primitive" Secondary.run
  runSuite "Resource" Resource.run
  runSuite "Context" Context.run
  runSuite "Meta" Meta.run
  runSuite "Event adapters" EventAdapters.run
  runSuite "Control" Control.run
  runSuite "Store" Store.run
  runSuite "UI" UI.run
  runSuite "Web" Web.run
  runSuite "Web SSR" WebSSR.run
  runSuite "Start core" StartCore.run
  runSuite "Start entry" StartEntry.run
  runSuite "Start routing" StartRouting.run
  runSuite "Start manifest" StartManifest.run
  runSuite "Start meta/assets" StartMetaAssets.run
  runSuite "Start middleware" StartMiddleware.run
  runSuite "Start request event" StartRequestEvent.run
  runSuite "Start runtime" StartRuntime.run
  runSuite "Start server" StartServer.run
  runSuite "Start router" StartRouter.run
  runSuite "Start server function" StartServerFunction.run
  runSuite "Start session" StartSession.run
  log "All tests passed"
