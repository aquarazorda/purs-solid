-- | Paths are parsed at compile time, so a route's component receives exactly
-- | the params its path declares. Links are plain anchors
-- | (`P.href (href @"/users/:id" { id })`); the router intercepts same-origin
-- | clicks and marks the active link with `aria-current="page"`.
module Solid.Router
  ( Route
  , RouteProps
  , route
  , layout
  , Router
  , History
  , RouterConfig
  , defaultRouterConfig
  , browserHistory
  , hashHistory
  , memoryHistory
  , createRouter
  , routerView
  , routerViewAt
  , Location
  , useLocation
  , pathname
  , search
  , hash
  , queryParam
  , useIsRouting
  , useMatch
  , Navigate
  , NavigateOptions
  , defaultNavigateOptions
  , useNavigate
  , navigate
  , navigateWith
  , navigateTo
  , go
  , module Exports
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe, toNullable)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Prim.RowList (class RowToList)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Internal.View (JSX, Realized, realize)
import Solid.Router.Path (class ParamFields, class PathParams, ParamField, href, paramFields)
import Solid.Router.Path (href) as Exports
import Solid.Signal (Accessor)
import Type.Proxy (Proxy(..))

foreign import data Route :: Type

-- | `children` is the matched child route (for a layout).
type RouteProps params =
  { params :: Accessor { | params }
  , children :: JSX
  }

-- | `route @"/users/:id/:tab?" \props -> ...` (optional params are `Maybe`).
route
  :: forall @path params rl
   . IsSymbol path
  => PathParams path params
  => RowToList params rl
  => ParamFields rl
  => (RouteProps params -> Setup JSX)
  -> Route
route render = layout @path render []

-- | Render the matched child with `props.children`. Child paths are relative
-- | to this one.
layout
  :: forall @path params rl
   . IsSymbol path
  => PathParams path params
  => RowToList params rl
  => ParamFields rl
  => (RouteProps params -> Setup JSX)
  -> Array Route
  -> Route
layout render children =
  routeImpl
    { path: reflectSymbol (Proxy :: Proxy path)
    , fields: paramFields (Proxy :: Proxy rl)
    , render: \props -> runSetup (render props)
    , children
    , just: Just
    , nothing: Nothing
    , realize
    }

foreign import routeImpl
  :: forall params
   . { path :: String
     , fields :: Array ParamField
     , render :: RouteProps params -> Effect JSX
     , children :: Array Route
     , just :: String -> Maybe String
     , nothing :: Maybe String
     , realize :: JSX -> Realized
     }
  -> Route

foreign import data Router :: Type

foreign import data History :: Type

foreign import browserHistory :: Effect History

foreign import hashHistory :: Effect History

-- | Starts at the given URL.
foreign import memoryHistory :: String -> Effect History

type RouterConfig =
  { routes :: Array Route
  -- | A path prefix for all routes (e.g. `"/app"`).
  , base :: Maybe String
  -- | `Nothing` uses browser history.
  , history :: Maybe History
  }

defaultRouterConfig :: RouterConfig
defaultRouterConfig = { routes: [], base: Nothing, history: Nothing }

-- | The route tree is fixed.
createRouter :: RouterConfig -> Effect Router
createRouter config =
  runEffectFn1 createRouterImpl
    { routes: config.routes, base: toNullable config.base, history: toNullable config.history }

foreign import createRouterImpl
  :: EffectFn1 { routes :: Array Route, base :: Nullable String, history :: Nullable History } Router

-- | `root` wraps the matched route (the app shell).
routerView :: Router -> (JSX -> Setup JSX) -> JSX
routerView router root = routerViewImpl router (toNullable Nothing) (runSetup <<< root) realize

-- | For server rendering when no request event provides the URL (static
-- | rendering, tests).
routerViewAt :: String -> Router -> (JSX -> Setup JSX) -> JSX
routerViewAt url router root = routerViewImpl router (toNullable (Just url)) (runSetup <<< root) realize

foreign import routerViewImpl :: Router -> Nullable String -> (JSX -> Effect JSX) -> (JSX -> Realized) -> JSX

foreign import data Location :: Type

useLocation :: Setup Location
useLocation = Setup useLocationImpl

foreign import useLocationImpl :: Effect Location

foreign import pathname :: Location -> Accessor String

foreign import search :: Location -> Accessor String

foreign import hash :: Location -> Accessor String

-- | The first value if repeated.
queryParam :: String -> Location -> Accessor (Maybe String)
queryParam name location = toMaybe <$> queryParamImpl name location

foreign import queryParamImpl :: String -> Location -> Accessor (Nullable String)

-- | `true` while a navigation (and the next route's data) is in progress.
useIsRouting :: Setup (Accessor Boolean)
useIsRouting = Setup useIsRoutingImpl

foreign import useIsRoutingImpl :: Effect (Accessor Boolean)

useMatch :: String -> Setup (Accessor Boolean)
useMatch pattern = Setup (runEffectFn1 useMatchImpl pattern)

foreign import useMatchImpl :: EffectFn1 String (Accessor Boolean)

foreign import data Navigate :: Type

type NavigateOptions =
  { replace :: Boolean
  , scroll :: Boolean
  -- | Resolve relative to the current route (like an `href`).
  , resolve :: Boolean
  }

defaultNavigateOptions :: NavigateOptions
defaultNavigateOptions = { replace: false, scroll: true, resolve: true }

useNavigate :: Setup Navigate
useNavigate = Setup useNavigateImpl

foreign import useNavigateImpl :: Effect Navigate

-- | Call from an event handler or effect.
navigate :: Navigate -> String -> Effect Unit
navigate nav to = runEffectFn2 navigateImpl nav { to, options: defaultNavigateOptions }

navigateWith :: NavigateOptions -> Navigate -> String -> Effect Unit
navigateWith options nav to = runEffectFn2 navigateImpl nav { to, options }

-- | `navigateTo @"/users/:id" nav { id: "42" }`.
navigateTo
  :: forall @path params
   . IsSymbol path
  => PathParams path params
  => Navigate
  -> { | params }
  -> Effect Unit
navigateTo nav params = navigate nav (href @path params)

foreign import navigateImpl :: EffectFn2 Navigate { to :: String, options :: NavigateOptions } Unit

-- | `go nav (-1)` is back.
go :: Navigate -> Int -> Effect Unit
go nav delta = runEffectFn2 goImpl nav delta

foreign import goImpl :: EffectFn2 Navigate Int Unit
