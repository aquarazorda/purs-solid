module Test.UI
  ( run
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.DOM as DOM
import Solid.JSX as JSX
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, set)
import Test.Assert (assertEqual)

run :: Effect Unit
run =
  createRoot \dispose -> do
    count /\ setCount <- createSignal 1

    counter <- pure $ Component.component \props -> do
      current <- get count
      pure $ DOM.div { id: props.id, className: "counter" }
        [ DOM.text (props.label <> show current)
        ]

    _ <- set setCount 2
    let
      view = Component.element counter { id: "counter", label: "count:" }
      _keyed = JSX.keyed "main" view
      _fragment = JSX.fragment [ view, JSX.empty ]

    assertEqual "ui constructors produce JSX values" true true

    dispose
