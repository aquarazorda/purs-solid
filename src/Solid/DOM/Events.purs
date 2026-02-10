module Solid.DOM.Events
  ( Event
  , EventHandler
  , handler
  , handler_
  ) where

import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Prelude (Unit)

foreign import data Event :: Type

type EventHandler = EffectFn1 Event Unit

handler :: (Event -> Effect Unit) -> EventHandler
handler = mkEffectFn1

handler_ :: Effect Unit -> EventHandler
handler_ action = mkEffectFn1 \_ -> action
