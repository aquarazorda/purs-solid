-- | Internal: which types Solid can send from server to client as-is.
-- | `Solid.Async` re-exports the class without its member (sealed).
module Solid.Internal.Serializable
  ( class Serializable
  , serializableProof
  , class SerializableFields
  ) where

import Prelude (Unit, unit)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Prim.TypeError (class Fail, Above, Beside, Quote, Text)
import Type.Proxy (Proxy)

-- | Types that survive Solid's hydration serialization unchanged: primitives,
-- | arrays and records of them. PureScript ADTs don't (under the default
-- | backend they lose their constructors), so they need an explicit codec.
class Serializable :: Type -> Constraint
class Serializable a where
  serializableProof :: Proxy a -> Unit

instance Serializable String where
  serializableProof _ = unit
else instance Serializable Int where
  serializableProof _ = unit
else instance Serializable Number where
  serializableProof _ = unit
else instance Serializable Boolean where
  serializableProof _ = unit
else instance Serializable a => Serializable (Array a) where
  serializableProof _ = unit
else instance (RowToList r rl, SerializableFields rl) => Serializable (Record r) where
  serializableProof _ = unit
else instance
  Fail
    ( Above (Beside (Text "Can't send ") (Beside (Quote a) (Text " from server to client as-is.")))
        (Text "Use `withCodec` with an explicit encoding (PureScript ADTs lose their constructors when serialized).")
    ) =>
  Serializable a where
  serializableProof _ = unit

class SerializableFields :: RowList Type -> Constraint
class SerializableFields rl

instance SerializableFields RL.Nil
instance (Serializable a, SerializableFields tail) => SerializableFields (RL.Cons l a tail)
