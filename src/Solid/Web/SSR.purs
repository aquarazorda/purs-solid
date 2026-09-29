module Solid.Web.SSR
  ( RenderStream
  , SsrError(..)
  , renderToString
  , renderToStringWithHead
  , renderToStringAsync
  , renderToStream
  , hydrationScript
  ) where

import Prelude

import Control.Promise as Promise
import Data.Bifunctor (lmap)
import Data.Either (Either)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff as Aff
import Effect.Uncurried (EffectFn2, runEffectFn2)
import Solid.Internal.View (JSX, Realized, realize)
import Solid.Internal.Error (errorMessage, tryMessage)

foreign import data RenderStream :: Type

data SsrError
  = RuntimeError String

derive instance eqSsrError :: Eq SsrError

instance showSsrError :: Show SsrError where
  show = case _ of
    RuntimeError message -> "RuntimeError " <> show message

renderToString :: JSX -> Effect (Either SsrError String)
renderToString view =
  mapError <$> tryMessage (runEffectFn2 renderToStringImpl realize view)

renderToStringAsync :: JSX -> Aff (Either SsrError String)
renderToStringAsync view =
  lmap (RuntimeError <<< errorMessage) <$> Aff.try (Promise.toAffE (runEffectFn2 renderToStringAsyncImpl realize view))

renderToStream :: JSX -> Effect (Either SsrError RenderStream)
renderToStream view =
  mapError <$> tryMessage (runEffectFn2 renderToStreamImpl realize view)

hydrationScript :: Effect (Either SsrError String)
hydrationScript =
  mapError <$> tryMessage hydrationScriptImpl

-- | Renders to HTML and also returns the head-bound markup (`useHead` tags,
-- | asset links, styles) for a host that owns the `<head>` template.
-- | Replaces Solid 1's `getAssets`.
renderToStringWithHead :: JSX -> Effect (Either SsrError { html :: String, head :: String })
renderToStringWithHead view =
  mapError <$> tryMessage (runEffectFn2 renderToStringWithHeadImpl realize view)

foreign import renderToStringImpl :: EffectFn2 (JSX -> Realized) JSX String

foreign import renderToStringAsyncImpl :: EffectFn2 (JSX -> Realized) JSX (Promise.Promise String)

foreign import renderToStreamImpl :: EffectFn2 (JSX -> Realized) JSX RenderStream

foreign import hydrationScriptImpl :: Effect String

foreign import renderToStringWithHeadImpl :: EffectFn2 (JSX -> Realized) JSX { html :: String, head :: String }

mapError :: forall a. Either String a -> Either SsrError a
mapError = lmap RuntimeError
