module Solid.Store
  ( Store
  , StoreSetter
  , Mutable
  , createStore
  , get
  , unwrapStore
  , set
  , modify
  , getField
  , setField
  , modifyField
  , setPath
  , modifyPath
  , createMutable
  , getMutable
  , unwrapMutable
  , getMutableField
  , setMutableField
  , modifyMutableField
  , setMutablePath
  , modifyMutablePath
  ) where

import Prelude

import Data.Symbol (class IsSymbol, reflectSymbol)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Prim.Row as Row
import Type.Proxy (Proxy)

foreign import data Store :: Type -> Type
foreign import data StoreSetter :: Type -> Type
foreign import data Mutable :: Type -> Type

type StoreParts a =
  { store :: Store a
  , set :: StoreSetter a
  }

createStore :: forall a. a -> Effect (Store a /\ StoreSetter a)
createStore initial =
  toPair <$> createStoreImpl initial
  where
  toPair :: StoreParts a -> Store a /\ StoreSetter a
  toPair parts = parts.store /\ parts.set

foreign import createStoreImpl :: forall a. a -> Effect (StoreParts a)

foreign import get :: forall a. Store a -> Effect a

foreign import unwrapStore :: forall a. Store a -> Effect a

foreign import set :: forall a. StoreSetter a -> a -> Effect Unit

foreign import modify :: forall a. StoreSetter a -> (a -> a) -> Effect Unit

getField
  :: forall label value tail row
   . IsSymbol label
  => Row.Cons label value tail row
  => Proxy label
  -> Store { | row }
  -> Effect value
getField label store = getFieldImpl (reflectSymbol label) store

foreign import getFieldImpl :: forall a b. String -> Store a -> Effect b

setField
  :: forall label value tail row
   . IsSymbol label
  => Row.Cons label value tail row
  => Proxy label
  -> StoreSetter { | row }
  -> value
  -> Effect Unit
setField label setter next = setFieldImpl (reflectSymbol label) setter next

foreign import setFieldImpl
  :: forall a b
   . String
  -> StoreSetter a
  -> b
  -> Effect Unit

modifyField
  :: forall label value tail row
   . IsSymbol label
  => Row.Cons label value tail row
  => Proxy label
  -> StoreSetter { | row }
  -> (value -> value)
  -> Effect Unit
modifyField label setter update = modifyFieldImpl (reflectSymbol label) setter update

foreign import modifyFieldImpl
  :: forall a b
   . String
  -> StoreSetter a
  -> (b -> b)
  -> Effect Unit

foreign import setPath :: forall a b. StoreSetter a -> Array String -> b -> Effect Unit

foreign import modifyPath :: forall a b. StoreSetter a -> Array String -> (b -> b) -> Effect Unit

foreign import createMutable :: forall a. a -> Effect (Mutable a)

foreign import getMutable :: forall a. Mutable a -> Effect a

foreign import unwrapMutable :: forall a. Mutable a -> Effect a

getMutableField
  :: forall label value tail row
   . IsSymbol label
  => Row.Cons label value tail row
  => Proxy label
  -> Mutable { | row }
  -> Effect value
getMutableField label mutable = getMutableFieldImpl (reflectSymbol label) mutable

foreign import getMutableFieldImpl :: forall a b. String -> Mutable a -> Effect b

setMutableField
  :: forall label value tail row
   . IsSymbol label
  => Row.Cons label value tail row
  => Proxy label
  -> Mutable { | row }
  -> value
  -> Effect Unit
setMutableField label mutable next = setMutableFieldImpl (reflectSymbol label) mutable next

foreign import setMutableFieldImpl
  :: forall a b
   . String
  -> Mutable a
  -> b
  -> Effect Unit

modifyMutableField
  :: forall label value tail row
   . IsSymbol label
  => Row.Cons label value tail row
  => Proxy label
  -> Mutable { | row }
  -> (value -> value)
  -> Effect Unit
modifyMutableField label mutable update = modifyMutableFieldImpl (reflectSymbol label) mutable update

foreign import modifyMutableFieldImpl
  :: forall a b
   . String
  -> Mutable a
  -> (b -> b)
  -> Effect Unit

foreign import setMutablePath :: forall a b. Mutable a -> Array String -> b -> Effect Unit

foreign import modifyMutablePath :: forall a b. Mutable a -> Array String -> (b -> b) -> Effect Unit
