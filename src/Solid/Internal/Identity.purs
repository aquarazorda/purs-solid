-- | Internal: not part of the public API.
module Solid.Internal.Identity
  ( class StableIdentity
  ) where

import Prim.TypeError (class Fail, Above, Quote, Text)
import Solid.Internal.Store (AsyncStore, Store)

-- | Values that stay `===` when a list is recomputed, so a list keyed by its
-- | items keeps each row: primitives and store cursors.
class StableIdentity :: Type -> Constraint
class StableIdentity a

instance StableIdentity Int
else instance StableIdentity Number
else instance StableIdentity String
else instance StableIdentity Boolean
else instance StableIdentity Char
else instance StableIdentity (Store a)
else instance StableIdentity (AsyncStore a)
else instance
  Fail
    ( Above (Text "Rows keyed by identity (===) are rebuilt whenever a ")
        ( Above (Quote a)
            ( Text
                " is rebuilt. Key by a field (forEachBy _.id), render Store.items, or use forEachByReference when the list keeps the same values."
            )
        )
    ) =>
  StableIdentity a
