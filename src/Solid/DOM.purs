-- | Untyped escape hatches (any tag, any attribute) and props that aren't
-- | element-specific. Typed elements and props are in `Solid.DOM.HTML`,
-- | `Solid.DOM.SVG` and `Solid.DOM.Props`.
module Solid.DOM
  ( module Exports
  , element
  , element_
  , attr
  , dataAttr
  , ariaAttr
  , classWhen
  , innerHTML
  , ref
  , on
  ) where

import Prelude

import Effect (Effect)
import Solid.Internal.View (class ToBinding, JSX, Namespace(..), Prop, bindingProp, binding, elementWith, eventProp, refProp)
import Solid.Internal.View (class ToBinding, JSX, Prop) as Exports
import Web.DOM.Element (Element)
import Web.Event.Event (Event)
import Foreign.Object as Object

-- | Accepts any property (no attribute checking).
element :: forall r. String -> Array (Prop r) -> Array JSX -> JSX
element = elementWith HtmlNamespace

element_ :: String -> Array JSX -> JSX
element_ tag = elementWith HtmlNamespace tag []

attr :: forall r v. ToBinding v String => String -> v -> Prop r
attr name value = bindingProp name identity (binding value)

dataAttr :: forall r v. ToBinding v String => String -> v -> Prop r
dataAttr name = attr ("data-" <> name)

ariaAttr :: forall r v. ToBinding v String => String -> v -> Prop r
ariaAttr name = attr ("aria-" <> name)

-- | Adds the class while the condition holds; combines with `class_` and other
-- | `classWhen`s on the same element.
classWhen :: forall r v. ToBinding v Boolean => String -> v -> Prop (class :: String | r)
classWhen name condition = bindingProp "class" (Object.singleton name) (binding condition)

-- | The string is **not** escaped: only pass trusted or sanitized HTML.
innerHTML :: forall r v. ToBinding v String => v -> Prop r
innerHTML value = bindingProp "innerHTML" identity (binding value)

ref :: forall r. (Element -> Effect Unit) -> Prop r
ref = refProp

-- | Any event by DOM name. Solid lowercases the name and delegates it when
-- | it's one of the events Solid delegates.
on :: forall r. String -> (Event -> Effect Unit) -> Prop r
on name = eventProp ("on" <> name)
