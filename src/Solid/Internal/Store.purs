-- | Internal: the store value policy. `Solid.Store` re-exports the classes
-- | without their members, so the policy can't be overridden.
module Solid.Internal.Store
  ( Preparer
  , class StoreValue
  , preparer
  , class StoreFields
  , storeFields
  ) where

import Prelude

import Data.Nullable (Nullable, null)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Type.Proxy (Proxy(..))

-- | Prepares a value before it enters a store: freezes every atomic value
-- | inside it so Solid stores it as-is. `null` means nothing to do (primitives,
-- | or records and arrays of primitives), so writing those costs nothing extra.
foreign import data Preparer :: Type

-- | How a type is stored. Records and arrays are structural (tracked per
-- | field / element); primitives are plain values; anything else is atomic.
-- | Every type has an instance; the class is sealed (its member isn't
-- | exported), so the policy can't be overridden inconsistently.
class StoreValue :: Type -> Constraint
class StoreValue a where
  preparer :: Proxy a -> Nullable Preparer

instance StoreValue Int where
  preparer _ = null
else instance StoreValue Number where
  preparer _ = null
else instance StoreValue String where
  preparer _ = null
else instance StoreValue Boolean where
  preparer _ = null
else instance StoreValue Char where
  preparer _ = null
else instance (RowToList r rl, StoreFields rl) => StoreValue (Record r) where
  preparer _ = recordPreparer (storeFields (Proxy :: Proxy rl))
else instance StoreValue a => StoreValue (Array a) where
  preparer _ = arrayPreparer (preparer (Proxy :: Proxy a))
else instance StoreValue a where
  preparer _ = atomicPreparer

class StoreFields :: RowList Type -> Constraint
class StoreFields rl where
  storeFields :: Proxy rl -> Array { name :: String, preparer :: Nullable Preparer }

instance StoreFields RL.Nil where
  storeFields _ = []

instance (IsSymbol l, StoreValue a, StoreFields tail) => StoreFields (RL.Cons l a tail) where
  storeFields _ =
    [ { name: reflectSymbol (Proxy :: Proxy l), preparer: preparer (Proxy :: Proxy a) } ]
      <> storeFields (Proxy :: Proxy tail)

foreign import recordPreparer :: Array { name :: String, preparer :: Nullable Preparer } -> Nullable Preparer
foreign import arrayPreparer :: Nullable Preparer -> Nullable Preparer
foreign import atomicPreparer :: Nullable Preparer

