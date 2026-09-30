-- | Paths are parsed at compile time, so a route's component receives exactly
-- | the params its path declares. Links are plain anchors
-- | (`P.href (href @"/users/:id" { id })`); the router intercepts same-origin
-- | clicks and marks the active link with `aria-current="page"`.
module Solid.Router
  ( Route
  , RouteProps
  , RouteOptions
  , PreloadArgs
  , route
  , routeWith
  , layout
  , layoutWith
  , layoutLazy
  , Router
  , History
  , RouterOptions
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
  , locationState
  , locationKey
  , useIsRouting
  , useMatch
  , LinkState
  , useLinkState
  , useResolvedPath
  , usePreloadRoute
  , BeforeLeave
  , useBeforeLeave
  , Navigate
  , NavigateOptions
  , useNavigate
  , navigate
  , navigateWith
  , navigateTo
  , go
  , module Exports
  ) where

import Prelude

import Data.Argonaut.Core (Json)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe, toNullable)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Prim.Row as Row
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive, runSetup)
import Solid.Internal.View (class LazyName, JSX, Realized, lazyName, loadModule, realize)
import Solid.Router.Path (class PathParams, RoutePattern, href, routePattern)
import Solid.Router.Path (href) as Exports
import Solid.Signal (Accessor)
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)

foreign import data Route :: Type

-- | `children` is the matched child route (for a layout).
type RouteProps params =
  { params :: Accessor { | params }
  , children :: JSX
  }

type RouteOptions params =
  ( -- | Runs before the route renders and when a link to it is hovered: start
    -- | loading its data here (`Solid.Router.Query.prefetch`).
    preload :: PreloadArgs params -> Effect Unit
  )

-- | `intent` is `"initial"`, `"navigate"`, `"native"` or `"preload"`.
type PreloadArgs params = { params :: { | params }, intent :: String }

-- | `route @"/users/:id<int>/:tab?" \props -> ...` (optional params are `Maybe`).
route
  :: forall @path params
   . IsSymbol path
  => PathParams path params
  => (RouteProps params -> Setup JSX)
  -> Route
route = routeWith @path {}

-- | Takes any subset of `RouteOptions`.
routeWith
  :: forall @path params given missing
   . IsSymbol path
  => PathParams path params
  => Row.Union given missing (RouteOptions params)
  => { | given }
  -> (RouteProps params -> Setup JSX)
  -> Route
routeWith options render = layoutWith @path options render []

-- | Render the matched child with `props.children`. Child paths are relative
-- | to this one.
layout
  :: forall @path params
   . IsSymbol path
  => PathParams path params
  => (RouteProps params -> Setup JSX)
  -> Array Route
  -> Route
layout = layoutWith @path {}

layoutWith
  :: forall @path params given missing
   . IsSymbol path
  => PathParams path params
  => Row.Union given missing (RouteOptions params)
  => { | given }
  -> (RouteProps params -> Setup JSX)
  -> Array Route
  -> Route
layoutWith options render children = defineRoute @path options render (unsafeCoerce children)

-- | A layout whose child routes load on first match, from the module `name`,
-- | which exports `routes :: Array Route`:
-- | `layoutLazy @"/admin" @"App.Admin" render`.
layoutLazy
  :: forall @path @name params
   . IsSymbol path
  => LazyName name
  => PathParams path params
  => (RouteProps params -> Setup JSX)
  -> Route
layoutLazy render = defineRoute @path {} render (unsafeCoerce (loadModule (lazyName (Proxy :: Proxy name))))

defineRoute
  :: forall @path params options
   . IsSymbol path
  => PathParams path params
  => { | options }
  -> (RouteProps params -> Setup JSX)
  -> RouteChildren
  -> Route
defineRoute options render children =
  routeImpl
    { pattern: routePattern (reflectSymbol (Proxy :: Proxy path))
    , options
    , render: \props -> runSetup (render props)
    , children
    , just: Just
    , nothing: Nothing
    , realize
    }

-- | `Array Route`, or an `Effect (Promise LazyModule)` for lazy children.
foreign import data RouteChildren :: Type

foreign import routeImpl
  :: forall params options
   . { pattern :: RoutePattern
     , options :: { | options }
     , render :: RouteProps params -> Effect JSX
     , children :: RouteChildren
     , just :: forall a. a -> Maybe a
     , nothing :: forall a. Maybe a
     , realize :: JSX -> Realized
     }
  -> Route

foreign import data Router :: Type

foreign import data History :: Type

browserHistory :: forall m. MonadReactive m => m History
browserHistory = liftReactive browserHistoryImpl

hashHistory :: forall m. MonadReactive m => m History
hashHistory = liftReactive hashHistoryImpl

-- | Starts at the given URL.
memoryHistory :: forall m. MonadReactive m => String -> m History
memoryHistory url = liftReactive (memoryHistoryImpl url)

foreign import browserHistoryImpl :: Effect History
foreign import hashHistoryImpl :: Effect History
foreign import memoryHistoryImpl :: String -> Effect History

type RouterOptions =
  ( -- | A path prefix for all routes (e.g. `"/app"`).
    base :: String
  -- | Browser history when left out.
  , history :: History
  -- | Warms app-wide data once per mount or request.
  , preload :: Effect Unit
  , singleFlight :: Boolean
  -- | The path prefix of server action URLs.
  , actionBase :: String
  -- | Only intercept links marked with `link` (instead of every same-origin link).
  , explicitLinks :: Boolean
  -- | Preload route code and data on link hover and focus.
  , preloadLinks :: Boolean
  , scrollRestoration :: Boolean
  , transformUrl :: String -> String
  )

-- | The route tree is fixed. Takes `routes` and any subset of `RouterOptions`.
-- | Works in `Effect` or `Setup`.
createRouter
  :: forall m given missing
   . MonadReactive m
  => Row.Union given missing RouterOptions
  => { routes :: Array Route | given }
  -> m Router
createRouter options = liftReactive (runEffectFn1 createRouterImpl options)

foreign import createRouterImpl :: forall options. EffectFn1 { | options } Router

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

-- | The `state` the navigation passed, if any.
locationState :: Location -> Accessor (Maybe Json)
locationState location = toMaybe <$> locationStateImpl location

foreign import locationStateImpl :: Location -> Accessor (Nullable Json)

-- | Identifies the history entry.
foreign import locationKey :: Location -> Accessor String

-- | `true` while a navigation (and the next route's data) is in progress.
useIsRouting :: Setup (Accessor Boolean)
useIsRouting = Setup useIsRoutingImpl

foreign import useIsRoutingImpl :: Effect (Accessor Boolean)

-- | The params of `path` while the location matches it:
-- | `useMatch @"/users/:id<int>"` is an `Accessor (Maybe { id :: Int })`.
useMatch :: forall @path params. IsSymbol path => PathParams path params => Setup (Accessor (Maybe { | params }))
useMatch = Setup (runEffectFn1 useMatchImpl { pattern: routePattern (reflectSymbol (Proxy :: Proxy path)), just: Just, nothing: Nothing })

foreign import useMatchImpl
  :: forall params
   . EffectFn1 { pattern :: RoutePattern, just :: forall a. a -> Maybe a, nothing :: forall a. Maybe a } (Accessor (Maybe { | params }))

-- | A link's state: `active` when the location is at or under it, `current`
-- | when it's exactly there, `pending` while navigating to it.
type LinkState =
  { active :: Accessor Boolean
  , current :: Accessor Boolean
  , pending :: Accessor Boolean
  }

useLinkState :: Accessor String -> Setup LinkState
useLinkState to = Setup (runEffectFn1 useLinkStateImpl to)

foreign import useLinkStateImpl :: EffectFn1 (Accessor String) LinkState

-- | Resolves a path against the current route, as an `href` would be.
useResolvedPath :: Accessor String -> Setup (Accessor (Maybe String))
useResolvedPath path = Setup (map toMaybe <$> runEffectFn1 useResolvedPathImpl path)

foreign import useResolvedPathImpl :: EffectFn1 (Accessor String) (Accessor (Nullable String))

-- | Loads a URL's route code and data ahead of navigating there.
usePreloadRoute :: Setup (String -> Effect Unit)
usePreloadRoute = Setup usePreloadRouteImpl

foreign import usePreloadRouteImpl :: Effect (String -> Effect Unit)

-- | A navigation away from the current route. `preventDefault` blocks it;
-- | `retry` tries it again, and `forceRetry` without asking the handlers.
type BeforeLeave =
  { to :: String
  , defaultPrevented :: Boolean
  , preventDefault :: Effect Unit
  , retry :: Effect Unit
  , forceRetry :: Effect Unit
  }

useBeforeLeave :: (BeforeLeave -> Effect Unit) -> Setup Unit
useBeforeLeave listener = Setup (runEffectFn1 useBeforeLeaveImpl listener)

foreign import useBeforeLeaveImpl :: EffectFn1 (BeforeLeave -> Effect Unit) Unit

foreign import data Navigate :: Type

type NavigateOptions =
  ( replace :: Boolean
  , scroll :: Boolean
  -- | Resolve relative to the current route (like an `href`).
  , resolve :: Boolean
  -- | Read back with `locationState`.
  , state :: Json
  )

useNavigate :: Setup Navigate
useNavigate = Setup useNavigateImpl

foreign import useNavigateImpl :: Effect Navigate

-- | Call from an event handler or effect.
navigate :: Navigate -> String -> Effect Unit
navigate = navigateWith {}

-- | Takes any subset of `NavigateOptions`.
navigateWith
  :: forall given missing
   . Row.Union given missing NavigateOptions
  => { | given }
  -> Navigate
  -> String
  -> Effect Unit
navigateWith options nav to = runEffectFn3 navigateImpl nav to options

-- | `navigateTo @"/users/:id<int>" nav { id: 42 }`.
navigateTo
  :: forall @path params
   . IsSymbol path
  => PathParams path params
  => Navigate
  -> { | params }
  -> Effect Unit
navigateTo nav params = navigate nav (href @path params)

foreign import navigateImpl :: forall options. EffectFn3 Navigate String { | options } Unit

-- | `go nav (-1)` is back.
go :: Navigate -> Int -> Effect Unit
go nav delta = runEffectFn2 goImpl nav delta

foreign import goImpl :: EffectFn2 Navigate Int Unit
