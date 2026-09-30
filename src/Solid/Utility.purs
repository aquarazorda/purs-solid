-- | Reactive list mapping. Results are reused as the list changes; each item
-- | gets its own owner, disposed when the item leaves the list.
module Solid.Utility
  ( mapArray
  , mapArrayByReference
  , mapArrayUnkeyed
  , mapArrayBy
  , repeat
  , repeatFrom
  , module Exports
  ) where

import Prelude

import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, mkEffectFn1, mkEffectFn2, runEffectFn3)
import Solid.Internal.Identity (class StableIdentity)
import Solid.Internal.Identity (class StableIdentity) as Exports
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Internal.View (Keyed, keyedBy, keyedByIdentity, keyedByPosition)
import Solid.Internal.Tracked (class Tracked, Accessor, fromAccessor, toAccessor)

-- | Keyed by the items themselves: an item keeps its result while it stays in
-- | the list, and only its index changes. For primitives and store cursors.
mapArray
  :: forall f a b
   . Tracked f
  => StableIdentity a
  => f (Array a)
  -> (a -> Accessor Int -> Setup b)
  -> Setup (f (Array b))
mapArray = mapArrayByReference

-- | `mapArray` for any values, keyed by reference (`===`). Results survive
-- | only while the list keeps the same values.
mapArrayByReference
  :: forall f a b
   . Tracked f
  => f (Array a)
  -> (a -> Accessor Int -> Setup b)
  -> Setup (f (Array b))
mapArrayByReference = mapArrayWith keyedByIdentity

-- | Keyed by position: the result at index `i` stays, and its item accessor
-- | updates when a different value lands there.
mapArrayUnkeyed
  :: forall f a b
   . Tracked f
  => f (Array a)
  -> (Accessor a -> Int -> Setup b)
  -> Setup (f (Array b))
mapArrayUnkeyed = mapArrayWith keyedByPosition

-- | Keyed by a derived key: items with the same key share a result, whose item
-- | accessor updates to the newest value.
mapArrayBy
  :: forall f a b k
   . Tracked f
  => (a -> k)
  -> f (Array a)
  -> (Accessor a -> Accessor Int -> Setup b)
  -> Setup (f (Array b))
mapArrayBy key = mapArrayWith (keyedBy key)

mapArrayWith
  :: forall f a b item index
   . Tracked f
  => Keyed a item index
  -> f (Array a)
  -> (item -> index -> Setup b)
  -> Setup (f (Array b))
mapArrayWith keyed list mapItem =
  Setup (fromAccessor <$> runEffectFn3 mapArrayImpl keyed (toAccessor list) (mkEffectFn2 \item index -> runSetup (mapItem item index)))

foreign import mapArrayImpl
  :: forall a b item index
   . EffectFn3 (Keyed a item index) (Accessor (Array a)) (EffectFn2 item index b) (Accessor (Array b))

-- | Maps the indices `0 .. count - 1`; results are reused as `count` changes.
repeat :: forall f b. Tracked f => f Int -> (Int -> Setup b) -> Setup (f (Array b))
repeat count mapIndex =
  Setup (fromAccessor <$> runEffectFn3 repeatImpl (toAccessor count) (mkEffectFn1 (runSetup <<< mapIndex)) {})

-- | Maps the indices `from .. from + count - 1`, e.g. a virtualized window;
-- | results are reused as the window moves.
repeatFrom :: forall f b. Tracked f => f Int -> f Int -> (Int -> Setup b) -> Setup (f (Array b))
repeatFrom from count mapIndex =
  Setup (fromAccessor <$> runEffectFn3 repeatImpl (toAccessor count) (mkEffectFn1 (runSetup <<< mapIndex)) { from: toAccessor from })

foreign import repeatImpl :: forall b options. EffectFn3 (Accessor Int) (EffectFn1 Int b) { | options } (Accessor (Array b))
