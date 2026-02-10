module Solid.DOM
  ( text
  , element
  , element_
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

import Solid.JSX (JSX)
import Solid.JSX as JSX

text :: String -> JSX
text = JSX.text

foreign import element
  :: forall props
   . String
  -> { | props }
  -> Array JSX
  -> JSX

foreign import element_ :: String -> Array JSX -> JSX

div :: forall props. { | props } -> Array JSX -> JSX
div = element "div"

div_ :: Array JSX -> JSX
div_ = element_ "div"

span :: forall props. { | props } -> Array JSX -> JSX
span = element "span"

span_ :: Array JSX -> JSX
span_ = element_ "span"

button :: forall props. { | props } -> Array JSX -> JSX
button = element "button"

button_ :: Array JSX -> JSX
button_ = element_ "button"

input :: forall props. { | props } -> Array JSX -> JSX
input = element "input"

input_ :: Array JSX -> JSX
input_ = element_ "input"

form :: forall props. { | props } -> Array JSX -> JSX
form = element "form"

form_ :: Array JSX -> JSX
form_ = element_ "form"

ul :: forall props. { | props } -> Array JSX -> JSX
ul = element "ul"

ul_ :: Array JSX -> JSX
ul_ = element_ "ul"

li :: forall props. { | props } -> Array JSX -> JSX
li = element "li"

li_ :: Array JSX -> JSX
li_ = element_ "li"
