-- | Server test entry point. Run with Node's default export conditions so Solid
-- | resolves its server runtime (see `npm run test:server`).
module Test.Server.Main where

import Prelude

import Effect (Effect)
import Effect.Class (liftEffect)
import Test.Spec (Spec, describe, it)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
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
import Test.Server.SSR as SSR

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] spec

spec :: Spec Unit
spec = describe "server" do
  SSR.spec
  it "Start core" (liftEffect StartCore.run)
  it "Start entry" (liftEffect StartEntry.run)
  it "Start routing" (liftEffect StartRouting.run)
  it "Start manifest" (liftEffect StartManifest.run)
  it "Start meta/assets" (liftEffect StartMetaAssets.run)
  it "Start middleware" (liftEffect StartMiddleware.run)
  it "Start request event" (liftEffect StartRequestEvent.run)
  it "Start runtime" StartRuntime.run
  it "Start server" (liftEffect StartServer.run)
  it "Start router" (liftEffect StartRouter.run)
  it "Start server function" StartServerFunction.run
  it "Start session" (liftEffect StartSession.run)
