-- | A component's body runs once per use, in `Setup`. Props are a plain
-- | record: pass `Accessor`s for values that change.
module Solid.Component
  ( Component
  , component
  , element
  , children
  , createUniqueId
  , module Exports
  , lazy
  , clientOnly
  , preload
  ) where

import Prelude

import Control.Promise (Promise)
import Data.Function.Uncurried (runFn2)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Internal.View (ComponentRep, JSX, LazyModule, childrenImpl, clientOnlyImpl, componentElement, componentRep, lazyImpl, preloadImpl)
import Solid.Internal.View (LazyModule) as Exports
import Solid.Signal (Accessor)

type Component props = ComponentRep props

component :: forall props. ({ | props } -> Setup JSX) -> Component { | props }
component render = componentRep (runSetup <<< render)

element :: forall props. Component { | props } -> { | props } -> JSX
element = runFn2 componentElement

-- | Resolves children once, so a component can inspect or place them without
-- | re-creating them.
children :: Setup JSX -> Setup (Accessor JSX)
children resolve = Setup (runEffectFn1 childrenImpl (runSetup resolve))

-- | A unique id, stable between server render and hydration.
createUniqueId :: Setup String
createUniqueId = Setup createUniqueIdImpl

foreign import createUniqueIdImpl :: Effect String

-- | Loaded on first use, suspending the nearest `loading` boundary. `load` is
-- | a dynamic `import()` in an FFI file, and the name is the component's export:
-- |
-- | ```js
-- | export const loadSettings = () => import("../Settings/index.js");
-- | ```
-- | ```purescript
-- | settings = lazy "settings" loadSettings
-- | ```
lazy :: forall props. String -> Effect (Promise LazyModule) -> Component { | props }
lazy = runFn2 lazyImpl

-- | Like `lazy`, but never runs on the server: the server, and hydration,
-- | render `fallback`; the component replaces it once loaded and hydrated.
-- | For browser-only code (`window`, DOM measurement). Loading starts at once.
clientOnly :: forall props. String -> Effect (Promise LazyModule) -> Component { fallback :: JSX | props }
clientOnly = runFn2 clientOnlyImpl

-- | Starts loading a `lazy` component early (e.g. on hover). Does nothing for
-- | other components.
preload :: forall props. Component props -> Effect Unit
preload = runEffectFn1 preloadImpl
