-- | A component's body runs once per use, in `Setup`. Props are a plain
-- | record: pass `Accessor`s for values that change.
module Solid.Component
  ( Component
  , component
  , element
  , children
  , createUniqueId
  , lazy
  ) where

import Prelude

import Control.Promise (Promise)
import Data.Function.Uncurried (runFn2)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Internal.View (ComponentRep, JSX, childrenImpl, componentElement, componentRep, lazyImpl)
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

-- | Loaded on first use, suspending the nearest `loading` boundary. Usually a
-- | dynamic `import()` in an FFI file so the bundler splits it out:
-- |
-- | ```js
-- | export const loadSettings = () => import("../Settings/index.js").then((m) => m.settings);
-- | ```
lazy :: forall props. Effect (Promise (Component { | props })) -> Component { | props }
lazy = lazyImpl
