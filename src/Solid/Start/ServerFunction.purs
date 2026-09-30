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
  ( call
  , CallOptions
  , callWith
  , module Exports
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff (Aff, effectCanceler, makeAff)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn1, EffectFn5, mkEffectFn1, runEffectFn5)
import Prim.Row as Row
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.Serializable (class Serializable) as Exports
import Solid.Internal.ServerFunction (ServerFunction, checked)
import Solid.Internal.ServerFunction (ServerFunction) as Exports

-- | Runs directly on the server and over the network from the client.
-- | Killing the fiber aborts the request.
call :: forall a b. Serializable a => Serializable b => ServerFunction a b -> a -> Aff b
call = callWith {}

type CallOptions =
  ( -- | Let the request outlive the page (e.g. during `pagehide`).
    keepalive :: Boolean
  )

-- | Takes any subset of `CallOptions`.
callWith
  :: forall a b given missing
   . Serializable a
  => Serializable b
  => Row.Union given missing CallOptions
  => { | given }
  -> ServerFunction a b
  -> a
  -> Aff b
callWith options fn argument = makeAff \done -> do
  cancel <- runEffectFn5 callImpl options (checked fn) argument
    (mkEffectFn1 (done <<< Right))
    (mkEffectFn1 (done <<< Left))
  pure (effectCanceler cancel)

foreign import callImpl
  :: forall options a b
   . EffectFn5 { | options } (ServerFunction a b) a (EffectFn1 b Unit) (EffectFn1 Error Unit) (Effect Unit)
