-- | Internal: not part of the public API.
module Solid.Internal.Tracked
  ( Accessor
  , Async
  , class Tracked
  , toAccessor
  , fromAccessor
  ) where

import Prelude

import Data.HeytingAlgebra (ff, implies, tt)
import Unsafe.Coerce (unsafeCoerce)

-- | A reactive value: read inside a tracked computation, it subscribes it.
foreign import data Accessor :: Type -> Type

type role Accessor representational

-- | A reactive value that may not have loaded yet. It can't be read directly
-- | (`get`, `sample`): render it, derive from it, or wait for it with
-- | `Solid.Async.resolve`.
foreign import data Async :: Type -> Type

type role Async representational

-- | `Accessor` and `Async`: what tracked computations, bindings and control
-- | flow read.
class Tracked :: (Type -> Type) -> Constraint
class Monad f <= Tracked f where
  toAccessor :: forall a. f a -> Accessor a
  fromAccessor :: forall a. Accessor a -> f a

instance Tracked Accessor where
  toAccessor = identity
  fromAccessor = identity

instance Tracked Async where
  toAccessor = unsafeCoerce
  fromAccessor = unsafeCoerce

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

instance Functor Async where
  map f = fromAccessor <<< map f <<< toAccessor

instance Apply Async where
  apply f a = fromAccessor (toAccessor f <*> toAccessor a)

instance Applicative Async where
  pure = fromAccessor <<< pure

instance Bind Async where
  bind a f = fromAccessor (toAccessor a >>= toAccessor <<< f)

instance Monad Async

instance Semigroup a => Semigroup (Async a) where
  append a b = append <$> a <*> b

instance Monoid a => Monoid (Async a) where
  mempty = pure mempty

instance HeytingAlgebra a => HeytingAlgebra (Async a) where
  ff = pure ff
  tt = pure tt
  implies a b = implies <$> a <*> b
  conj a b = conj <$> a <*> b
  disj a b = disj <$> a <*> b
  not = map not

instance BooleanAlgebra a => BooleanAlgebra (Async a)
