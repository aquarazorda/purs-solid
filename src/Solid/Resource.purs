module Solid.Resource
  ( Resource
  , ResourceActions
  , ResourceState(..)
  , ResourceStateError(..)
  , ResourceReadError(..)
  , ResourceFetchInfo
  , createResource
  , createResourceFrom
  , value
  , latest
  , state
  , loading
  , error
  , mutate
  , refetch
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Solid.Signal (Accessor)

foreign import data Resource :: Type -> Type
foreign import data ResourceActions :: Type -> Type -> Type

type ResourceFetchInfo a r =
  { value :: Maybe a
  , refetching :: Maybe r
  , isRefetching :: Boolean
  }

data ResourceState
  = Unresolved
  | Pending
  | Ready
  | Refreshing
  | Errored

data ResourceStateError
  = UnknownResourceState String

data ResourceReadError
  = ResourceReadError String

derive instance eqResourceState :: Eq ResourceState
derive instance eqResourceStateError :: Eq ResourceStateError
derive instance eqResourceReadError :: Eq ResourceReadError

instance showResourceState :: Show ResourceState where
  show = case _ of
    Unresolved -> "Unresolved"
    Pending -> "Pending"
    Ready -> "Ready"
    Refreshing -> "Refreshing"
    Errored -> "Errored"

instance showResourceStateError :: Show ResourceStateError where
  show = case _ of
    UnknownResourceState tag -> "UnknownResourceState " <> show tag

instance showResourceReadError :: Show ResourceReadError where
  show = case _ of
    ResourceReadError message -> "ResourceReadError " <> show message

type ResourceParts a r =
  { resource :: Resource a
  , actions :: ResourceActions a r
  }

createResource
  :: forall a r
   . (ResourceFetchInfo a r -> Effect (Either String a))
  -> Effect (Resource a /\ ResourceActions a r)
createResource fetcher =
  toPair <$> createResourceImpl fetcher
  where
  toPair :: ResourceParts a r -> Resource a /\ ResourceActions a r
  toPair parts = parts.resource /\ parts.actions

createResourceFrom
  :: forall s a r
   . Accessor (Maybe s)
  -> (s -> ResourceFetchInfo a r -> Effect (Either String a))
  -> Effect (Resource a /\ ResourceActions a r)
createResourceFrom source fetcher =
  toPair <$> createResourceFromImpl source fetcher
  where
  toPair :: ResourceParts a r -> Resource a /\ ResourceActions a r
  toPair parts = parts.resource /\ parts.actions

foreign import createResourceImpl
  :: forall a r
   . (ResourceFetchInfo a r -> Effect (Either String a))
  -> Effect (ResourceParts a r)

foreign import createResourceFromImpl
  :: forall s a r
   . Accessor (Maybe s)
  -> (s -> ResourceFetchInfo a r -> Effect (Either String a))
  -> Effect (ResourceParts a r)

value :: forall a. Resource a -> Effect (Either ResourceReadError (Maybe a))
value resource = do
  result <- valueImpl resource
  pure case result of
    Left message -> Left (ResourceReadError message)
    Right current -> Right current

latest :: forall a. Resource a -> Effect (Either ResourceReadError (Maybe a))
latest resource = do
  result <- latestImpl resource
  pure case result of
    Left message -> Left (ResourceReadError message)
    Right current -> Right current

foreign import valueImpl :: forall a. Resource a -> Effect (Either String (Maybe a))

foreign import latestImpl :: forall a. Resource a -> Effect (Either String (Maybe a))

state :: forall a. Resource a -> Effect (Either ResourceStateError ResourceState)
state resource = do
  tag <- stateTagImpl resource
  pure case tag of
    "unresolved" -> Right Unresolved
    "pending" -> Right Pending
    "ready" -> Right Ready
    "refreshing" -> Right Refreshing
    "errored" -> Right Errored
    _ -> Left (UnknownResourceState tag)

foreign import stateTagImpl :: forall a. Resource a -> Effect String

foreign import loading :: forall a. Resource a -> Effect Boolean

foreign import error :: forall a. Resource a -> Effect (Maybe String)

foreign import mutate :: forall a r. ResourceActions a r -> Maybe a -> Effect Unit

foreign import refetch :: forall a r. ResourceActions a r -> Maybe r -> Effect Unit
