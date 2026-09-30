-- | The current server request, available in middleware, server functions and
-- | during rendering. On the client there is none.
module Solid.Start.RequestEvent
  ( RequestEvent
  , getRequestEvent
  , request
  , cookies
  , cookie
  , CookieOptions
  , SameSite
  , lax
  , strict
  , none
  , setCookie
  , deleteCookie
  , setResponseStatus
  , setResponseHeader
  , appendResponseHeader
  , LocalKey
  , localKey
  , getLocal
  , setLocal
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn3, EffectFn4, runEffectFn2, runEffectFn3, runEffectFn4)
import Foreign.Object (Object)
import Prim.Row as Row
import Foreign.Object as Object
import Web.Fetch.Request (Request)

foreign import data RequestEvent :: Type

getRequestEvent :: Effect (Maybe RequestEvent)
getRequestEvent = toMaybe <$> getRequestEventImpl

foreign import getRequestEventImpl :: Effect (Nullable RequestEvent)

foreign import request :: RequestEvent -> Request

-- | URI-decoded.
foreign import cookies :: RequestEvent -> Object String

cookie :: String -> RequestEvent -> Maybe String
cookie name = Object.lookup name <<< cookies

newtype SameSite = SameSite String

derive newtype instance Eq SameSite

lax :: SameSite
lax = SameSite "lax"

strict :: SameSite
strict = SameSite "strict"

none :: SameSite
none = SameSite "none"

type CookieOptions =
  ( path :: String
  , domain :: String
  -- | Seconds.
  , maxAge :: Int
  , httpOnly :: Boolean
  , secure :: Boolean
  , sameSite :: SameSite
  , partitioned :: Boolean
  )

-- | Takes any subset of `CookieOptions`. Unset fields default to path `/`,
-- | `HttpOnly`, `Secure` and `SameSite=Lax`.
setCookie
  :: forall given missing
   . Row.Union given missing CookieOptions
  => String
  -> String
  -> { | given }
  -> RequestEvent
  -> Effect Unit
setCookie name value options event = runEffectFn4 setCookieImpl event name value options

foreign import setCookieImpl :: forall options. EffectFn4 RequestEvent String String { | options } Unit

-- | Expires the cookie. Pass the `path` and `domain` it was set with.
deleteCookie
  :: forall given missing
   . Row.Union given missing CookieOptions
  => String
  -> { | given }
  -> RequestEvent
  -> Effect Unit
deleteCookie name options event = runEffectFn3 deleteCookieImpl event name options

foreign import deleteCookieImpl :: forall options. EffectFn3 RequestEvent String { | options } Unit

-- | For middleware and server functions; while rendering, use
-- | `Solid.Start.Response.httpStatus`.
setResponseStatus :: Int -> RequestEvent -> Effect Unit
setResponseStatus status event = runEffectFn2 setResponseStatusImpl event status

foreign import setResponseStatusImpl :: EffectFn2 RequestEvent Int Unit

setResponseHeader :: String -> String -> RequestEvent -> Effect Unit
setResponseHeader name value event = runEffectFn4 responseHeaderImpl event name value false

appendResponseHeader :: String -> String -> RequestEvent -> Effect Unit
appendResponseHeader name value event = runEffectFn4 responseHeaderImpl event name value true

foreign import responseHeaderImpl :: EffectFn4 RequestEvent String String Boolean Unit

-- | A typed slot in the request's `locals`. Define each key once and share it:
-- | two keys with the same name refer to the same slot.
newtype LocalKey :: Type -> Type
newtype LocalKey a = LocalKey String

localKey :: forall a. String -> LocalKey a
localKey = LocalKey

getLocal :: forall a. LocalKey a -> RequestEvent -> Effect (Maybe a)
getLocal (LocalKey name) event = toMaybe <$> runEffectFn2 getLocalImpl event name

setLocal :: forall a. LocalKey a -> a -> RequestEvent -> Effect Unit
setLocal (LocalKey name) value event = runEffectFn3 setLocalImpl event name value

foreign import getLocalImpl :: forall a. EffectFn2 RequestEvent String (Nullable a)

foreign import setLocalImpl :: forall a. EffectFn3 RequestEvent String a Unit
