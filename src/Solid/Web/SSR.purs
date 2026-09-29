-- | Server rendering (run under Node's default export conditions, which
-- | select Solid's server build).
-- |
-- | - `renderToString`: synchronous; loading boundaries render their
-- |   fallbacks.
-- | - `renderToStringAsync`: waits until every async value has settled.
-- | - `renderToReadableStream`: streams HTML as boundaries resolve.
-- |
-- | A Solid render stream can be consumed only once, so each function picks
-- | its consumer instead of handing out a stream object.
module Solid.Web.SSR
  ( SsrError(..)
  , RenderOptions
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

import Prelude

import Control.Promise as Promise
import Data.ArrayBuffer.Types (Uint8Array)
import Data.Bifunctor (lmap)
import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toNullable)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff as Aff
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Solid.Internal.Error (errorMessage, tryMessage)
import Solid.Internal.View (JSX, Realized, realize)
import Web.Streams.ReadableStream (ReadableStream)

data SsrError
  = RuntimeError String

derive instance eqSsrError :: Eq SsrError

instance showSsrError :: Show SsrError where
  show = case _ of
    RuntimeError message -> "RuntimeError " <> show message

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

renderToString :: JSX -> Effect (Either SsrError String)
renderToString = renderToStringWith defaultRenderOptions

renderToStringWith :: RenderOptions -> JSX -> Effect (Either SsrError String)
renderToStringWith options view =
  mapError <$> tryMessage (runEffectFn3 renderToStringImpl realize (toRep options) view)

-- | Renders to HTML and returns the head-bound markup (`useHead` tags, asset
-- | links, styles) separately, for a host that owns the `<head>` template.
-- | Replaces Solid 1's `getAssets`.
renderToStringWithHead :: RenderOptions -> JSX -> Effect (Either SsrError { html :: String, head :: String })
renderToStringWithHead options view =
  mapError <$> tryMessage (runEffectFn3 renderToStringWithHeadImpl realize (toRep options) view)

renderToStringAsync :: JSX -> Aff (Either SsrError String)
renderToStringAsync = renderToStringAsyncWith defaultRenderOptions

renderToStringAsyncWith :: RenderOptions -> JSX -> Aff (Either SsrError String)
renderToStringAsyncWith options view =
  lmap (RuntimeError <<< errorMessage)
    <$> Aff.try (Promise.toAffE (runEffectFn3 renderToStringAsyncImpl realize (toRep options) view))

-- | Streams the HTML as UTF-8 chunks: the shell first, then each boundary
-- | as it resolves. Hand the stream to a `Response` or pipe it to a socket.
renderToReadableStream :: RenderOptions -> JSX -> Effect (Either SsrError (ReadableStream Uint8Array))
renderToReadableStream options view =
  mapError <$> tryMessage (runEffectFn3 renderToReadableStreamImpl realize (toRep options) view)

-- | The script that captures events before hydration; put it in `<head>`.
hydrationScript :: Effect (Either SsrError String)
hydrationScript = hydrationScriptWith Nothing

hydrationScriptWith :: Maybe String -> Effect (Either SsrError String)
hydrationScriptWith nonce =
  mapError <$> tryMessage (runEffectFn1 hydrationScriptImpl (toNullable nonce))

foreign import renderToStringImpl :: EffectFn3 (JSX -> Realized) OptionsRep JSX String

foreign import renderToStringWithHeadImpl
  :: EffectFn3 (JSX -> Realized) OptionsRep JSX { html :: String, head :: String }

foreign import renderToStringAsyncImpl
  :: EffectFn3 (JSX -> Realized) OptionsRep JSX (Promise.Promise String)

foreign import renderToReadableStreamImpl
  :: EffectFn3 (JSX -> Realized) OptionsRep JSX (ReadableStream Uint8Array)

foreign import hydrationScriptImpl :: EffectFn1 (Nullable String) String

mapError :: forall a. Either String a -> Either SsrError a
mapError = lmap RuntimeError
