-- | Responses. `httpStatus` / `httpHeader` declare the response head while
-- | server rendering; they're withdrawn if their scope is disposed before the
-- | head is sent, and do nothing on the client. A `Reply` is what a router
-- | action or server function returns to redirect, revalidate, or set a status.
module Solid.Start.Response
  ( httpStatus
  , httpStatusText
  , httpHeader
  , appendHttpHeader
  , module Exports
  , ReplyOptions
  , reply
  , redirect
  , redirectWith
  , reload
  , reloadWith
  , respond
  , respondWith
  ) where

import Prelude

import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Prim.Row as Row
import Solid.Internal.Reply (Reply)
import Solid.Internal.Reply (Reply) as Exports
import Solid.Internal.Setup (Setup(..))
import Solid.Router.Query (QueryKey)
import Unsafe.Coerce (unsafeCoerce)

httpStatus :: Int -> Setup Unit
httpStatus code = Setup (runEffectFn1 httpStatusImpl code)

httpStatusText :: Int -> String -> Setup Unit
httpStatusText code text = Setup (runEffectFn2 httpStatusTextImpl code text)

httpHeader :: String -> String -> Setup Unit
httpHeader name value = Setup (runEffectFn3 httpHeaderImpl name value false)

appendHttpHeader :: String -> String -> Setup Unit
appendHttpHeader name value = Setup (runEffectFn3 httpHeaderImpl name value true)

foreign import httpStatusImpl :: EffectFn1 Int Unit

foreign import httpStatusTextImpl :: EffectFn2 Int String Unit

foreign import httpHeaderImpl :: EffectFn3 String String Boolean Unit

type ReplyOptions =
  ( status :: Int
  , statusText :: String
  -- | The queries the mutation invalidated; `[]` revalidates nothing. Left
  -- | out, the router revalidates everything.
  , revalidate :: Array QueryKey
  )

-- | A plain result.
reply :: forall b. b -> Reply b
reply = unsafeCoerce

redirect :: forall b. String -> Reply b
redirect = redirectWith {}

-- | Takes any subset of `ReplyOptions`.
redirectWith :: forall b given missing. Row.Union given missing ReplyOptions => { | given } -> String -> Reply b
redirectWith options url = redirectImpl url options

-- | Revalidates the page's data without a value.
reload :: forall b. Reply b
reload = reloadImpl {}

reloadWith :: forall b given missing. Row.Union given missing ReplyOptions => { | given } -> Reply b
reloadWith = reloadImpl

-- | A result with a status or revalidation keys.
respond :: forall b. b -> Reply b
respond = respondWith {}

respondWith :: forall b given missing. Row.Union given missing ReplyOptions => { | given } -> b -> Reply b
respondWith options value = respondImpl value options

foreign import redirectImpl :: forall b options. String -> { | options } -> Reply b

foreign import reloadImpl :: forall b options. { | options } -> Reply b

foreign import respondImpl :: forall b options. b -> { | options } -> Reply b
