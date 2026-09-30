-- | A component's body runs once per use, in `Setup`. Props are a plain
-- | record: pass `Accessor`s for values that change.
module Solid.Component
  ( Component
  , component
  , element
  , children
  , childrenArray
  , createUniqueId
  , module Exports
  , lazy
  , clientOnly
  , preload
  ) where

import Prelude

import Control.Promise (Promise)
import Data.Function.Uncurried (Fn3, runFn2, runFn3)
import Data.Maybe (fromMaybe)
import Data.String as String
import Effect (Effect)
import Effect.Uncurried (runEffectFn1)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Internal.View (class LazyName, ComponentRep, JSX, LazyModule, childrenArrayImpl, childrenImpl, clientOnlyImpl, componentElement, componentRep, lazyImpl, lazyName, loadModule, preloadImpl)
import Solid.Internal.View (LazyModule) as Exports
import Solid.Signal (Accessor)
import Type.Proxy (Proxy(..))

type Component props = ComponentRep props

component :: forall props. ({ | props } -> Setup JSX) -> Component { | props }
component render = componentRep (runSetup <<< render)

element :: forall props. Component { | props } -> { | props } -> JSX
element = runFn2 componentElement

-- | Resolves children once, so a component can inspect or place them without
-- | re-creating them.
children :: Setup JSX -> Setup (Accessor JSX)
children resolve = Setup (runEffectFn1 childrenImpl (runSetup resolve))

-- | Like `children`, as the list of resolved children (a fragment is flattened).
childrenArray :: Setup JSX -> Setup (Accessor (Array JSX))
childrenArray resolve = Setup (runEffectFn1 childrenArrayImpl (runSetup resolve))

-- | A unique id, stable between server render and hydration.
createUniqueId :: Setup String
createUniqueId = Setup createUniqueIdImpl

foreign import createUniqueIdImpl :: Effect String

-- | Loaded on first use, suspending the nearest `loading` boundary. Named by
-- | the component's qualified name; `purs-solid/vite` bundles its module as a
-- | separate chunk:
-- |
-- | ```purescript
-- | settings :: Component { user :: User }
-- | settings = lazy @"App.Settings.settings"
-- | ```
lazy :: forall @name props. LazyName name => Component { | props }
lazy = withQualified @name lazyImpl

-- | Like `lazy`, but never runs on the server: the server, and hydration,
-- | render `fallback`; the component replaces it once loaded and hydrated.
-- | For browser-only code (`window`, DOM measurement). Loading starts on first
-- | render.
clientOnly :: forall @name props. LazyName name => Component { fallback :: JSX | props }
clientOnly = withQualified @name clientOnlyImpl

withQualified
  :: forall @name component
   . LazyName name
  => Fn3 String String (Effect (Promise LazyModule)) component
  -> component
withQualified load = runFn3 load moduleName (String.drop (dot + 1) name) (loadModule moduleName)
  where
  name = lazyName (Proxy :: Proxy name)
  dot = fromMaybe 0 (String.lastIndexOf (String.Pattern ".") name)
  moduleName = String.take dot name

-- | Starts loading a `lazy` component early (e.g. on hover). Does nothing for
-- | other components.
preload :: forall props. Component props -> Effect Unit
preload = runEffectFn1 preloadImpl
