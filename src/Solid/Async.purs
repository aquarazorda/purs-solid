-- | Async values in the reactive graph. In `createAsync`, read dependencies in
-- | the tracked `Accessor` layer; the `Aff` is untracked and is killed when a
-- | dependency changes. Values load on the client unless `ssr` is `serialized`
-- | or `withCodec`.
module Solid.Async
  ( AsyncOptions
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
  , UntilOptions
  , until
  , untilWith
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Argonaut.Core (Json)
import Data.Either (Either(..), either)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, notNull, null, toNullable)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds, effectCanceler, killFiber, launchAff_, makeAff, runAff)
import Effect.Exception (Error, error)
import Effect.Uncurried (EffectFn1, EffectFn4, mkEffectFn1, runEffectFn1, runEffectFn4)
import Prim.Row as Row
import Solid.Internal.Equality (Equality)
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.Serializable (class Serializable) as Exports
import Solid.Internal.Setup (Setup(..))
import Solid.Signal (Accessor)

type AsyncOptions a =
  ( name :: String
  , equals :: Equality a
  -- | Where the value loads when the page is server-rendered. Default `onClient`.
  , ssr :: AsyncSsr a
  -- | Hold the streamed shell until this value is ready.
  , deferStream :: Boolean
  )

-- | Where an async value loads when the page is server-rendered.
newtype AsyncSsr a = AsyncSsr
  { source :: String
  , encode :: Nullable (a -> Json)
  , decode :: Nullable (Json -> Either String a)
  }

-- | Load on the client; the server renders the loading fallback.
onClient :: forall a. AsyncSsr a
onClient = AsyncSsr { source: "client", encode: null, decode: null }

-- | Load on the server and send the value with the page.
serialized :: forall a. Serializable a => AsyncSsr a
serialized = AsyncSsr { source: "server", encode: null, decode: null }

-- | Load on the server and send the value encoded as JSON.
withCodec :: forall a. (a -> Json) -> (Json -> Either String a) -> AsyncSsr a
withCodec encode decode = AsyncSsr { source: "server", encode: notNull encode, decode: notNull decode }

-- | Re-runs one async value's work even though its inputs haven't changed.
foreign import data Refresh :: Type -> Type

createAsync :: forall a. Accessor (Aff a) -> Setup (Accessor a /\ Refresh a)
createAsync = createAsyncWith {}

-- | Takes any subset of `AsyncOptions`.
createAsyncWith
  :: forall a given missing
   . Row.Union given missing (AsyncOptions a)
  => { | given }
  -> Accessor (Aff a)
  -> Setup (Accessor a /\ Refresh a)
createAsyncWith options compute = Setup do
  parts <- runEffectFn4 createAsyncImpl start either options compute
  pure (parts.value /\ parts.refresh)

start :: forall a. Aff a -> (a -> Effect Unit) -> (Error -> Effect Unit) -> Effect (Effect Unit)
start aff onValue onError = do
  fiber <- runAff (either onError onValue) aff
  pure (launchAff_ (killFiber (error "purs-solid: superseded async value") fiber))

foreign import createAsyncImpl
  :: forall options a
   . EffectFn4
       (Aff a -> (a -> Effect Unit) -> (Error -> Effect Unit) -> Effect (Effect Unit))
       (forall r. (String -> r) -> (a -> r) -> Either String a -> r)
       { | options }
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
-- | the first load (that's what loading boundaries are for), nor for a bare
-- | `refresh`.
foreign import isPending :: forall a. Accessor a -> Accessor Boolean

-- | The in-flight value where one exists, instead of the settled one.
foreign import latest :: forall a. Accessor a -> Accessor a

-- | Waits for `accessor` to settle and returns its value.
resolve :: forall a. Accessor a -> Aff a
resolve accessor = toAffE (runEffectFn1 resolveImpl accessor)

foreign import resolveImpl :: forall a. EffectFn1 (Accessor a) (Promise a)

type UntilOptions =
  ( -- | Fail with a `TimeoutError` if the value doesn't arrive in time.
    timeout :: Milliseconds
  )

-- | Waits until `predicate` is `Just`, re-checking as its sources change. Reads
-- | see settled state, so an optimistic write can't satisfy it. Killing the
-- | fiber stops waiting.
until :: forall a. Accessor (Maybe a) -> Aff a
until = untilWith {}

-- | Takes any subset of `UntilOptions`.
untilWith
  :: forall a given missing
   . Row.Union given missing UntilOptions
  => { | given }
  -> Accessor (Maybe a)
  -> Aff a
untilWith options predicate = makeAff \done -> do
  cancel <- runEffectFn4 untilImpl options (toNullable <<< map { value: _ } <$> predicate)
    (mkEffectFn1 (done <<< Right <<< _.value))
    (mkEffectFn1 (done <<< Left))
  pure (effectCanceler cancel)

foreign import untilImpl
  :: forall options a
   . EffectFn4 { | options } (Accessor (Nullable { value :: a })) (EffectFn1 { value :: a } Unit) (EffectFn1 Error Unit) (Effect Unit)
