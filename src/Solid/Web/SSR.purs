-- | Server rendering. Run under Node's default export conditions, which
-- | select Solid's server build.
module Solid.Web.SSR
  ( RenderOptions
  , defaultRenderOptions
  , renderToString
  , renderToStringWith
  , renderToStringWithHead
  , renderToStringAsync
  , renderToStringAsyncWith
  , renderToReadableStream
  , hydrationScript
  , hydrationScriptWith
  ) where


import Control.Promise as Promise
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toNullable)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff as Aff
import Effect.Exception (Error, try)
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Solid.Internal.View (JSX, Realized, realize)
import Web.Streams.ReadableStream (ReadableStream)

type RenderOptions =
  { -- | CSP nonce for the inline hydration scripts.
    nonce :: Maybe String
  -- | Distinguishes several independently hydrated roots on one page.
  , renderId :: Maybe String
  -- | Omit hydration scripts (static HTML that won't be hydrated).
  , noScripts :: Boolean
  }

defaultRenderOptions :: RenderOptions
defaultRenderOptions =
  { nonce: Nothing
  , renderId: Nothing
  , noScripts: false
  }

type OptionsRep =
  { nonce :: Nullable String
  , renderId :: Nullable String
  , noScripts :: Boolean
  }

toRep :: RenderOptions -> OptionsRep
toRep options =
  { nonce: toNullable options.nonce
  , renderId: toNullable options.renderId
  , noScripts: options.noScripts
  }

renderToString :: JSX -> Effect (Either Error String)
renderToString = renderToStringWith defaultRenderOptions

renderToStringWith :: RenderOptions -> JSX -> Effect (Either Error String)
renderToStringWith options view =
  try (runEffectFn3 renderToStringImpl realize (toRep options) view)

-- | Returns head-bound markup (head tags, asset links, styles) separately, for
-- | a host that owns the `<head>` template.
renderToStringWithHead :: RenderOptions -> JSX -> Effect (Either Error { html :: String, head :: String })
renderToStringWithHead options view =
  try (runEffectFn3 renderToStringWithHeadImpl realize (toRep options) view)

renderToStringAsync :: JSX -> Aff (Either Error String)
renderToStringAsync = renderToStringAsyncWith defaultRenderOptions

renderToStringAsyncWith :: RenderOptions -> JSX -> Aff (Either Error String)
renderToStringAsyncWith options view =
  Aff.try (Promise.toAffE (runEffectFn3 renderToStringAsyncImpl realize (toRep options) view))

-- | Streams the HTML: the shell first, then each boundary as it resolves.
renderToReadableStream :: RenderOptions -> JSX -> Effect (Either Error (ReadableStream Uint8Array))
renderToReadableStream options view =
  try (runEffectFn3 renderToReadableStreamImpl realize (toRep options) view)

-- | The script that captures events before hydration; put it in `<head>`.
hydrationScript :: Effect (Either Error String)
hydrationScript = hydrationScriptWith Nothing

hydrationScriptWith :: Maybe String -> Effect (Either Error String)
hydrationScriptWith nonce =
  try (runEffectFn1 hydrationScriptImpl (toNullable nonce))

foreign import renderToStringImpl :: EffectFn3 (JSX -> Realized) OptionsRep JSX String

foreign import renderToStringWithHeadImpl
  :: EffectFn3 (JSX -> Realized) OptionsRep JSX { html :: String, head :: String }

foreign import renderToStringAsyncImpl
  :: EffectFn3 (JSX -> Realized) OptionsRep JSX (Promise.Promise String)

foreign import renderToReadableStreamImpl
  :: EffectFn3 (JSX -> Realized) OptionsRep JSX (ReadableStream Uint8Array)

foreign import hydrationScriptImpl :: EffectFn1 (Nullable String) String
