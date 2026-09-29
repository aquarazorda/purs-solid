-- | Client test entry point. Run with `--conditions=browser --conditions=development`
-- | so Solid resolves its client dev build (see `npm run test:client`). Suites
-- | written with `Test.Solid.solidIt` fail on any Solid dev diagnostic.
module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Class (liftEffect)
import Test.Control as Control
import Test.Core.Async as Async
import Test.Core.Component as Component
import Test.Core.Context as Context
import Test.Core.Lifecycle as Lifecycle
import Test.Core.Reactivity as Reactivity
import Test.Core.Signal as Signal
import Test.Core.Utility as Utility
import Test.EventAdapters as EventAdapters
import Test.Spec (Spec, describe, it, pending)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.TypedDOM as TypedDOM
import Test.UI as UI
import Test.Web as Web

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] spec

spec :: Spec Unit
spec = describe "client" do
  describe "core" do
    Signal.spec
    Reactivity.spec
    Lifecycle.spec
    Context.spec
    Async.spec
    Utility.spec
    Component.spec
  describe "view (transitional until Phase 3)" do
    it "Control" (liftEffect Control.run)
    it "Event adapters" (liftEffect EventAdapters.run)
    it "Typed DOM" (liftEffect TypedDOM.run)
    it "UI" (liftEffect UI.run)
    it "Web" (liftEffect Web.run)
  describe "pending migration" do
    pending "Store (Phase 2: typed paths over draft setters)"
    pending "Meta (Phase 5: @solidjs/meta 1.0 has no MetaProvider)"
