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

import Data.Bifunctor (bimap)
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe, toNullable)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Exception (throwException)
import Effect.Exception as Exception
import Solid.Internal.Error (tryMessage)
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
  toPair <$> createResourceImpl Just Nothing (orThrow <<< fetcher)

createResourceFrom
  :: forall s a r
   . Accessor (Maybe s)
  -> (s -> ResourceFetchInfo a r -> Effect (Either String a))
  -> Effect (Resource a /\ ResourceActions a r)
createResourceFrom source fetcher =
  toPair <$> createResourceFromImpl Just Nothing (sourceBoxImpl (\m -> toNullable ({ value: _ } <$> m)) source) (\s -> orThrow <<< fetcher s)

toPair :: forall a r. ResourceParts a r -> Resource a /\ ResourceActions a r
toPair parts = parts.resource /\ parts.actions

-- | Solid signals fetch failures by throwing; `Left` becomes a thrown `Error`.
orThrow :: forall a. Effect (Either String a) -> Effect a
orThrow = (_ >>= either (throwException <<< Exception.error) pure)

foreign import createResourceImpl
  :: forall a r
   . (forall x. x -> Maybe x)
  -> (forall x. Maybe x)
  -> (ResourceFetchInfo a r -> Effect a)
  -> Effect (ResourceParts a r)

foreign import data SourceBox :: Type -> Type

-- | Wraps a `Maybe` source as Solid expects: `{ value }` when present, `undefined` otherwise.
foreign import sourceBoxImpl
  :: forall s
   . (Maybe s -> Nullable { value :: s })
  -> Accessor (Maybe s)
  -> SourceBox s

foreign import createResourceFromImpl
  :: forall s a r
   . (forall x. x -> Maybe x)
  -> (forall x. Maybe x)
  -> SourceBox s
  -> (s -> ResourceFetchInfo a r -> Effect a)
  -> Effect (ResourceParts a r)

value :: forall a. Resource a -> Effect (Either ResourceReadError (Maybe a))
value resource =
  bimap ResourceReadError toMaybe <$> tryMessage (readValueImpl resource)

latest :: forall a. Resource a -> Effect (Either ResourceReadError (Maybe a))
latest resource =
  bimap ResourceReadError toMaybe <$> tryMessage (readLatestImpl resource)

foreign import readValueImpl :: forall a. Resource a -> Effect (Nullable a)

foreign import readLatestImpl :: forall a. Resource a -> Effect (Nullable a)

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

foreign import errorImpl :: forall a. Resource a -> Effect (Nullable String)

error :: forall a. Resource a -> Effect (Maybe String)
error resource = toMaybe <$> errorImpl resource

foreign import mutateImpl :: forall a r. ResourceActions a r -> Nullable a -> Effect Unit

mutate :: forall a r. ResourceActions a r -> Maybe a -> Effect Unit
mutate actions next = mutateImpl actions (toNullable next)

foreign import refetchImpl :: forall a r. ResourceActions a r -> Effect Unit

foreign import refetchWithImpl :: forall a r. ResourceActions a r -> r -> Effect Unit

refetch :: forall a r. ResourceActions a r -> Maybe r -> Effect Unit
refetch actions = case _ of
  Just info -> refetchWithImpl actions info
  Nothing -> refetchImpl actions
