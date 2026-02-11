module Solid.Component
  ( Component
  , component
  , element
  , elementKeyed
  , children
  , createUniqueId
  , lazy
  ) where

import Effect (Effect)
import Solid.JSX (JSX)
import Solid.Signal (Accessor)

foreign import data Component :: Type -> Type

foreign import component
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

foreign import children :: Effect JSX -> Effect (Accessor JSX)

foreign import createUniqueId :: Effect String

foreign import lazy
  :: forall props
   . Effect (Component { | props })
  -> Component { | props }
