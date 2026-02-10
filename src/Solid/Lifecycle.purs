module Solid.Lifecycle
  ( onCleanup
  , onMount
  ) where

import Prelude (Unit)

import Effect (Effect)

foreign import onCleanup :: Effect Unit -> Effect Unit

foreign import onMount :: Effect Unit -> Effect Unit
