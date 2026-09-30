-- | Reactive list mapping. Results are reused as the list changes; each item
-- | gets its own owner, disposed when the item leaves the list.
module Solid.Utility
  ( mapArray
  , mapArrayUnkeyed
  , mapArrayBy
  , repeat
  ) where

import Prelude

import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, mkEffectFn1, mkEffectFn2, runEffectFn2, runEffectFn3)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Signal (Accessor)

-- | Keyed by identity (`===`): an item keeps its result while it stays in the
-- | list, and only its index changes.
mapArray
  :: forall a b
   . Accessor (Array a)
  -> (a -> Accessor Int -> Setup b)
  -> Setup (Accessor (Array b))
mapArray list mapItem =
  Setup (runEffectFn2 mapArrayImpl list (mkEffectFn2 \item index -> runSetup (mapItem item index)))

foreign import mapArrayImpl
  :: forall a b
   . EffectFn2 (Accessor (Array a)) (EffectFn2 a (Accessor Int) b) (Accessor (Array b))

-- | Keyed by position: the result at index `i` stays, and its item accessor
-- | updates when a different value lands there.
mapArrayUnkeyed
  :: forall a b
   . Accessor (Array a)
  -> (Accessor a -> Int -> Setup b)
  -> Setup (Accessor (Array b))
mapArrayUnkeyed list mapItem =
  Setup (runEffectFn2 mapArrayUnkeyedImpl list (mkEffectFn2 \item index -> runSetup (mapItem item index)))

foreign import mapArrayUnkeyedImpl
  :: forall a b
   . EffectFn2 (Accessor (Array a)) (EffectFn2 (Accessor a) Int b) (Accessor (Array b))

-- | Keyed by a derived key: items with the same key share a result, whose item
-- | accessor updates to the newest value.
mapArrayBy
  :: forall a b k
   . (a -> k)
  -> Accessor (Array a)
  -> (Accessor a -> Accessor Int -> Setup b)
  -> Setup (Accessor (Array b))
mapArrayBy key list mapItem =
  Setup (runEffectFn3 mapArrayByImpl key list (mkEffectFn2 \item index -> runSetup (mapItem item index)))

foreign import mapArrayByImpl
  :: forall a b k
   . EffectFn3 (a -> k) (Accessor (Array a)) (EffectFn2 (Accessor a) (Accessor Int) b) (Accessor (Array b))

-- | Maps the indices `0 .. count - 1`; results are reused as `count` changes.
repeat :: forall b. Accessor Int -> (Int -> Setup b) -> Setup (Accessor (Array b))
repeat count mapIndex =
  Setup (runEffectFn2 repeatImpl count (mkEffectFn1 (runSetup <<< mapIndex)))

foreign import repeatImpl :: forall b. EffectFn2 (Accessor Int) (EffectFn1 Int b) (Accessor (Array b))
