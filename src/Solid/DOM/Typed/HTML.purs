module Solid.DOM.Typed.HTML
  ( a
  , a_
  , div
  , div_
  , span
  , span_
  , button
  , button_
  , input
  , input_
  , form
  , form_
  , ul
  , ul_
  , li
  , li_
  ) where

import Solid.DOM.Typed as Typed
import Solid.JSX (JSX)

a :: Array (Typed.Prop Typed.AnchorTag) -> Array JSX -> JSX
a = Typed.render "a"

a_ :: Array JSX -> JSX
a_ = Typed.render_ "a"

div :: Array (Typed.Prop Typed.DivTag) -> Array JSX -> JSX
div = Typed.render "div"

div_ :: Array JSX -> JSX
div_ = Typed.render_ "div"

span :: Array (Typed.Prop Typed.SpanTag) -> Array JSX -> JSX
span = Typed.render "span"

span_ :: Array JSX -> JSX
span_ = Typed.render_ "span"

button :: Array (Typed.Prop Typed.ButtonTag) -> Array JSX -> JSX
button = Typed.render "button"

button_ :: Array JSX -> JSX
button_ = Typed.render_ "button"

input :: Array (Typed.Prop Typed.InputTag) -> Array JSX -> JSX
input = Typed.render "input"

input_ :: Array JSX -> JSX
input_ = Typed.render_ "input"

form :: Array (Typed.Prop Typed.FormTag) -> Array JSX -> JSX
form = Typed.render "form"

form_ :: Array JSX -> JSX
form_ = Typed.render_ "form"

ul :: Array (Typed.Prop Typed.UlTag) -> Array JSX -> JSX
ul = Typed.render "ul"

ul_ :: Array JSX -> JSX
ul_ = Typed.render_ "ul"

li :: Array (Typed.Prop Typed.LiTag) -> Array JSX -> JSX
li = Typed.render "li"

li_ :: Array JSX -> JSX
li_ = Typed.render_ "li"
