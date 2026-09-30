-- | Signals: the writable sources of the reactive graph. `map` / `do` on an
-- | `Accessor` build derived accessors that recompute when read (cache them
-- | with `Solid.Reactivity.createMemo`). Writes are batched until the next flush.
module Solid.Signal
  ( Accessor
  , Setter
  , Signal
  , module Exports
  , SignalOptions
  , defaultSignalOptions
  , createSignal
  , createSignalWith
  , get
  , sample
  , untrack
  , set
  , modify
  , modify_
  ) where

import Prelude

import Data.HeytingAlgebra (ff, implies, tt)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn4, runEffectFn2, runEffectFn4)
import Solid.Internal.Equality (Equality(..), EqualityFn, toEqualityFn)
import Solid.Internal.Equality (Equality(..), eqEquality) as Exports
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive)

foreign import data Accessor :: Type -> Type

type role Accessor representational

foreign import data Setter :: Type -> Type

type Signal a = Accessor a /\ Setter a

foreign import mapImpl :: forall a b. (a -> b) -> Accessor a -> Accessor b
foreign import applyImpl :: forall a b. Accessor (a -> b) -> Accessor a -> Accessor b
foreign import pureImpl :: forall a. a -> Accessor a
foreign import bindImpl :: forall a b. Accessor a -> (a -> Accessor b) -> Accessor b

instance Functor Accessor where
  map = mapImpl

instance Apply Accessor where
  apply = applyImpl

instance Applicative Accessor where
  pure = pureImpl

instance Bind Accessor where
  bind = bindImpl

instance Monad Accessor

instance Semigroup a => Semigroup (Accessor a) where
  append a b = append <$> a <*> b

instance Monoid a => Monoid (Accessor a) where
  mempty = pure mempty

instance HeytingAlgebra a => HeytingAlgebra (Accessor a) where
  ff = pure ff
  tt = pure tt
  implies a b = implies <$> a <*> b
  conj a b = conj <$> a <*> b
  disj a b = disj <$> a <*> b
  not = map not

instance BooleanAlgebra a => BooleanAlgebra (Accessor a)

type SignalOptions a =
  { name :: String
  , equality :: Equality a
  }

defaultSignalOptions :: forall a. SignalOptions a
defaultSignalOptions =
  { name: ""
  , equality: DefaultEquals
  }

-- | Works in `Effect` or `Setup`; signals need no disposal.
createSignal :: forall m a. MonadReactive m => a -> m (Signal a)
createSignal = createSignalWith defaultSignalOptions

createSignalWith :: forall m a. MonadReactive m => SignalOptions a -> a -> m (Signal a)
createSignalWith options initial = liftReactive do
  parts <- runEffectFn4 createSignalImpl options.name mode equals initial
  pure (parts.get /\ parts.set)
  where
  { mode, equals } = toEqualityFn options.equality

foreign import createSignalImpl
  :: forall a
   . EffectFn4 String String (EqualityFn a) a { get :: Accessor a, set :: Setter a }

-- | Reads the current value without subscribing. Throws `NotReadyError` for an
-- | async value that hasn't loaded yet; use `Solid.Async.resolve` to wait.
foreign import get :: forall a. Accessor a -> Effect a

-- | Reads the current value during setup without tracking. For initial values;
-- | pass the `Accessor` on for anything that should stay reactive.
sample :: forall a. Accessor a -> Setup a
sample accessor = Setup (untrackImpl accessor)

foreign import untrackImpl :: forall a. Accessor a -> Effect a

-- | An accessor that reads `accessor` without subscribing the computation
-- | reading it.
foreign import untrack :: forall a. Accessor a -> Accessor a

-- | Writes a value. Visible to reads after the next flush.
set :: forall a. Setter a -> a -> Effect Unit
set setter value = runEffectFn2 setImpl setter value

foreign import setImpl :: forall a. EffectFn2 (Setter a) a Unit

-- | Updates the value from its latest (possibly not yet flushed) value and
-- | returns the value written.
modify :: forall a. Setter a -> (a -> a) -> Effect a
modify setter update = runEffectFn2 modifyImpl setter update

modify_ :: forall a. Setter a -> (a -> a) -> Effect Unit
modify_ setter update = void (modify setter update)

foreign import modifyImpl :: forall a. EffectFn2 (Setter a) (a -> a) a
