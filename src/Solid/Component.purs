module Solid.Component
  ( Component
  , component
  , element
  , elementKeyed
  ) where

import Effect (Effect)
import Solid.JSX (JSX)

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
