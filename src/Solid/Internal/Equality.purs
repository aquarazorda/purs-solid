module Solid.Internal.Equality
  ( Equality
  , alwaysNotify
  , customEquals
  , eqEquality
  ) where

import Prelude

import Data.Function.Uncurried (mkFn2)
import Unsafe.Coerce (unsafeCoerce)

-- | When a new value counts as a change: Solid's `equals` option. Leaving it
-- | out means reference equality (`===`), so a freshly built record or array
-- | always counts as a change.
foreign import data Equality :: Type -> Type

-- | Every write notifies, even of the same value.
alwaysNotify :: forall a. Equality a
alwaysNotify = unsafeCoerce false

-- | `true` means "equal, don't notify".
customEquals :: forall a. (a -> a -> Boolean) -> Equality a
customEquals equals = unsafeCoerce (mkFn2 equals)

-- | Structural equality via `Eq`: rebuilding an equal value doesn't notify.
eqEquality :: forall a. Eq a => Equality a
eqEquality = customEquals eq
