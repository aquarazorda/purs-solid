-- | Server functions are defined with `serverFunction` in a server module
-- | (see `Solid.Start.UseServer`) and called with `call` from anywhere.
module Solid.Start.ServerFunction
  ( serverFunction
  , serverFunctionWithEvent
  , call
  , CallOptions
  , callWith
  , module Exports
  ) where

import Prelude

import Control.Promise (Promise, fromAff)
import Data.Either (Either(..))
import Data.Maybe (maybe)
import Effect (Effect)
import Effect.Aff (Aff, effectCanceler, makeAff)
import Effect.Exception (Error, throw)
import Effect.Uncurried (EffectFn1, EffectFn5, mkEffectFn1, runEffectFn5)
import Prim.Row as Row
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.Serializable (class Serializable) as Exports
import Solid.Internal.ServerFunction (ServerFunction, checked)
import Solid.Internal.ServerFunction (ServerFunction) as Exports
import Solid.Start.RequestEvent (RequestEvent, getRequestEvent)

-- | Use a record for several arguments.
serverFunction :: forall a b. Serializable a => Serializable b => (a -> Aff b) -> ServerFunction a b
serverFunction run = serverFunctionImpl (fromAff <<< run)

-- | A server function that also gets the request it runs in.
serverFunctionWithEvent
  :: forall a b. Serializable a => Serializable b => (RequestEvent -> a -> Aff b) -> ServerFunction a b
serverFunctionWithEvent run = serverFunctionImpl \argument ->
  getRequestEvent >>= maybe (throw "purs-solid: server function called outside of a request") \event ->
    fromAff (run event argument)

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

foreign import serverFunctionImpl :: forall a b. (a -> Effect (Promise b)) -> ServerFunction a b

foreign import callImpl
  :: forall options a b
   . EffectFn5 { | options } (ServerFunction a b) a (EffectFn1 b Unit) (EffectFn1 Error Unit) (Effect Unit)
