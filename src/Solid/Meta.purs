module Solid.Meta
  ( MetaError(..)
  , TagSetting
  , TagDescription
  , metaProvider
  , metaProvider_
  , metaProviderWith
  , title
  , titleWith
  , titleFrom
  , style
  , styleWith
  , meta
  , link
  , base
  , stylesheet
  , useHead
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe)
import Effect (Effect)
import Solid.JSX (JSX)
import Solid.Signal (Accessor)

data MetaError
  = MetaRuntimeError String

derive instance eqMetaError :: Eq MetaError

instance showMetaError :: Show MetaError where
  show = case _ of
    MetaRuntimeError message -> "MetaRuntimeError " <> show message

type TagSetting =
  { close :: Boolean
  , escape :: Boolean
  }

type TagDescription props =
  { tag :: String
  , props :: { | props }
  , setting :: Maybe TagSetting
  , id :: String
  , name :: Maybe String
  }

foreign import metaProvider :: forall props. { | props } -> Array JSX -> JSX

foreign import metaProviderWith :: forall props. { | props } -> Effect JSX -> JSX

metaProvider_ :: Array JSX -> JSX
metaProvider_ = metaProvider {}

foreign import titleWithImpl :: forall props. { | props } -> String -> JSX

titleWith :: forall props. { | props } -> String -> JSX
titleWith = titleWithImpl

title :: String -> JSX
title = titleWith {}

foreign import titleFrom :: Accessor String -> JSX

foreign import styleWithImpl :: forall props. { | props } -> String -> JSX

styleWith :: forall props. { | props } -> String -> JSX
styleWith = styleWithImpl

style :: String -> JSX
style = styleWith {}

foreign import meta :: forall props. { | props } -> JSX

foreign import link :: forall props. { | props } -> JSX

foreign import base :: forall props. { | props } -> JSX

foreign import stylesheet :: forall props. { | props } -> JSX

foreign import useHeadImpl :: forall props. TagDescription props -> Effect (Either String Unit)

useHead :: forall props. TagDescription props -> Effect (Either MetaError Unit)
useHead tagDescription = do
  result <- useHeadImpl tagDescription
  pure case result of
    Left message -> Left (MetaRuntimeError message)
    Right unitValue -> Right unitValue
