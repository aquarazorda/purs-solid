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

import Data.Bifunctor (lmap)
import Data.Either (Either)
import Effect (Effect)

import Solid.Internal.Error (tryMessage)
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
  { to :: String -> NavigateOptions -> Effect Unit
  , by :: Int -> Effect Unit
  }

foreign import data Location :: Type

foreign import router :: forall props. { | props } -> Array JSX -> JSX

foreign import route :: forall props. { | props } -> Array JSX -> JSX

foreign import link :: forall props. { href :: String | props } -> Array JSX -> JSX

foreign import useLocationImpl :: Effect Location

useLocation :: Effect (Either RouterError Location)
useLocation = lmap RouterRuntimeError <$> tryMessage useLocationImpl

foreign import pathname :: Location -> Accessor String

foreign import search :: Location -> Accessor String

foreign import hash :: Location -> Accessor String

foreign import useNavigateImpl :: Effect Navigate

useNavigate :: Effect (Either RouterError Navigate)
useNavigate = lmap RouterRuntimeError <$> tryMessage useNavigateImpl

navigate :: Navigate -> String -> Effect Unit
navigate navigateTo destination =
  navigateTo.to destination defaultNavigateOptions

navigateBy :: Navigate -> Int -> Effect Unit
navigateBy navigateTo delta =
  navigateTo.by delta
