-- | The current server request (start mode / `@solidjs/web`).
-- |
-- | Available on the server while handling a request: in middleware, server
-- | functions and during rendering. On the client there is none.
module Solid.Start.RequestEvent
  ( RequestEvent
  , getRequestEvent
  , request
  , cookies
  , cookie
  , CookieOptions
  , defaultCookieOptions
  , SameSite(..)
  , setCookie
  , LocalKey
  , localKey
  , getLocal
  , setLocal
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe, toNullable)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn3, EffectFn4, runEffectFn2, runEffectFn3, runEffectFn4)
import Foreign.Object (Object)
import Foreign.Object as Object
import Web.Fetch.Request (Request)

foreign import data RequestEvent :: Type

-- | The request being handled, if any (`Nothing` on the client).
getRequestEvent :: Effect (Maybe RequestEvent)
getRequestEvent = toMaybe <$> getRequestEventImpl

foreign import getRequestEventImpl :: Effect (Nullable RequestEvent)

foreign import request :: RequestEvent -> Request

-- | The request's cookies (URI-decoded).
foreign import cookies :: RequestEvent -> Object String

cookie :: String -> RequestEvent -> Maybe String
cookie name = Object.lookup name <<< cookies

data SameSite = Lax | Strict | None

type CookieOptions =
  { path :: String
  , domain :: Maybe String
  -- | Seconds.
  , maxAge :: Maybe Int
  , httpOnly :: Boolean
  , secure :: Boolean
  , sameSite :: Maybe SameSite
  }

-- | Path `/`, `HttpOnly`, `Secure`, `SameSite=Lax`.
defaultCookieOptions :: CookieOptions
defaultCookieOptions =
  { path: "/"
  , domain: Nothing
  , maxAge: Nothing
  , httpOnly: true
  , secure: true
  , sameSite: Just Lax
  }

-- | Adds a `Set-Cookie` header to the response for this request.
setCookie :: String -> String -> CookieOptions -> RequestEvent -> Effect Unit
setCookie name value options event =
  runEffectFn4 setCookieImpl event name value
    { path: options.path
    , domain: toNullable options.domain
    , maxAge: toNullable options.maxAge
    , httpOnly: options.httpOnly
    , secure: options.secure
    , sameSite: toNullable (sameSiteName <$> options.sameSite)
    }
  where
  sameSiteName = case _ of
    Lax -> "lax"
    Strict -> "strict"
    None -> "none"

foreign import setCookieImpl
  :: EffectFn4 RequestEvent String String
       { path :: String
       , domain :: Nullable String
       , maxAge :: Nullable Int
       , httpOnly :: Boolean
       , secure :: Boolean
       , sameSite :: Nullable String
       }
       Unit

-- | A typed slot in the request's `locals` (per-request state, e.g. the
-- | signed-in user set by middleware). Define each key once and share it;
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
