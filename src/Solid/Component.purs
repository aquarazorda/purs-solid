-- | Components.
-- |
-- | A component's body runs once per use, in `Setup`, and returns the view.
-- | Props are a plain PureScript record: pass `Accessor`s for values that
-- | change, so what's reactive shows in the component's type.
-- |
-- | ```purescript
-- | counter :: Component { label :: String, count :: Accessor Int }
-- | counter = component \props -> pure $
-- |   H.span_ [ text props.label, text (show <$> props.count) ]
-- | ```
module Solid.Component
  ( Component
  , component
  , element
  , children
  , createUniqueId
  , lazy
  ) where

import Prelude

import Control.Promise (fromAff)
import Data.Function.Uncurried (runFn2)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Uncurried (runEffectFn1)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.Internal.View (ComponentRep, JSX, childrenImpl, componentElement, componentRep, lazyImpl)
import Solid.Signal (Accessor)

type Component props = ComponentRep props

-- | Defines a component from its body.
component :: forall props. ({ | props } -> Setup JSX) -> Component { | props }
component render = componentRep (runSetup <<< render)

-- | A use of a component with the given props.
element :: forall props. Component { | props } -> { | props } -> JSX
element = runFn2 componentElement

-- | Resolves children once and exposes them as an accessor, so a component
-- | can inspect or place them without re-creating them.
children :: Setup JSX -> Setup (Accessor JSX)
children resolve = Setup (runEffectFn1 childrenImpl (runSetup resolve))

-- | A unique id, stable between server render and hydration.
createUniqueId :: Setup String
createUniqueId = Setup createUniqueIdImpl

foreign import createUniqueIdImpl :: Effect String

-- | A component whose definition is loaded on first use (e.g. via a dynamic
-- | import). Suspends the nearest `Solid.Control.loading` boundary meanwhile.
lazy :: forall props. Aff (Component { | props }) -> Component { | props }
lazy load = lazyImpl (fromAff load)
