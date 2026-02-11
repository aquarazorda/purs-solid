module Test.ComponentApi
  ( run
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.JSX as JSX
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get)
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  createRoot \dispose -> do
    firstId <- Component.createUniqueId
    secondId <- Component.createUniqueId

    assertEqual "createUniqueId returns non-empty id" false (firstId == "")
    assertEqual "createUniqueId returns different ids" false (firstId == secondId)

    currentChild /\ _setChild <- createSignal (JSX.text "child")
    resolvedChildren <- Component.children (get currentChild)
    _ <- get resolvedChildren

    let
      lazyWidget =
        Component.lazy
          (pure (Component.component \_ -> pure (JSX.text "lazy")))

      _lazyNode =
        Component.element lazyWidget {}

    dispose
