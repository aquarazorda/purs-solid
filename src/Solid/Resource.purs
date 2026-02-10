module Solid.Resource
  ( Resource
  , ResourceActions
  , ResourceState(..)
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

derive instance eqResourceState :: Eq ResourceState

instance showResourceState :: Show ResourceState where
  show = case _ of
    Unresolved -> "Unresolved"
    Pending -> "Pending"
    Ready -> "Ready"
    Refreshing -> "Refreshing"
    Errored -> "Errored"

type ResourceParts a r =
  { resource :: Resource a
  , actions :: ResourceActions a r
  }

createResource
  :: forall a r
   . (ResourceFetchInfo a r -> Effect a)
  -> Effect (Resource a /\ ResourceActions a r)
createResource fetcher =
  toPair <$> createResourceImpl fetcher
  where
  toPair :: ResourceParts a r -> Resource a /\ ResourceActions a r
  toPair parts = parts.resource /\ parts.actions

createResourceFrom
  :: forall s a r
   . Accessor (Maybe s)
  -> (s -> ResourceFetchInfo a r -> Effect a)
  -> Effect (Resource a /\ ResourceActions a r)
createResourceFrom source fetcher =
  toPair <$> createResourceFromImpl source fetcher
  where
  toPair :: ResourceParts a r -> Resource a /\ ResourceActions a r
  toPair parts = parts.resource /\ parts.actions

foreign import createResourceImpl
  :: forall a r
   . (ResourceFetchInfo a r -> Effect a)
  -> Effect (ResourceParts a r)

foreign import createResourceFromImpl
  :: forall s a r
   . Accessor (Maybe s)
  -> (s -> ResourceFetchInfo a r -> Effect a)
  -> Effect (ResourceParts a r)

foreign import value :: forall a. Resource a -> Effect (Maybe a)

foreign import latest :: forall a. Resource a -> Effect (Maybe a)

state :: forall a. Resource a -> Effect ResourceState
state resource = do
  tag <- stateTagImpl resource
  pure case tag of
    "unresolved" -> Unresolved
    "pending" -> Pending
    "ready" -> Ready
    "refreshing" -> Refreshing
    "errored" -> Errored
    _ -> Errored

foreign import stateTagImpl :: forall a. Resource a -> Effect String

foreign import loading :: forall a. Resource a -> Effect Boolean

foreign import error :: forall a. Resource a -> Effect (Maybe String)

foreign import mutate :: forall a r. ResourceActions a r -> Maybe a -> Effect Unit

foreign import refetch :: forall a r. ResourceActions a r -> Maybe r -> Effect Unit
