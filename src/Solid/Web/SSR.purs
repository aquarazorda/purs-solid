module Solid.Web.SSR
  ( RenderStream
  , SsrError(..)
  , renderToString
  , renderToStringAsync
  , renderToStream
  , hydrationScript
  , getAssets
  ) where

import Prelude

import Control.Promise as Promise
import Data.Bifunctor (lmap)
import Data.Either (Either)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff as Aff
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Solid.Internal.Error (errorMessage, tryMessage)

foreign import data RenderStream :: Type

data SsrError
  = RuntimeError String

derive instance eqSsrError :: Eq SsrError

instance showSsrError :: Show SsrError where
  show = case _ of
    RuntimeError message -> "RuntimeError " <> show message

renderToString :: forall a. Effect a -> Effect (Either SsrError String)
renderToString view =
  mapError <$> tryMessage (runEffectFn1 renderToStringImpl view)

renderToStringAsync :: forall a. Effect a -> Aff (Either SsrError String)
renderToStringAsync view =
  lmap (RuntimeError <<< errorMessage) <$> Aff.try (Promise.toAffE (runEffectFn1 renderToStringAsyncImpl view))

renderToStream :: forall a. Effect a -> Effect (Either SsrError RenderStream)
renderToStream view =
  mapError <$> tryMessage (runEffectFn1 renderToStreamImpl view)

hydrationScript :: Effect (Either SsrError String)
hydrationScript =
  mapError <$> tryMessage hydrationScriptImpl

getAssets :: Effect (Either SsrError String)
getAssets =
  mapError <$> tryMessage getAssetsImpl

foreign import renderToStringImpl :: forall a. EffectFn1 (Effect a) String

foreign import renderToStringAsyncImpl :: forall a. EffectFn1 (Effect a) (Promise.Promise String)

foreign import renderToStreamImpl :: forall a. EffectFn1 (Effect a) RenderStream

foreign import hydrationScriptImpl :: Effect String

foreign import getAssetsImpl :: Effect String

mapError :: forall a. Either String a -> Either SsrError a
mapError = lmap RuntimeError
