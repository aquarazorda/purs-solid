module Solid.Web
  ( Mountable
  , WebError(..)
  , isServer
  , render
  , hydrate
  , documentBody
  , mountById
  , requireBody
  , requireMountById
  ) where

import Prelude

import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Solid.Internal.Error (tryMessage)

foreign import data Mountable :: Type

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

render :: forall a. Effect a -> Mountable -> Effect (Either WebError (Effect Unit))
render view mount
  | isServer =
      pure (Left (ClientOnlyApi clientOnlyMessage))
  | otherwise =
      lmap RuntimeError <$> tryMessage (runEffectFn2 renderImpl view mount)

hydrate :: forall a. Effect a -> Mountable -> Effect (Either WebError (Effect Unit))
hydrate view mount
  | isServer =
      pure (Left (ClientOnlyApi clientOnlyMessage))
  | otherwise =
      lmap RuntimeError <$> tryMessage (runEffectFn2 hydrateImpl view mount)

foreign import renderImpl :: forall a. EffectFn2 (Effect a) Mountable (Effect Unit)

foreign import hydrateImpl :: forall a. EffectFn2 (Effect a) Mountable (Effect Unit)

documentBody :: Effect (Maybe Mountable)
documentBody = toMaybe <$> documentBodyImpl

foreign import documentBodyImpl :: Effect (Nullable Mountable)

mountById :: String -> Effect (Maybe Mountable)
mountById id = toMaybe <$> runEffectFn1 mountByIdImpl id

foreign import mountByIdImpl :: EffectFn1 String (Nullable Mountable)

requireBody :: Effect (Either WebError Mountable)
requireBody = do
  maybeBody <- documentBody
  pure case maybeBody of
    Just body -> Right body
    Nothing -> Left (MissingMount "document.body is unavailable in current runtime")

requireMountById :: String -> Effect (Either WebError Mountable)
requireMountById id = do
  maybeMount <- mountById id
  pure case maybeMount of
    Just mount -> Right mount
    Nothing -> Left (MissingMount ("No mount element found for id: " <> id))

clientOnlyMessage :: String
clientOnlyMessage =
  "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
