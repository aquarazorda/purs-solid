module Site.Samples.Reactivity where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect.Console (log)
import Solid.Component as Component
import Solid.DOM.HTML as H
import Solid.Reactivity (createEffect, createMemo)
import Solid.Signal (createSignal, modify_)

-- region signals
stepper :: Component.Component { step :: Int }
stepper = Component.component \props -> do
  count /\ setCount <- createSignal 0
  label <- createMemo ((\n -> "count: " <> show n) <$> count)
  createEffect count \n -> do
    log ("count is now " <> show n)
    pure (pure unit)
  pure $ H.button { onClick: \_ -> modify_ setCount (_ + props.step) } label
-- endregion
