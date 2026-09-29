module Test.TypedDOM
  ( run
  ) where

import Prelude

import Effect (Effect)
import Solid.DOM.Typed as Typed
import Solid.DOM.Typed.HTML as HTML
import Solid.DOM.Events as Events

run :: Effect Unit
run = do
  let _ = Typed.idProp
  let _ = Typed.className
  let _ = Typed.customProp
  let _ = Typed.href
  let _ = Typed.type_
  let _ = Typed.onClick
  let _ = Typed.onInput
  let _ = Events.handler_
  let _ = HTML.div
  let _ = HTML.a
  let _ = HTML.input
  let _ = HTML.button
  let _ = HTML.ul_
  pure unit
