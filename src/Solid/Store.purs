-- | Stores: nested reactive state. Records and arrays are tracked per field and
-- | element; every other type is atomic, stored as-is and replaced as a whole.
-- |
-- | ```purescript
-- | Store.update setState $ Store.at (key @"todos") (Store.push todo)
-- | ```
module Solid.Store
  ( StoreSetter
  , module Exports
  , class StoreObject
  , createStore
  , Path
  , key
  , class StoreCursor
  , focus
  , focusKey
  , atKey
  , value
  , items
  , snapshot
  , Update
  , update
  , at
  , set
  , modify
  , push
  , filter
  , atIndex
  , each
  , eachWhere
  , reconcile
  , reconcileBy
  , reconcileByPosition
  , createProjection
  , createProjectionAsync
  , createDerivedStore
  , createSelector
  , OptimisticStore
  , createOptimisticStore
  , createOptimisticProjection
  , updateOptimistic
  , affects
  ) where

import Prelude

import Data.Symbol (class IsSymbol, reflectSymbol)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Data.Either (either)
import Effect.Aff (Aff, killFiber, launchAff_, runAff)
import Effect.Exception (Error, error)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, EffectFn4, runEffectFn1, runEffectFn2, runEffectFn3, runEffectFn4)
import Solid.Async (Refresh)
import Prim.Row as Row
import Prim.TypeError (class Fail, Text)
import Solid.Internal.Optimistic (class MonadOptimistic, liftOptimistic)
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive)
import Solid.Internal.Store (class StoreValue, AsyncStore, Preparer, Store, preparer)
import Solid.Internal.Store (Store, AsyncStore, class StoreValue, class StoreFields) as Exports
import Solid.Internal.Optimistic (class MonadOptimistic) as Exports
import Solid.Internal.Tracked (class Tracked, Accessor, Async, fromAccessor, toAccessor)
import Type.Proxy (Proxy(..))

foreign import data StoreSetter :: Type -> Type

class StoreObject :: Type -> Constraint
class StoreObject a

instance StoreObject (Record r)
else instance StoreObject (Array a)
else instance Fail (Text "A store must hold a record or an array; wrap other values in a record") => StoreObject a

-- | Works in `Effect` or `Setup` (stores need no owner). The initial value is
-- | never mutated.
createStore
  :: forall m s
   . MonadReactive m
  => StoreObject s
  => StoreValue s
  => s
  -> m (Store s /\ StoreSetter s)
createStore initial = liftReactive do
  parts <- runEffectFn2 createStoreImpl (preparer :: Preparer s) initial
  pure (parts.store /\ parts.setter)

foreign import createStoreImpl
  :: forall s
   . EffectFn2 (Preparer s) s { store :: Store s, setter :: StoreSetter s }

-- | A path to a field, built from record labels with `key` and composed with `>>>`.
newtype Path :: Type -> Type -> Type
newtype Path s a = Path (Array String)

instance Semigroupoid Path where
  compose (Path inner) (Path outer) = Path (outer <> inner)

instance Category Path where
  identity = Path []

key :: forall @l r a tail. IsSymbol l => Row.Cons l a tail r => Path (Record r) a
key = Path [ reflectSymbol (Proxy :: Proxy l) ]

-- | `Store` and `AsyncStore` cursors, and what reading them gives: an
-- | `AsyncStore` may not have its first value yet, so its values are `Async`.
class StoreCursor :: (Type -> Type) -> (Type -> Type) -> Constraint
class Tracked f <= StoreCursor store f | store -> f

instance StoreCursor Store Accessor
instance StoreCursor AsyncStore Async

focus :: forall store f s a. StoreCursor store f => Path s a -> store s -> store a
focus (Path keys) store = focusImpl keys store

foreign import focusImpl :: forall store s a. Array String -> store s -> store a

-- | `focusKey @"todos" store` is `focus (key @"todos") store`.
focusKey
  :: forall @l store f r a tail. StoreCursor store f => IsSymbol l => Row.Cons l a tail r => store (Record r) -> store a
focusKey = focus (key @l)

-- | `atKey @"todos" change` is `at (key @"todos") change`.
atKey :: forall @l r a tail. IsSymbol l => Row.Cons l a tail r => Update a -> Update (Record r)
atKey = at (key @l)

-- | Tracks the whole focused part; `focus` first to track less.
value :: forall store f a. StoreCursor store f => store a -> f a
value = fromAccessor <<< valueImpl

foreign import valueImpl :: forall store a. store a -> Accessor a

-- | A cursor per element. Cursors keep their identity while an element stays in
-- | the array, so keyed list rendering reuses rows.
items :: forall store f a. StoreCursor store f => StoreObject a => store (Array a) -> f (Array (store a))
items = fromAccessor <<< itemsImpl

foreign import itemsImpl :: forall store a. store (Array a) -> Accessor (Array (store a))

-- | An untracked copy of the current value. Not for an `AsyncStore`, which may
-- | not have one yet.
foreign import snapshot :: forall a. Store a -> Effect a

-- | A pure description of changes. Combine with `<>`; they apply in order, in
-- | one batch.
foreign import data Update :: Type -> Type

foreign import appendUpdate :: forall a. Update a -> Update a -> Update a
foreign import emptyUpdate :: forall a. Update a

instance Semigroup (Update a) where
  append = appendUpdate

instance Monoid (Update a) where
  mempty = emptyUpdate

-- | Applies an update. Readers see it after the next flush.
update :: forall s. StoreSetter s -> Update s -> Effect Unit
update setter change = runEffectFn2 updateImpl setter change

foreign import updateImpl :: forall s. EffectFn2 (StoreSetter s) (Update s) Unit

at :: forall s a. Path s a -> Update a -> Update s
at (Path keys) change = atImpl keys change

foreign import atImpl :: forall s a. Array String -> Update a -> Update s

set :: forall a. StoreValue a => a -> Update a
set next = setImpl (preparer :: Preparer a) next

foreign import setImpl :: forall a. Preparer a -> a -> Update a

modify :: forall a. StoreValue a => (a -> a) -> Update a
modify f = modifyImpl (preparer :: Preparer a) f

foreign import modifyImpl :: forall a. Preparer a -> (a -> a) -> Update a

push :: forall a. StoreValue a => a -> Update (Array a)
push element = pushImpl (preparer :: Preparer a) element

foreign import pushImpl :: forall a. Preparer a -> a -> Update (Array a)

-- | Removes failing elements in place; kept elements keep their identity and
-- | readers.
foreign import filter :: forall a. (a -> Boolean) -> Update (Array a)

-- | Does nothing if the index is out of range.
foreign import atIndex :: forall a. Int -> Update a -> Update (Array a)

foreign import each :: forall a. Update a -> Update (Array a)

foreign import eachWhere :: forall a. (a -> Boolean) -> Update a -> Update (Array a)

-- | Replaces the value with `next`, keeping everything that didn't change
-- | (and its readers). Array elements are matched by their `id` field.
reconcile :: forall a. StoreValue a => a -> Update a
reconcile next = reconcileImpl (preparer :: Preparer a) next

-- | `reconcile` for an array, matching elements by a key function. Keys are
-- | compared with `===`, so use primitives.
reconcileBy :: forall a k. StoreValue a => (a -> k) -> Array a -> Update (Array a)
reconcileBy toKey next = reconcileByImpl (preparer :: Preparer (Array a)) toKey next

-- | `reconcile` for an array, matching elements by position.
reconcileByPosition :: forall a. StoreValue a => Array a -> Update (Array a)
reconcileByPosition next = reconcileByPositionImpl (preparer :: Preparer (Array a)) next

foreign import reconcileImpl :: forall a. Preparer a -> a -> Update a
foreign import reconcileByPositionImpl :: forall a. Preparer (Array a) -> Array a -> Update (Array a)
foreign import reconcileByImpl :: forall a k. Preparer (Array a) -> (a -> k) -> Array a -> Update (Array a)

-- | A read-only store derived from reactive sources: `compute` is tracked and
-- | yields the update to apply whenever its dependencies change.
createProjection
  :: forall s
   . StoreObject s
  => StoreValue s
  => Accessor (Update s)
  -> s
  -> Setup (Store s)
createProjection compute seed =
  Setup (runEffectFn3 createProjectionImpl (preparer :: Preparer s) compute seed)

foreign import createProjectionImpl
  :: forall s
   . EffectFn3 (Preparer s) (Accessor (Update s)) s (Store s)

-- | Like `createProjection`, but the update comes from async work: readers
-- | suspend (show `loading` fallbacks) until the first update, and a change of
-- | `compute`'s dependencies kills the running `Aff`. `Refresh` re-runs it.
createProjectionAsync
  :: forall s
   . StoreObject s
  => StoreValue s
  => Accessor (Aff (Update s))
  -> s
  -> Setup (AsyncStore s /\ Refresh s)
createProjectionAsync compute seed = Setup do
  parts <- runEffectFn4 createProjectionAsyncImpl startAff (preparer :: Preparer s) compute seed
  pure (parts.store /\ parts.refresh)

startAff :: forall a. Aff a -> (a -> Effect Unit) -> (Error -> Effect Unit) -> Effect (Effect Unit)
startAff aff onValue onError = do
  fiber <- runAff (either onError onValue) aff
  pure (launchAff_ (killFiber (error "purs-solid: superseded store update") fiber))

foreign import createProjectionAsyncImpl
  :: forall s
   . EffectFn4
       (forall a. Aff a -> (a -> Effect Unit) -> (Error -> Effect Unit) -> Effect (Effect Unit))
       (Preparer s)
       (Accessor (Aff (Update s)))
       s
       { store :: AsyncStore s, refresh :: Refresh s }

-- | A store derived like `createProjection` that can also be updated locally;
-- | a local update holds until `compute`'s dependencies change.
createDerivedStore
  :: forall s
   . StoreObject s
  => StoreValue s
  => Accessor (Update s)
  -> s
  -> Setup (Store s /\ StoreSetter s)
createDerivedStore compute seed = Setup do
  parts <- runEffectFn3 createDerivedStoreImpl (preparer :: Preparer s) compute seed
  pure (parts.store /\ parts.setter)

foreign import createDerivedStoreImpl
  :: forall s
   . EffectFn3 (Preparer s) (Accessor (Update s)) s { store :: Store s, setter :: StoreSetter s }

-- | `isSelected x` is true when `source` equals `x` (compared by `toKey`). A
-- | selection change notifies only the two affected readers.
createSelector :: forall f a. Tracked f => (a -> String) -> f a -> Setup (a -> Accessor Boolean)
createSelector toKey source = Setup (runEffectFn2 createSelectorImpl toKey (toAccessor source))

foreign import createSelectorImpl :: forall a. EffectFn2 (a -> String) (Accessor a) (a -> Accessor Boolean)

-- | Updated only from a `Solid.Action.Action`; its updates show immediately
-- | and revert when the action settles.
foreign import data OptimisticStore :: Type -> Type

-- | A store whose updates are tentative: made during an action, reverted
-- | when it settles.
createOptimisticStore
  :: forall m s
   . MonadReactive m
  => StoreObject s
  => StoreValue s
  => s
  -> m (Store s /\ OptimisticStore s)
createOptimisticStore initial = liftReactive do
  parts <- runEffectFn2 createOptimisticStoreImpl (preparer :: Preparer s) initial
  pure (parts.store /\ parts.setter)

foreign import createOptimisticStoreImpl
  :: forall s
   . EffectFn2 (Preparer s) s { store :: Store s, setter :: OptimisticStore s }

-- | Follows `compute` like `createProjection`, with tentative updates layered
-- | on top during actions.
createOptimisticProjection
  :: forall s
   . StoreObject s
  => StoreValue s
  => Accessor (Update s)
  -> s
  -> Setup (Store s /\ OptimisticStore s)
createOptimisticProjection compute seed = Setup do
  parts <- runEffectFn3 createOptimisticProjectionImpl (preparer :: Preparer s) compute seed
  pure (parts.store /\ parts.setter)

foreign import createOptimisticProjectionImpl
  :: forall s
   . EffectFn3 (Preparer s) (Accessor (Update s)) s { store :: Store s, setter :: OptimisticStore s }

-- | A tentative update, as a step of a `Solid.Action.Action`.
updateOptimistic :: forall m s. MonadOptimistic m => OptimisticStore s -> Update s -> m Unit
updateOptimistic setter change = liftOptimistic (runEffectFn2 updateOptimisticImpl setter change)

foreign import updateOptimisticImpl :: forall s. EffectFn2 (OptimisticStore s) (Update s) Unit

-- | Marks the focused part of a store as pending until the action settles.
affects :: forall m store f s. MonadOptimistic m => StoreCursor store f => StoreObject s => store s -> m Unit
affects store = liftOptimistic (runEffectFn1 affectsImpl store)

foreign import affectsImpl :: forall store s. EffectFn1 (store s) Unit
