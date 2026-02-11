module Test.Control
  ( run
  ) where

import Prelude

import Data.Maybe (Maybe(..))
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
  -> Accessor (Maybe String)
  -> Accessor (Array String)
  -> Component.Component {}
  -> Array JSX.JSX
_examples visible maybeItem items widget =
  [ Control.when visible (JSX.text "shown")
  , Control.whenKeyed visible (JSX.text "shown")
  , Control.whenElse visible JSX.empty (JSX.text "shown")
  , Control.whenElseKeyed visible JSX.empty (JSX.text "shown")
  , Control.showMaybe maybeItem \itemAccessor -> do
      item <- get itemAccessor
      pure (JSX.text item)
  , Control.showMaybeElse maybeItem (JSX.text "missing") \itemAccessor -> do
      item <- get itemAccessor
      pure (JSX.text item)
  , Control.showMaybeKeyed maybeItem \item ->
      pure (JSX.text item)
  , Control.showMaybeKeyedElse maybeItem (JSX.text "missing") \item ->
      pure (JSX.text item)
  , Control.forEach items \item -> pure (JSX.text item)
  , Control.forEachWithIndex items \item indexAccessor -> do
      index <- get indexAccessor
      pure (JSX.text (show index <> ":" <> item))
  , Control.indexEach items \itemAccessor -> do
      item <- get itemAccessor
      pure (JSX.text item)
  , Control.matchWhen visible (JSX.text "matched")
  , Control.matchMaybe maybeItem \item ->
      pure (JSX.text item)
  , Control.switchCases [ Control.matchWhenKeyed visible (JSX.text "matched") ]
  , Control.dynamicTag "section" { children: [ JSX.text "dynamic" ] }
  , Control.dynamicComponent widget {}
  , Control.errorBoundary (JSX.text "fallback") (JSX.text "content")
  , Control.errorBoundaryWith (\message reset -> do
      _ <- reset
      pure (JSX.text message)
    ) (JSX.text "content")
  , Control.noHydration (JSX.text "static")
  , Control.suspense (JSX.text "loading") (JSX.text "content")
  , Control.suspenseList Control.Forwards
      [ Control.suspense (JSX.text "loading-a") (JSX.text "a")
      , Control.suspense (JSX.text "loading-b") (JSX.text "b")
      ]
  , Control.suspenseListWith
      ( Control.defaultSuspenseListOptions
          { revealOrder = Control.Backwards
          , tail = Just Control.Collapsed
          }
      )
      [ Control.suspense (JSX.text "loading-c") (JSX.text "c") ]
  , Control.portal (JSX.text "portal")
  , Control.portalWith
      ( Control.defaultPortalOptions
          { useShadow = true
          }
      )
      (JSX.text "portal")
  ]
