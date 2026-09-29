-- | Client test entry point. Run with `--conditions=browser` so Solid resolves its
-- | client runtime (see `npm run test:client`).
module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Class (liftEffect)
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
import Test.Spec (Spec, describe, it)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.Store as Store
import Test.TypedDOM as TypedDOM
import Test.UI as UI
import Test.Utility as Utility
import Test.Web as Web

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] spec

spec :: Spec Unit
spec = describe "client" do
  it "Signal" (liftEffect Signal.run)
  it "Component API" (liftEffect ComponentApi.run)
  it "Advanced utility" (liftEffect AdvancedUtility.run)
  it "Utility" (liftEffect Utility.run)
  it "Lifecycle" (liftEffect Lifecycle.run)
  it "Secondary primitive" (liftEffect Secondary.run)
  it "Resource" (liftEffect Resource.run)
  it "Context" (liftEffect Context.run)
  it "Meta" (liftEffect Meta.run)
  it "Event adapters" (liftEffect EventAdapters.run)
  it "Control" (liftEffect Control.run)
  it "Store" (liftEffect Store.run)
  it "Typed DOM" (liftEffect TypedDOM.run)
  it "UI" (liftEffect UI.run)
  it "Web" (liftEffect Web.run)
