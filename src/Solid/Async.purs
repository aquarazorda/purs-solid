-- | Async values as part of the reactive graph (Solid 2 replaces
-- | `createResource` and transitions with this).
-- |
-- | `createAsync` takes an `Accessor (Aff a)`. The accessor layer is tracked:
-- | read your dependencies there. The `Aff` is the async work, and it can't
-- | subscribe to anything (Solid 2 only tracks reads before the first await,
-- | and here the types say so). When a dependency changes, the running fiber
-- | is killed and a new one starts.
-- |
-- | While the first value loads, reading the accessor suspends the nearest
-- | loading boundary. After that, a pending update keeps showing the previous
-- | value; ask `isPending` to show that something is in flight.
-- |
-- | **Server rendering.** By default an async value loads on the client
-- | (`OnClient`): the server renders the loading fallback and nothing is
-- | serialized. To load on the server and hand the result to the client with
-- | the page, choose `serialized` (for plain data: primitives, arrays,
-- | records) or `withCodec` (anything else, e.g. via argonaut-codecs). This
-- | is explicit because PureScript ADTs don't survive serialization as-is.
module Solid.Async
  ( AsyncOptions
  , defaultAsyncOptions
  , AsyncSsr
  , onClient
  , serialized
  , withCodec
  , module Exports
  , createAsync
  , createAsyncWith
  , Refresh
  , refresh
  , refreshAff
  , isPending
  , latest
  , resolve
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Argonaut.Core (Json)
import Data.Either (Either, either)
import Data.Nullable (Nullable, notNull, null)
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.Serializable (class Serializable) as Exports
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Aff (Aff, killFiber, launchAff_, runAff)
import Effect.Exception (Error, error)
import Effect.Uncurried (EffectFn1, EffectFn5, runEffectFn1, runEffectFn5)
import Solid.Internal.Equality (Equality(..), EqualityFn, toEqualityFn)
import Solid.Internal.Setup (Setup(..))
import Solid.Signal (Accessor)

type AsyncOptions a =
  { name :: String
  , equality :: Equality a
  -- | Where the value loads during server rendering.
  , ssr :: AsyncSsr a
  -- | Hold the streamed shell until this value is ready (instead of streaming
  -- | its loading fallback first).
  , deferStream :: Boolean
  }

defaultAsyncOptions :: forall a. AsyncOptions a
defaultAsyncOptions =
  { name: ""
  , equality: DefaultEquals
  , ssr: onClient
  , deferStream: false
  }

-- | Where an async value loads when the page is server-rendered.
newtype AsyncSsr a = AsyncSsr
  { source :: String
  , encode :: Nullable (a -> Json)
  , decode :: Nullable (Json -> Either String a)
  }

-- | Load on the client; the server renders the loading fallback.
onClient :: forall a. AsyncSsr a
onClient = AsyncSsr { source: "client", encode: null, decode: null }

-- | Load on the server and send the value with the page. Only for types that
-- | serialize as-is (`Serializable`: primitives, arrays, records of them).
serialized :: forall a. Serializable a => AsyncSsr a
serialized = AsyncSsr { source: "server", encode: null, decode: null }

-- | Load on the server and send the value encoded as JSON.
withCodec :: forall a. (a -> Json) -> (Json -> Either String a) -> AsyncSsr a
withCodec encode decode = AsyncSsr { source: "server", encode: notNull encode, decode: notNull decode }

-- | The capability to re-run one async value's work even though its inputs
-- | haven't changed (Solid 1's `refetch`). Only `createAsync` produces it, so
-- | `refresh` can't be pointed at a derived accessor it wouldn't affect.
foreign import data Refresh :: Type -> Type

createAsync :: forall a. Accessor (Aff a) -> Setup (Accessor a /\ Refresh a)
createAsync = createAsyncWith defaultAsyncOptions

createAsyncWith :: forall a. AsyncOptions a -> Accessor (Aff a) -> Setup (Accessor a /\ Refresh a)
createAsyncWith options compute = Setup do
  parts <- runEffectFn5 createAsyncImpl start rep mode equals compute
  pure (parts.value /\ parts.refresh)
  where
  { mode, equals } = toEqualityFn options.equality
  AsyncSsr ssr = options.ssr
  rep :: AsyncRep a
  rep = { name: options.name, source: ssr.source, encode: ssr.encode, decode: ssr.decode, deferStream: options.deferStream, either }

-- | Starts an `Aff`, reporting its outcome; the returned effect kills it.
start :: forall a. Aff a -> (a -> Effect Unit) -> (Error -> Effect Unit) -> Effect (Effect Unit)
start aff onValue onError = do
  fiber <- runAff (either onError onValue) aff
  pure (launchAff_ (killFiber (error "purs-solid: superseded async value") fiber))

type AsyncRep a =
  { name :: String
  , source :: String
  , encode :: Nullable (a -> Json)
  , decode :: Nullable (Json -> Either String a)
  , deferStream :: Boolean
  , either :: forall r. (String -> r) -> (a -> r) -> Either String a -> r
  }

foreign import createAsyncImpl
  :: forall a
   . EffectFn5
       (Aff a -> (a -> Effect Unit) -> (Error -> Effect Unit) -> Effect (Effect Unit))
       (AsyncRep a)
       String
       (EqualityFn a)
       (Accessor (Aff a))
       { value :: Accessor a, refresh :: Refresh a }

-- | Re-runs the async work in the background.
refresh :: forall a. Refresh a -> Effect Unit
refresh target = runEffectFn1 refreshImpl target

foreign import refreshImpl :: forall a. EffectFn1 (Refresh a) Unit

-- | Re-runs the async work and waits until the graph settles with the new value.
refreshAff :: forall a. Refresh a -> Aff a
refreshAff target = toAffE (runEffectFn1 refreshPromiseImpl target)

foreign import refreshPromiseImpl :: forall a. EffectFn1 (Refresh a) (Promise a)

-- | `true` while a change to `accessor`'s value is in flight. Not `true` for
-- | the first load (that's what loading boundaries are for).
foreign import isPending :: forall a. Accessor a -> Accessor Boolean

-- | The in-flight value where one exists, instead of the settled one.
foreign import latest :: forall a. Accessor a -> Accessor a

-- | Waits for `accessor` to settle and returns its value.
resolve :: forall a. Accessor a -> Aff a
resolve accessor = toAffE (runEffectFn1 resolveImpl accessor)

foreign import resolveImpl :: forall a. EffectFn1 (Accessor a) (Promise a)
