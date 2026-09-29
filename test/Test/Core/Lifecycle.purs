module Test.Core.Lifecycle
  ( spec
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Solid.Lifecycle (onCleanup, onSettled)
import Solid.Owner (getOwner, runWithOwner)
import Solid.Reactivity (createEffect_)
import Solid.Root (createRoot)
import Solid.Setup (liftSetup)
import Solid.Signal (createSignal, set)
import Test.Solid (expectDiagnostic, settle, solidIt)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

logTo :: Ref.Ref (Array String) -> String -> Effect Unit
logTo ref entry = Ref.modify_ (_ <> [ entry ]) ref

spec :: Spec Unit
spec = describe "lifecycle and ownership" do
  solidIt "onCleanup runs on dispose, last registered first" do
    log <- liftEffect (Ref.new [])
    dispose <- liftEffect $ createRoot \dispose -> do
      onCleanup (logTo log "first")
      onCleanup (logTo log "second")
      pure dispose
    liftEffect dispose
    liftEffect (Ref.read log) >>= shouldEqual [ "second", "first" ]

  solidIt "onSettled runs after setup, and its cleanup on dispose" do
    log <- liftEffect (Ref.new [])
    dispose <- liftEffect $ createRoot \dispose -> do
      onSettled do
        logTo log "settled"
        pure (logTo log "settled cleanup")
      liftSetup (logTo log "setup")
      pure dispose
    settle
    liftEffect dispose
    liftEffect (Ref.read log) >>= shouldEqual [ "setup", "settled", "settled cleanup" ]

  solidIt "a root created in Setup is owned by the enclosing owner" do
    log <- liftEffect (Ref.new [])
    dispose <- liftEffect $ createRoot \dispose -> do
      createRoot \_ -> onCleanup (logTo log "child disposed")
      pure dispose
    liftEffect dispose
    liftEffect (Ref.read log) >>= shouldEqual [ "child disposed" ]

  solidIt "runWithOwner creates computations under a captured owner" do
    log <- liftEffect (Ref.new [])
    parts <- liftEffect $ createRoot \dispose -> do
      owner <- getOwner
      value /\ setValue <- createSignal 0
      pure { owner, value, setValue, dispose }
    -- Later, from Effect code (e.g. an event handler):
    liftEffect $ runWithOwner parts.owner do
      createEffect_ parts.value \v -> logTo log (show v)
    settle
    liftEffect (set parts.setValue 1)
    settle
    liftEffect parts.dispose
    liftEffect (set parts.setValue 2)
    settle
    liftEffect (Ref.read log) >>= shouldEqual [ "0", "1" ]

  -- The types rule this out; this documents that Solid's dev build still
  -- guards the `liftSetup` escape hatch.
  it "a signal write smuggled into Setup is reported by Solid" do
    expectDiagnostic "REACTIVE_WRITE_IN_OWNED_SCOPE" do
      liftEffect do
        _ /\ setValue <- createSignal 0
        createRoot \_ -> liftSetup (set setValue 1)
