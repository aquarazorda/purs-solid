module Solid.Router
  ( RouterError(..)
  , Location
  , Navigate
  , NavigateOptions
  , defaultNavigateOptions
  , router
  , route
  , link
  , useLocation
  , pathname
  , search
  , hash
  , useNavigate
  , navigate
  , navigateBy
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)

import Solid.JSX (JSX)
import Solid.Signal (Accessor)

data RouterError
  = RouterRuntimeError String

derive instance eqRouterError :: Eq RouterError

instance showRouterError :: Show RouterError where
  show = case _ of
    RouterRuntimeError message -> "RouterRuntimeError " <> show message

type NavigateOptions =
  { resolve :: Boolean
  , replace :: Boolean
  , scroll :: Boolean
  }

defaultNavigateOptions :: NavigateOptions
defaultNavigateOptions =
  { resolve: true
  , replace: false
  , scroll: true
  }

type Navigate =
  String
  -> NavigateOptions
  -> Effect Unit

foreign import data Location :: Type

foreign import router :: forall props. { | props } -> Array JSX -> JSX

foreign import route :: forall props. { | props } -> Array JSX -> JSX

foreign import link :: forall props. { href :: String | props } -> Array JSX -> JSX

foreign import useLocationImpl :: Effect (Either String Location)

useLocation :: Effect (Either RouterError Location)
useLocation = do
  result <- useLocationImpl
  pure case result of
    Left message -> Left (RouterRuntimeError message)
    Right location -> Right location

foreign import pathname :: Location -> Accessor String

foreign import search :: Location -> Accessor String

foreign import hash :: Location -> Accessor String

foreign import useNavigateImpl :: Effect (Either String Navigate)

useNavigate :: Effect (Either RouterError Navigate)
useNavigate = do
  result <- useNavigateImpl
  pure case result of
    Left message -> Left (RouterRuntimeError message)
    Right navigateTo -> Right navigateTo

navigate :: Navigate -> String -> Effect Unit
navigate navigateTo destination =
  navigateTo destination defaultNavigateOptions

foreign import navigateBy :: Navigate -> Int -> Effect Unit
