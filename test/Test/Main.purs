-- | Client test entry point. Run with `--conditions=browser --conditions=development`
-- | so Solid resolves its client dev build (see `npm run test:client`). Suites
-- | written with `Test.Solid.solidIt` fail on any Solid dev diagnostic.
module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Class (liftEffect)
import Test.Core.Action as Action
import Test.Core.Async as Async
import Test.Core.Component as Component
import Test.Core.Context as Context
import Test.Core.Lifecycle as Lifecycle
import Test.Core.Reactivity as Reactivity
import Test.Core.Router as Router
import Test.Core.Signal as Signal
import Test.Core.Store as Store
import Test.Core.Utility as Utility
import Test.Core.View as View
import Test.EventAdapters as EventAdapters
import Test.Spec (Spec, describe, it)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)

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
    Store.spec
    Action.spec
    Component.spec
    View.spec
    Router.spec
  describe "DOM adapters" do
    it "Event adapters" (liftEffect EventAdapters.run)
