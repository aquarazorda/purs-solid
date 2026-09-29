-- | Mounting views in the browser.
module Solid.Web
  ( WebError(..)
  , isServer
  , render
  , hydrate
  , documentBody
  , elementById
  , requireBody
  , requireElementById
  ) where

import Prelude

import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Solid.Internal.Error (tryMessage)
import Solid.Internal.View (JSX, Realized, realize)
import Web.DOM.Element (Element)

data WebError
  = ClientOnlyApi String
  | RuntimeError String
  | MissingMount String

derive instance eqWebError :: Eq WebError

instance showWebError :: Show WebError where
  show = case _ of
    ClientOnlyApi message -> "ClientOnlyApi " <> show message
    RuntimeError message -> "RuntimeError " <> show message
    MissingMount message -> "MissingMount " <> show message

foreign import isServer :: Boolean

-- | Renders `view` into `mount`, replacing its content. The result disposes
-- | the view (removes its DOM and its computations).
render :: JSX -> Element -> Effect (Either WebError (Effect Unit))
render view mount
  | isServer = pure (Left (ClientOnlyApi clientOnlyMessage))
  | otherwise = lmap RuntimeError <$> tryMessage (runEffectFn3 renderImpl realize view mount)

-- | Attaches `view` to server-rendered markup in `mount` instead of creating
-- | new DOM.
hydrate :: JSX -> Element -> Effect (Either WebError (Effect Unit))
hydrate view mount
  | isServer = pure (Left (ClientOnlyApi clientOnlyMessage))
  | otherwise = lmap RuntimeError <$> tryMessage (runEffectFn3 hydrateImpl realize view mount)

foreign import renderImpl :: EffectFn3 (JSX -> Realized) JSX Element (Effect Unit)

foreign import hydrateImpl :: EffectFn3 (JSX -> Realized) JSX Element (Effect Unit)

documentBody :: Effect (Maybe Element)
documentBody = toMaybe <$> documentBodyImpl

foreign import documentBodyImpl :: Effect (Nullable Element)

elementById :: String -> Effect (Maybe Element)
elementById id = toMaybe <$> runEffectFn1 elementByIdImpl id

foreign import elementByIdImpl :: EffectFn1 String (Nullable Element)

requireBody :: Effect (Either WebError Element)
requireBody = do
  maybeBody <- documentBody
  pure case maybeBody of
    Just body -> Right body
    Nothing -> Left (MissingMount "document.body is unavailable in current runtime")

requireElementById :: String -> Effect (Either WebError Element)
requireElementById id = do
  maybeMount <- elementById id
  pure case maybeMount of
    Just mount -> Right mount
    Nothing -> Left (MissingMount ("No element found for id: " <> id))

clientOnlyMessage :: String
clientOnlyMessage =
  "Client-only API called on the server. Render on the server with Solid.Web.SSR, or run this code from onSettled."
