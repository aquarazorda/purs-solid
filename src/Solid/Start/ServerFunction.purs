-- | A `"use server"` function written in an FFI file. Argument and result must
-- | be `Serializable`; use a record for several arguments.
-- |
-- | ```js
-- | export async function saveTodo(todo) {
-- |   "use server";
-- |   return db.insert(todo);
-- | }
-- | ```
-- | ```purescript
-- | foreign import saveTodo :: ServerFunction NewTodo { id :: Int }
-- | ```
-- |
-- | **Vite config:** compiled FFI lives in `output/`, outside the plugin's
-- | default `src/**` filter. Add `output/**/foreign.js` to
-- | `serverFunctions.filter.include`, or server functions ship to the browser.
module Solid.Start.ServerFunction
  ( ServerFunction
  , call
  , module Exports
  ) where

import Control.Promise (Promise, toAffE)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn2, runEffectFn2)
import Prelude ((<<<))
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.Serializable (class Serializable) as Exports

foreign import data ServerFunction :: Type -> Type -> Type

-- | Runs directly on the server and over the network from the client.
call :: forall a b. Serializable a => Serializable b => ServerFunction a b -> a -> Aff b
call fn = toAffE <<< runEffectFn2 callImpl fn

foreign import callImpl :: forall a b. EffectFn2 (ServerFunction a b) a (Promise b)
