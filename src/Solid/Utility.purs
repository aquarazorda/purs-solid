module Solid.Utility
  ( Owner
  , OnOptions
  , defaultOnOptions
  , batch
  , untrack
  , getOwner
  , runWithOwner
  , on
  , onWith
  ) where

import Data.Maybe (Maybe)
import Effect (Effect)
import Solid.Signal (Accessor)

foreign import data Owner :: Type

type OnOptions =
  { defer :: Boolean
  }

defaultOnOptions :: OnOptions
defaultOnOptions =
  { defer: false
  }

foreign import batch :: forall a. Effect a -> Effect a

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
