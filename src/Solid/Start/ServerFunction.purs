-- | Server functions (start mode, `@solidjs/web/server-functions`).
-- |
-- | A server function is an `async` function with a `"use server"` directive,
-- | written in an FFI file and declared as a `ServerFunction`:
-- |
-- | ```js
-- | // Todos.js
-- | export async function saveTodo(todo) {
-- |   "use server";
-- |   return db.insert(todo);
-- | }
-- | ```
-- | ```purescript
-- | foreign import saveTodo :: ServerFunction NewTodo { id :: Int }
-- |
-- | save = call saveTodo { title: "ship it" }
-- | ```
-- |
-- | The argument and result cross the network, so both must be
-- | `Serializable`. Use a record for several arguments.
-- |
-- | **Vite config:** compiled FFI lives in `output/`, outside the plugin's
-- | default `src/**` filter. Add `output/**/foreign.js` to
-- | `serverFunctions.filter.include`, or the function isn't transformed and
-- | ships to the browser. `call` refuses to run an untransformed function on
-- | the client.
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

-- | A `"use server"` function taking `a` and resolving to `b`.
foreign import data ServerFunction :: Type -> Type -> Type

-- | Calls a server function: directly on the server, over the network from
-- | the client.
call :: forall a b. Serializable a => Serializable b => ServerFunction a b -> a -> Aff b
call fn = toAffE <<< runEffectFn2 callImpl fn

foreign import callImpl :: forall a b. EffectFn2 (ServerFunction a b) a (Promise b)
