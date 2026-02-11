module Solid.Web.SSR
  ( RenderStream
  , SsrError(..)
  , renderToString
  , renderToStringAsync
  , renderToStream
  , hydrationScript
  ) where

import Prelude

import Control.Promise as Promise
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff (Aff)

foreign import data RenderStream :: Type

data SsrError
  = RuntimeError String

derive instance eqSsrError :: Eq SsrError

instance showSsrError :: Show SsrError where
  show = case _ of
    RuntimeError message -> "RuntimeError " <> show message

renderToString :: forall a. Effect a -> Effect (Either SsrError String)
renderToString view =
  mapError <$> renderToStringImpl view

renderToStringAsync :: forall a. Effect a -> Aff (Either SsrError String)
renderToStringAsync view = do
  result <- Promise.toAffE (renderToStringAsyncImpl view)
  pure (mapError result)

renderToStream :: forall a. Effect a -> Effect (Either SsrError RenderStream)
renderToStream view =
  mapError <$> renderToStreamImpl view

hydrationScript :: Effect (Either SsrError String)
hydrationScript =
  mapError <$> hydrationScriptImpl

foreign import renderToStringImpl :: forall a. Effect a -> Effect (Either String String)

foreign import renderToStringAsyncImpl
  :: forall a
   . Effect a
  -> Effect (Promise.Promise (Either String String))

foreign import renderToStreamImpl
  :: forall a
   . Effect a
  -> Effect (Either String RenderStream)

foreign import hydrationScriptImpl :: Effect (Either String String)

mapError :: forall a. Either String a -> Either SsrError a
mapError = case _ of
  Left message -> Left (RuntimeError message)
  Right value -> Right value
