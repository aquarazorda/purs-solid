module Test.Control
  ( run
  ) where

import Prelude

import Effect (Effect)
import Solid.Component as Component
import Solid.Control as Control
import Solid.JSX as JSX
import Solid.Signal (Accessor, get)

run :: Effect Unit
run = do
  let _ = _examples
  pure unit

_examples
  :: Accessor Boolean
  -> Accessor (Array String)
  -> Component.Component {}
  -> Array JSX.JSX
_examples visible items widget =
  [ Control.when visible (JSX.text "shown")
  , Control.whenElse visible JSX.empty (JSX.text "shown")
  , Control.forEach items \item -> pure (JSX.text item)
  , Control.forEachWithIndex items \item indexAccessor -> do
      index <- get indexAccessor
      pure (JSX.text (show index <> ":" <> item))
  , Control.indexEach items \itemAccessor -> do
      item <- get itemAccessor
      pure (JSX.text item)
  , Control.matchWhen visible (JSX.text "matched")
  , Control.switchCases [ Control.matchWhenKeyed visible (JSX.text "matched") ]
  , Control.dynamicTag "section" { children: [ JSX.text "dynamic" ] }
  , Control.dynamicComponent widget {}
  , Control.portal (JSX.text "portal")
  ]
