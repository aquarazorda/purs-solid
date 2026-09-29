-- | Building DOM elements.
-- |
-- | Typed elements live in `Solid.DOM.HTML` / `Solid.DOM.SVG`, and typed
-- | properties in `Solid.DOM.Props`. Each property value may be fixed or an
-- | `Accessor` (then it's reactive):
-- |
-- | ```purescript
-- | import Solid.DOM.HTML as H
-- | import Solid.DOM.Props as P
-- |
-- | H.button [ P.class_ "btn", P.disabled isSaving, P.onClick \_ -> save ]
-- |   [ text "Save" ]
-- | ```
-- |
-- | This module has the untyped escape hatches (any tag, any attribute) and
-- | props that aren't element-specific.
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

-- | An element by tag name, accepting any property (no attribute checking).
element :: forall r. String -> Array (Prop r) -> Array JSX -> JSX
element = elementWith HtmlNamespace

element_ :: String -> Array JSX -> JSX
element_ tag = elementWith HtmlNamespace tag []

-- | Any attribute by its DOM name, on any element.
attr :: forall r v. ToBinding v String => String -> v -> Prop r
attr name value = bindingProp name identity (binding value)

-- | `data-<name>`.
dataAttr :: forall r v. ToBinding v String => String -> v -> Prop r
dataAttr name = attr ("data-" <> name)

-- | `aria-<name>`.
ariaAttr :: forall r v. ToBinding v String => String -> v -> Prop r
ariaAttr name = attr ("aria-" <> name)

-- | Adds the class `name` while the condition holds. Combines with `class_`
-- | and other `classWhen`s on the same element:
-- | `[ P.class_ "todo", classWhen "done" isDone ]`.
classWhen :: forall r v. ToBinding v Boolean => String -> v -> Prop (class :: String | r)
classWhen name condition = bindingProp "class" (Object.singleton name) (binding condition)

-- | Sets the element's content from an HTML string. The string is **not**
-- | escaped: only pass trusted or sanitized HTML.
innerHTML :: forall r v. ToBinding v String => v -> Prop r
innerHTML value = bindingProp "innerHTML" identity (binding value)

-- | Runs with the element once it's created.
ref :: forall r. (Element -> Effect Unit) -> Prop r
ref = refProp

-- | A listener for any event by DOM name, for custom events and events
-- | without a typed helper. Solid lowercases the name, and delegates it when
-- | it's one of the events Solid delegates.
on :: forall r. String -> (Event -> Effect Unit) -> Prop r
on name = eventProp ("on" <> name)
