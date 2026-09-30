-- | Cached loaders keyed by name and argument. Define them at the top level
-- | with unique names; `runQuery` must be the first step of an `Aff` read by
-- | `createAsync`, so the cache sees who is reading it:
-- |
-- | ```purescript
-- | items /\ _ <- createAsync (runQuery stories <$> args)
-- | ```
module Solid.Router.Query
  ( Query
  , query
  , queryServer
  , runQuery
  , revalidate
  , revalidateWith
  , revalidateAll
  , module Exports
  ) where

import Prelude

import Control.Promise (Promise, fromAff, toAffE)
import Data.Function.Uncurried (Fn2, runFn2)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.Serializable (class Serializable) as Exports
import Solid.Internal.ServerFunction (ServerFunction, checked)

foreign import data Query :: Type -> Type -> Type

query :: forall a b. Serializable a => Serializable b => String -> (a -> Aff b) -> Query a b
query name load = runFn2 queryImpl name (fromAff <<< load)

-- | The client calls it with a `GET`. As with `call`, `output/**/foreign.js` must be
-- | in the Vite plugin's `serverFunctions.filter.include`.
queryServer :: forall a b. Serializable a => Serializable b => String -> ServerFunction a b -> Query a b
queryServer name fn = runFn2 queryServerImpl name (checked fn)

-- | From the cache when it's fresh, loading it otherwise.
runQuery :: forall a b. Query a b -> a -> Aff b
runQuery q argument = toAffE (runEffectFn2 runQueryImpl q argument)

-- | Marks every cached value of a query stale and reloads the ones on screen.
revalidate :: forall a b. Query a b -> Effect Unit
revalidate = runEffectFn1 revalidateImpl

-- | Marks one argument's cached value stale and reloads it if it's on screen.
revalidateWith :: forall a b. Query a b -> a -> Effect Unit
revalidateWith = runEffectFn2 revalidateWithImpl

-- | Marks every cached query value stale, and reloads the ones on screen.
foreign import revalidateAll :: Effect Unit

foreign import queryImpl :: forall a b. Fn2 String (a -> Effect (Promise b)) (Query a b)
foreign import queryServerImpl :: forall a b. Fn2 String (ServerFunction a b) (Query a b)
foreign import runQueryImpl :: forall a b. EffectFn2 (Query a b) a (Promise b)
foreign import revalidateImpl :: forall a b. EffectFn1 (Query a b) Unit
foreign import revalidateWithImpl :: forall a b. EffectFn2 (Query a b) a Unit
