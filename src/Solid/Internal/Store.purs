-- | Internal: not part of the public API.
module Solid.Internal.Store
  ( Store
  , Preparer
  , class StoreValue
  , preparer
  , class StoreFields
  , storeFields
  , Fields
  ) where

import Data.Symbol (class IsSymbol, reflectSymbol)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Type.Proxy (Proxy(..))

-- | A read-only cursor into a store, focused on a value of type `a`.
foreign import data Store :: Type -> Type

-- | Freezes every atomic value inside an `a` so Solid stores it as-is. `null`
-- | means nothing to do.
foreign import data Preparer :: Type -> Type

-- | How a type is stored: records and arrays are tracked per field / element;
-- | anything else is atomic. Every type has an instance. `preparer` is a value,
-- | so it's built once per type.
class StoreValue :: Type -> Constraint
class StoreValue a where
  preparer :: Preparer a

instance StoreValue Int where
  preparer = noPreparer
else instance StoreValue Number where
  preparer = noPreparer
else instance StoreValue String where
  preparer = noPreparer
else instance StoreValue Boolean where
  preparer = noPreparer
else instance StoreValue Char where
  preparer = noPreparer
else instance (RowToList r rl, StoreFields rl) => StoreValue (Record r) where
  preparer = recordPreparer (storeFields :: Fields rl)
else instance StoreValue a => StoreValue (Array a) where
  preparer = arrayPreparer (preparer :: Preparer a)
else instance StoreValue a where
  preparer = atomicPreparer

foreign import data Fields :: RowList Type -> Type

class StoreFields :: RowList Type -> Constraint
class StoreFields rl where
  storeFields :: Fields rl

instance StoreFields RL.Nil where
  storeFields = noFields

instance (IsSymbol l, StoreValue a, StoreFields tail) => StoreFields (RL.Cons l a tail) where
  storeFields = consField (reflectSymbol (Proxy :: Proxy l)) (preparer :: Preparer a) (storeFields :: Fields tail)

foreign import noPreparer :: forall a. Preparer a
foreign import atomicPreparer :: forall a. Preparer a
foreign import recordPreparer :: forall r rl. Fields rl -> Preparer (Record r)
foreign import arrayPreparer :: forall a. Preparer a -> Preparer (Array a)
foreign import noFields :: Fields RL.Nil
foreign import consField :: forall l a tail. String -> Preparer a -> Fields tail -> Fields (RL.Cons l a tail)
