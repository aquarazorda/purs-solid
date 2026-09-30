-- | Internal: not part of the public API.
module Solid.Internal.Serializable
  ( class Serializable
  , class SerializableFields
  ) where

import Prelude

import Data.Argonaut.Core (Json)
import Data.Either (Either)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable)
import Effect (Effect)
import Foreign.Object (Object)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Prim.TypeError (class Fail, Above, Beside, Quote, Text)
import Solid.Internal.Reply (Reply)

-- | Types that survive Solid's serialization unchanged: primitives, `Unit`,
-- | `Nullable`, `Json`, arrays, objects and records of them. A newtype over
-- | one can derive it (`derive newtype instance Serializable UserId`). ADTs
-- | lose their constructors, so they need an explicit codec.
class Serializable :: Type -> Constraint
class Serializable a

instance Serializable String
instance Serializable Int
instance Serializable Number
instance Serializable Boolean
instance Serializable Unit
instance Serializable Json
instance Serializable a => Serializable (Nullable a)
instance Serializable a => Serializable (Array a)
instance Serializable a => Serializable (Object a)
instance Serializable a => Serializable (Reply a)
instance (RowToList r rl, SerializableFields rl) => Serializable (Record r)

instance
  Fail
    ( Above (Beside (Text "Can't send ") (Beside (Quote (Maybe a)) (Text " between server and client as-is.")))
        (Text "Use `Nullable` (PureScript ADTs lose their constructors when serialized).")
    ) =>
  Serializable (Maybe a)

instance
  Fail
    ( Above (Beside (Text "Can't send ") (Beside (Quote (Either a b)) (Text " between server and client as-is.")))
        (Text "Use a record of `Nullable` fields, or an explicit JSON codec.")
    ) =>
  Serializable (Either a b)

instance Fail (Text "Functions can't be sent between server and client.") => Serializable (a -> b)

instance Fail (Text "Effects can't be sent between server and client.") => Serializable (Effect a)

class SerializableFields :: RowList Type -> Constraint
class SerializableFields rl

instance SerializableFields RL.Nil
instance (Serializable a, SerializableFields tail) => SerializableFields (RL.Cons l a tail)
