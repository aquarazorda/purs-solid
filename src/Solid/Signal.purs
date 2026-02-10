module Solid.Signal
  ( Accessor
  , Setter
  , Signal
  , Equality(..)
  , SignalOptions
  , defaultSignalOptions
  , createSignal
  , createSignalWith
  , get
  , set
  , modify
  ) where

import Prelude

import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)

foreign import data Accessor :: Type -> Type
foreign import data Setter :: Type -> Type

type Signal a = Accessor a /\ Setter a

data Equality a
  = DefaultEquals
  | AlwaysNotify
  | CustomEquals (a -> a -> Boolean)

type SignalOptions a =
  { name :: String
  , internal :: Boolean
  , equality :: Equality a
  }

defaultSignalOptions :: forall a. SignalOptions a
defaultSignalOptions =
  { name: ""
  , internal: false
  , equality: DefaultEquals
  }

type SignalParts a =
  { get :: Accessor a
  , set :: Setter a
  }

createSignal :: forall a. a -> Effect (Signal a)
createSignal = createSignalWith defaultSignalOptions

createSignalWith :: forall a. SignalOptions a -> a -> Effect (Signal a)
createSignalWith options initial =
  case options.equality of
    DefaultEquals ->
      toSignal <$> createSignalWithDefaultEqImpl options.name options.internal initial
    AlwaysNotify ->
      toSignal <$> createSignalWithAlwaysImpl options.name options.internal initial
    CustomEquals equals ->
      toSignal <$> createSignalWithCustomEqImpl options.name options.internal equals initial
  where
  toSignal :: SignalParts a -> Signal a
  toSignal parts = parts.get /\ parts.set

foreign import createSignalWithDefaultEqImpl
  :: forall a
   . String
  -> Boolean
  -> a
  -> Effect (SignalParts a)

foreign import createSignalWithAlwaysImpl
  :: forall a
   . String
  -> Boolean
  -> a
  -> Effect (SignalParts a)

foreign import createSignalWithCustomEqImpl
  :: forall a
   . String
  -> Boolean
  -> (a -> a -> Boolean)
  -> a
  -> Effect (SignalParts a)

foreign import get :: forall a. Accessor a -> Effect a

foreign import set :: forall a. Setter a -> a -> Effect a

foreign import modify :: forall a. Setter a -> (a -> a) -> Effect a
