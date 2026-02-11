module Solid.Utility
  ( Owner
  , Observable
  , OnOptions
  , defaultOnOptions
  , SplitResult
  , batch
  , catchError
  , from
  , fromWithInitial
  , indexArray
  , mapArray
  , mergeProps2
  , mergeProps3
  , mergePropsMany
  , observable
  , splitProps
  , startTransition
  , useTransition
  , untrack
  , getOwner
  , runWithOwner
  , on
  , onWith
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Solid.Signal (Accessor)

foreign import data Owner :: Type

foreign import data Observable :: Type -> Type

type SplitResult picked omitted =
  { picked :: picked
  , omitted :: omitted
  }

type OnOptions =
  { defer :: Boolean
  }

defaultOnOptions :: OnOptions
defaultOnOptions =
  { defer: false
  }

foreign import batch :: forall a. Effect a -> Effect a

foreign import catchError :: forall a. Effect a -> (String -> Effect Unit) -> Effect (Maybe a)

foreign import from
  :: forall a
   . ((a -> Effect Unit) -> Effect (Effect Unit))
  -> Effect (Accessor (Maybe a))

foreign import fromWithInitial
  :: forall a
   . a
  -> ((a -> Effect Unit) -> Effect (Effect Unit))
  -> Effect (Accessor a)

foreign import indexArray
  :: forall a b
   . Accessor (Array a)
  -> (Accessor a -> Int -> Effect b)
  -> Effect (Accessor (Array b))

foreign import mapArray
  :: forall a b
   . Accessor (Array a)
  -> (a -> Accessor Int -> Effect b)
  -> Effect (Accessor (Array b))

foreign import mergeProps2 :: forall a b c. a -> b -> c

foreign import mergeProps3 :: forall a b c d. a -> b -> c -> d

foreign import mergePropsMany :: forall a. Array a -> a

foreign import observable :: forall a. Accessor a -> Effect (Observable a)

foreign import splitProps
  :: forall props picked omitted
   . props
  -> Array String
  -> SplitResult picked omitted

foreign import startTransition :: Effect Unit -> Effect Unit

type TransitionParts =
  { pending :: Accessor Boolean
  , start :: Effect Unit -> Effect Unit
  }

useTransition :: Effect (Accessor Boolean /\ (Effect Unit -> Effect Unit))
useTransition = toPair <$> useTransitionImpl
  where
  toPair :: TransitionParts -> Accessor Boolean /\ (Effect Unit -> Effect Unit)
  toPair parts = parts.pending /\ parts.start

foreign import useTransitionImpl :: Effect TransitionParts

foreign import untrack :: forall a. Effect a -> Effect a

foreign import getOwner :: Effect (Maybe Owner)

foreign import runWithOwner :: forall a. Owner -> Effect a -> Effect a

on :: forall a b. Accessor a -> (a -> Maybe a -> Effect b) -> Effect b
on = onWith defaultOnOptions

onWith :: forall a b. OnOptions -> Accessor a -> (a -> Maybe a -> Effect b) -> Effect b
onWith options accessor run = onImpl accessor options.defer run

foreign import onImpl
  :: forall a b
   . Accessor a
  -> Boolean
  -> (a -> Maybe a -> Effect b)
  -> Effect b
