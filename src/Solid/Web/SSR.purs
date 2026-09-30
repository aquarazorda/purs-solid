-- | Server rendering. Run under Node's default export conditions, which
-- | select Solid's server build.
module Solid.Web.SSR
  ( RenderOptions
  , renderToString
  , renderToStringWith
  , renderToStringWithHead
  , renderToStringAsync
  , renderToStringAsyncWith
  , renderToReadableStream
  , hydrationScript
  , hydrationScriptWith
  ) where

import Prelude

import Control.Promise as Promise
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff as Aff
import Effect.Exception (Error, try)
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Prim.Row as Row
import Solid.Internal.View (JSX, Realized, realize)
import Web.Streams.ReadableStream (ReadableStream)

type RenderOptions =
  ( -- | CSP nonce for the inline hydration scripts.
    nonce :: String
  -- | Distinguishes several independently hydrated roots on one page.
  , renderId :: String
  -- | Omit hydration scripts (static HTML that won't be hydrated).
  , noScripts :: Boolean
  -- | Sees every error the render handles (an `errored` fallback, a rejected
  -- | `loading` boundary), once per error.
  , onError :: Error -> Effect Unit
  )

renderToString :: JSX -> Effect (Either Error String)
renderToString = renderToStringWith {}

-- | Takes any subset of `RenderOptions`.
renderToStringWith
  :: forall given missing
   . Row.Union given missing RenderOptions
  => { | given }
  -> JSX
  -> Effect (Either Error String)
renderToStringWith options view =
  try (runEffectFn3 renderToStringImpl realize options view)

-- | Returns head-bound markup (head tags, asset links, styles) separately, for
-- | a host that owns the `<head>` template.
renderToStringWithHead
  :: forall given missing
   . Row.Union given missing RenderOptions
  => { | given }
  -> JSX
  -> Effect (Either Error { html :: String, head :: String })
renderToStringWithHead options view =
  try (runEffectFn3 renderToStringWithHeadImpl realize options view)

-- | Waits for all async work. `Left` only for errors thrown while starting the
-- | render; later render errors go to `onError`.
renderToStringAsync :: JSX -> Aff (Either Error String)
renderToStringAsync = renderToStringAsyncWith {}

renderToStringAsyncWith
  :: forall given missing
   . Row.Union given missing RenderOptions
  => { | given }
  -> JSX
  -> Aff (Either Error String)
renderToStringAsyncWith options view =
  Aff.try (Promise.toAffE (runEffectFn3 renderToStringAsyncImpl realize options view))

-- | Streams the HTML: the shell first, then each boundary as it resolves.
-- | `Left` only for errors thrown while starting the render; later render
-- | errors go to `onError`.
renderToReadableStream
  :: forall given missing
   . Row.Union given missing RenderOptions
  => { | given }
  -> JSX
  -> Effect (Either Error (ReadableStream Uint8Array))
renderToReadableStream options view =
  try (runEffectFn3 renderToReadableStreamImpl realize options view)

-- | The script that captures events before hydration; put it in `<head>`.
hydrationScript :: Effect (Either Error String)
hydrationScript = hydrationScriptWith {}

hydrationScriptWith
  :: forall given missing
   . Row.Union given missing (nonce :: String)
  => { | given }
  -> Effect (Either Error String)
hydrationScriptWith options =
  try (runEffectFn1 hydrationScriptImpl options)

foreign import renderToStringImpl :: forall options. EffectFn3 (JSX -> Realized) { | options } JSX String

foreign import renderToStringWithHeadImpl
  :: forall options. EffectFn3 (JSX -> Realized) { | options } JSX { html :: String, head :: String }

foreign import renderToStringAsyncImpl
  :: forall options. EffectFn3 (JSX -> Realized) { | options } JSX (Promise.Promise String)

foreign import renderToReadableStreamImpl
  :: forall options. EffectFn3 (JSX -> Realized) { | options } JSX (ReadableStream Uint8Array)

foreign import hydrationScriptImpl :: forall options. EffectFn1 { | options } String
