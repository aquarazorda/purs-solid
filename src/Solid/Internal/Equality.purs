module Solid.Internal.Equality
  ( Equality(..)
  , eqEquality
  , EqualityFn
  , toEqualityFn
  ) where

import Prelude

import Data.Function.Uncurried (Fn2, mkFn2)

-- | When a new value counts as a change.
data Equality a
  -- | Reference equality (`===`), Solid's default. Cheap, but a freshly built
  -- | record or array always counts as a change.
  = DefaultEquals
  -- | Every write notifies, even with the same value.
  | AlwaysNotify
  -- | `true` means "equal, don't notify".
  | CustomEquals (a -> a -> Boolean)

-- | Structural equality via `Eq`: rebuilding an equal value doesn't notify.
eqEquality :: forall a. Eq a => Equality a
eqEquality = CustomEquals eq

type EqualityFn a = Fn2 a a Boolean

-- | Encodes an `Equality` for the FFI: a mode tag plus the comparison
-- | (ignored unless the mode is `"custom"`).
toEqualityFn :: forall a. Equality a -> { mode :: String, equals :: EqualityFn a }
toEqualityFn = case _ of
  DefaultEquals -> { mode: "default", equals: mkFn2 \_ _ -> false }
  AlwaysNotify -> { mode: "never", equals: mkFn2 \_ _ -> false }
  CustomEquals equals -> { mode: "custom", equals: mkFn2 equals }
