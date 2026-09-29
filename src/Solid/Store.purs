-- | Stores: nested reactive state with fine-grained updates.
-- |
-- | A `Store s` is a read-only cursor into reactive state. `focus` narrows it
-- | along a `Path`; `value` reads it as an `Accessor`, tracking exactly the
-- | part it reads. Writes go through the `StoreSetter` and are described by a
-- | pure `Update`, which the FFI applies to Solid 2's draft:
-- |
-- | ```purescript
-- | state /\ setState <- createStore { todos: [] :: Array Todo, filter: All }
-- |
-- | addTodo todo = Store.update setState $ Store.at (key @"todos") (Store.push todo)
-- |
-- | toggle id = Store.update setState $
-- |   Store.at (key @"todos") $ Store.eachWhere (\t -> t.id == id) $
-- |     Store.at (key @"done") (Store.modify not)
-- | ```
-- |
-- | Only the parts an update touches notify their readers.
-- |
-- | Records and arrays become reactive structure: each field and element is
-- | tracked on its own. Every other type (`Maybe`, your own data types, `Map`,
-- | ...) is an *atomic* value: stored as-is and replaced as a whole. That
-- | policy follows the type (`StoreValue`), so pattern matching on values read
-- | from a store always works.
module Solid.Store
  ( Store
  , StoreSetter
  , module Exports
  , class StoreObject
  , createStore
  , Path
  , key
  , focus
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
  , createProjection
  , createSelector
  , OptimisticStore
  , createOptimisticStore
  , createOptimisticProjection
  , updateOptimistic
  ) where

import Prelude

import Data.Nullable (Nullable)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn3, runEffectFn2, runEffectFn3)
import Prim.Row as Row
import Prim.TypeError (class Fail, Text)
import Solid.Internal.Action (Action, liftActionEffect)
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive)
import Solid.Internal.Store (class StoreValue, Preparer, preparer)
import Solid.Internal.Store (class StoreValue, class StoreFields) as Exports
import Solid.Signal (Accessor)
import Type.Proxy (Proxy(..))

-- | A read-only cursor into a store, focused on a value of type `a`.
foreign import data Store :: Type -> Type

-- | The capability to update a store.
foreign import data StoreSetter :: Type -> Type

-- | Types that can be the root of a store (Solid stores are objects).
class StoreObject :: Type -> Constraint
class StoreObject a

instance StoreObject (Record r)
else instance StoreObject (Array a)
else instance Fail (Text "A store must hold a record or an array; wrap other values in a record") => StoreObject a

-- | Creates a store. Allowed in `Effect` and `Setup` (stores need no owner).
-- | The initial value is never mutated.
createStore
  :: forall m s
   . MonadReactive m
  => StoreObject s
  => StoreValue s
  => s
  -> m (Store s /\ StoreSetter s)
createStore initial = liftReactive do
  parts <- runEffectFn2 createStoreImpl (preparer (Proxy :: Proxy s)) initial
  pure (parts.store /\ parts.setter)

foreign import createStoreImpl
  :: forall s
   . EffectFn2 (Nullable Preparer) s { store :: Store s, setter :: StoreSetter s }

-- | A path to a field inside a value, built from record labels. Always total:
-- | the field exists by type. Compose paths with `>>>` / `<<<`.
newtype Path :: Type -> Type -> Type
newtype Path s a = Path (Array String)

instance Semigroupoid Path where
  compose (Path inner) (Path outer) = Path (outer <> inner)

instance Category Path where
  identity = Path []

-- | The path to field `l`: `key @"todos"`.
key :: forall @l r a tail. IsSymbol l => Row.Cons l a tail r => Path (Record r) a
key = Path [ reflectSymbol (Proxy :: Proxy l) ]

-- | Narrows a store cursor along a path.
focus :: forall s a. Path s a -> Store s -> Store a
focus (Path keys) store = focusImpl keys store

foreign import focusImpl :: forall s a. Array String -> Store s -> Store a

-- | The current value, as an immutable PureScript value. Reading tracks the
-- | whole focused part; `focus` first to track less.
foreign import value :: forall a. Store a -> Accessor a

-- | A cursor per element, for list rendering. Cursors keep their identity
-- | while an element stays in the array, so keyed list rendering reuses rows
-- | and each row tracks only its own fields.
items :: forall a. StoreObject a => Store (Array a) -> Accessor (Array (Store a))
items = itemsImpl

foreign import itemsImpl :: forall a. Store (Array a) -> Accessor (Array (Store a))

-- | An untracked, immutable copy of the current value.
foreign import snapshot :: forall a. Store a -> Effect a

-- | A pure description of changes to a value of type `a`. Combine updates
-- | with `<>`; they apply in order, in one batch.
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

-- | Applies an update to the part of the value at `path`.
at :: forall s a. Path s a -> Update a -> Update s
at (Path keys) change = atImpl keys change

foreign import atImpl :: forall s a. Array String -> Update a -> Update s

-- | Replaces the value.
set :: forall a. StoreValue a => a -> Update a
set next = setImpl (preparer (Proxy :: Proxy a)) next

foreign import setImpl :: forall a. Nullable Preparer -> a -> Update a

-- | Replaces the value with a function of its current value.
modify :: forall a. StoreValue a => (a -> a) -> Update a
modify f = modifyImpl (preparer (Proxy :: Proxy a)) f

foreign import modifyImpl :: forall a. Nullable Preparer -> (a -> a) -> Update a

-- | Appends an element.
push :: forall a. StoreValue a => a -> Update (Array a)
push element = pushImpl (preparer (Proxy :: Proxy a)) element

foreign import pushImpl :: forall a. Nullable Preparer -> a -> Update (Array a)

-- | Keeps the elements satisfying the predicate, removing the rest in place
-- | (the kept elements keep their identity and their readers).
foreign import filter :: forall a. (a -> Boolean) -> Update (Array a)

-- | Applies an update to the element at an index; does nothing if the index
-- | is out of range.
foreign import atIndex :: forall a. Int -> Update a -> Update (Array a)

-- | Applies an update to every element.
foreign import each :: forall a. Update a -> Update (Array a)

-- | Applies an update to every element satisfying the predicate.
foreign import eachWhere :: forall a. (a -> Boolean) -> Update a -> Update (Array a)

-- | Replaces the value with `next`, keeping everything that didn't change
-- | (and its readers). Array elements are matched by their `id` field.
reconcile :: forall a. StoreValue a => a -> Update a
reconcile next = reconcileImpl (preparer (Proxy :: Proxy a)) next

-- | `reconcile` for an array, matching elements by a key function (e.g. after a
-- | refetch built fresh records). Keys are compared with `===`, so use
-- | primitives. Matched elements that are being observed (e.g. rendered rows
-- | reading their fields) keep their cursor, so their rows are reused.
reconcileBy :: forall a k. StoreValue a => (a -> k) -> Array a -> Update (Array a)
reconcileBy toKey next = reconcileByImpl (preparer (Proxy :: Proxy (Array a))) toKey next

foreign import reconcileImpl :: forall a. Nullable Preparer -> a -> Update a
foreign import reconcileByImpl :: forall a k. Nullable Preparer -> (a -> k) -> Array a -> Update (Array a)

-- | A read-only store derived from reactive sources: `compute` is tracked and
-- | yields the update to apply whenever its dependencies change, starting from
-- | `seed`. Unchanged parts keep their readers.
createProjection
  :: forall s
   . StoreObject s
  => StoreValue s
  => Accessor (Update s)
  -> s
  -> Setup (Store s)
createProjection compute seed =
  Setup (runEffectFn3 createProjectionImpl (preparer (Proxy :: Proxy s)) compute seed)

foreign import createProjectionImpl
  :: forall s
   . EffectFn3 (Nullable Preparer) (Accessor (Update s)) s (Store s)

-- | `isSelected x` is true when `source` currently equals `x` (compared by
-- | `toKey`). A selection change notifies only the two affected readers,
-- | instead of every row comparing against the selection.
createSelector :: forall a. (a -> String) -> Accessor a -> Setup (a -> Accessor Boolean)
createSelector toKey source = Setup (runEffectFn2 createSelectorImpl toKey source)

foreign import createSelectorImpl :: forall a. EffectFn2 (a -> String) (Accessor a) (a -> Accessor Boolean)

-- | The capability to update an optimistic store, only from a
-- | `Solid.Action.Action`. Its updates show immediately and revert when the
-- | action settles.
foreign import data OptimisticStore :: Type -> Type

-- | A store whose updates are tentative: made during an action, reverted
-- | when it settles (e.g. showing a new row before the server confirms it).
createOptimisticStore
  :: forall m s
   . MonadReactive m
  => StoreObject s
  => StoreValue s
  => s
  -> m (Store s /\ OptimisticStore s)
createOptimisticStore initial = liftReactive do
  parts <- runEffectFn2 createOptimisticStoreImpl (preparer (Proxy :: Proxy s)) initial
  pure (parts.store /\ parts.setter)

foreign import createOptimisticStoreImpl
  :: forall s
   . EffectFn2 (Nullable Preparer) s { store :: Store s, setter :: OptimisticStore s }

-- | An optimistic view of a projection: follows `compute` like
-- | `createProjection`, with tentative updates layered on top during actions.
createOptimisticProjection
  :: forall s
   . StoreObject s
  => StoreValue s
  => Accessor (Update s)
  -> s
  -> Setup (Store s /\ OptimisticStore s)
createOptimisticProjection compute seed = Setup do
  parts <- runEffectFn3 createOptimisticProjectionImpl (preparer (Proxy :: Proxy s)) compute seed
  pure (parts.store /\ parts.setter)

foreign import createOptimisticProjectionImpl
  :: forall s
   . EffectFn3 (Nullable Preparer) (Accessor (Update s)) s { store :: Store s, setter :: OptimisticStore s }

updateOptimistic :: forall s. OptimisticStore s -> Update s -> Action Unit
updateOptimistic setter change = liftActionEffect (runEffectFn2 updateOptimisticImpl setter change)

foreign import updateOptimisticImpl :: forall s. EffectFn2 (OptimisticStore s) (Update s) Unit
