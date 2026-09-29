module Solid.Component
  ( Component
  , component
  , element
  , elementKeyed
  , children
  , createUniqueId
  , lazy
  ) where

import Prelude

import Control.Promise (Promise, fromAff)
import Effect (Effect)
import Effect.Aff (Aff)
import Solid.Internal.Setup (Setup(..), runSetup)
import Solid.JSX (JSX)
import Solid.Signal (Accessor)

foreign import data Component :: Type -> Type

type role Component representational

-- | Defines a component. The body runs once per instance, in `Setup`.
component :: forall props. ({ | props } -> Setup JSX) -> Component { | props }
component render = componentImpl (runSetup <<< render)

foreign import componentImpl
  :: forall props
   . ({ | props } -> Effect JSX)
  -> Component { | props }

foreign import element
  :: forall props
   . Component { | props }
  -> { | props }
  -> JSX

foreign import elementKeyed
  :: forall props
   . Component { | props }
  -> { key :: String | props }
  -> JSX

-- | Resolves children once and exposes them as an accessor, so a component
-- | can inspect or reuse them without re-creating them.
children :: Setup JSX -> Setup (Accessor JSX)
children resolve = Setup (childrenImpl (runSetup resolve))

foreign import childrenImpl :: Effect JSX -> Effect (Accessor JSX)

-- | A unique id, stable between server render and hydration.
createUniqueId :: Setup String
createUniqueId = Setup createUniqueIdImpl

foreign import createUniqueIdImpl :: Effect String

-- | A component whose definition is loaded on first render (e.g. by a
-- | dynamic import). Suspends the nearest loading boundary while loading.
lazy :: forall props. Aff (Component { | props }) -> Component { | props }
lazy load = lazyImpl (fromAff load)

foreign import lazyImpl
  :: forall props
   . Effect (Promise (Component { | props }))
  -> Component { | props }
