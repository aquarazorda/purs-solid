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

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Prelude

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
render view mount = do
  result <- renderImpl view mount
  pure case result of
    Left message ->
      if message == clientOnlyMessage then
        Left (ClientOnlyApi message)
      else
        Left (RuntimeError message)
    Right disposer ->
      Right disposer

hydrate :: forall a. Effect a -> Mountable -> Effect (Either WebError (Effect Unit))
hydrate view mount = do
  result <- hydrateImpl view mount
  pure case result of
    Left message ->
      if message == clientOnlyMessage then
        Left (ClientOnlyApi message)
      else
        Left (RuntimeError message)
    Right disposer ->
      Right disposer

foreign import renderImpl :: forall a. Effect a -> Mountable -> Effect (Either String (Effect Unit))

foreign import hydrateImpl :: forall a. Effect a -> Mountable -> Effect (Either String (Effect Unit))

foreign import documentBody :: Effect (Maybe Mountable)

foreign import mountById :: String -> Effect (Maybe Mountable)

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
