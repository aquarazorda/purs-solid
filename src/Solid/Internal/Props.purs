-- | Element props as records. Each field is converted to a `Prop` by a
-- | function the instances build once per record type, so rendering only
-- | reads the fields and applies those functions.
module Solid.Internal.Props
  ( class Props
  , props
  , class UntypedProps
  , untypedProps
  , class Children
  , toChildren
  , applyProps
  , Typed
  , Untyped
  , class PropsRL
  , propsRL
  , class Entry
  , entry
  , class Prefixed
  , prefixed
  , class Supports
  , class ElementType
  , class Attribute
  , attribute
  , class RowField
  , field
  , class UntypedField
  , untypedField
  , class ClassValue
  , classValue
  , class StyleValue
  , styleValue
  , class Toggles
  , toggles
  , class StyleEntries
  , styleEntries
  , class StartsWith
  , class StartsWithChar
  , typedElement
  , typedVoidElement
  , untypedElement
  , targetValue
  , targetChecked
  ) where

import Prelude

import Data.Array as Array
import Data.String as String
import Data.Symbol (class IsSymbol, reflectSymbol)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Foreign.Object as Object
import Prim.Boolean (False, True)
import Prim.Row as Row
import Prim.RowList as RL
import Prim.Symbol as Symbol
import Record.Unsafe (unsafeGet)
import Solid.DOM.AttrValue (class AttrValue, toAttrValue)
import Solid.Internal.Names (attributeName, eventName)
import Solid.Internal.View (class ToBinding, JSX, Namespace, Prop, bindingProp, elementWith, eventProp, propsProp, refProp, textBinding)
import Solid.Signal (Signal, set)
import Type.Equality (class TypeEquals, to)
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)
import Web.Clipboard.ClipboardEvent (ClipboardEvent)
import Web.DOM.Element (Element)
import Web.Event.Event (Event)
import Web.HTML.Event.DragEvent (DragEvent)
import Web.PointerEvent (PointerEvent)
import Web.TouchEvent (TouchEvent)
import Web.UIEvent.FocusEvent (FocusEvent)
import Web.UIEvent.KeyboardEvent (KeyboardEvent)
import Web.UIEvent.MouseEvent (MouseEvent)
import Web.UIEvent.WheelEvent (WheelEvent)

-- | The value of the element the handler is on (an input, select or textarea).
foreign import targetValue :: Event -> Effect String

-- | The `checked` state of the checkbox or radio the handler is on.
foreign import targetChecked :: Event -> Effect Boolean

-- | Fields checked against an element's row.
data Typed (row :: Row Type)

-- | Fields taken as they are, for any tag.
data Untyped

-- | `props` is a record whose fields `row` accepts (see `Solid.DOM.HTML`).
class Props :: Row Type -> Row Type -> Constraint
class Props row props where
  props :: Array (Record props -> Prop ())

instance (RL.RowToList props list, PropsRL (Typed row) list props) => Props row props where
  props = propsRL @(Typed row) @list

class UntypedProps :: Row Type -> Constraint
class UntypedProps props where
  untypedProps :: Array (Record props -> Prop ())

instance (RL.RowToList props list, PropsRL Untyped list props) => UntypedProps props where
  untypedProps = propsRL @Untyped @list

applyProps :: forall props r. Array (Record props -> Prop ()) -> Record props -> Array (Prop r)
applyProps converters record = unsafeCoerce (map (_ $ record) converters)

typedElement :: forall @row props children. Props row props => Children children => Namespace -> String -> Record props -> children -> JSX
typedElement namespace tag record children = elementWith namespace tag (applyProps (props @row) record) (toChildren children)

typedVoidElement :: forall @row props. Props row props => Namespace -> String -> Record props -> JSX
typedVoidElement namespace tag record = elementWith namespace tag (applyProps (props @row) record) []

untypedElement :: forall props children. UntypedProps props => Children children => Namespace -> String -> Record props -> children -> JSX
untypedElement namespace tag record children = elementWith namespace tag (applyProps untypedProps record) (toChildren children)

-- | An element's children: one element, text (`String` or reactive), or an array.
class Children :: Type -> Constraint
class Children children where
  toChildren :: children -> Array JSX

instance Children JSX where
  toChildren child = [ child ]
else instance TypeEquals child JSX => Children (Array child) where
  toChildren = unsafeCoerce
else instance ToBinding text String => Children text where
  toChildren text = [ textBinding text ]

class PropsRL :: Type -> RL.RowList Type -> Row Type -> Constraint
class PropsRL kind list props where
  propsRL :: Array (Record props -> Prop ())

instance PropsRL kind RL.Nil props where
  propsRL = []

instance (IsSymbol label, Entry kind label value, PropsRL kind rest props) => PropsRL kind (RL.Cons label value rest) props where
  propsRL =
    let
      name = reflectSymbol (Proxy @label)
      convert = entry @kind @label @value
    in
      Array.cons (\record -> convert (unsafeGet name record)) (propsRL @kind @rest @props)

-- | One field, by its label.
class Entry :: Type -> Symbol -> Type -> Constraint
class Entry kind label value where
  entry :: value -> Prop ()

instance (ElementType kind element, TypeEquals value (element -> Effect Unit)) => Entry kind "ref" value where
  entry callback = refProp (unsafeCoerce (to callback))
else instance (Supports kind "class", ClassValue value) => Entry kind "class" value where
  entry = classValue
else instance (Supports kind "style", StyleValue value) => Entry kind "style" value where
  entry = styleValue
else instance (Supports kind "value", Supports kind "onInput", TypeEquals value (Signal String)) => Entry kind "bindValue" value where
  entry signal = case to signal of
    current /\ setter -> propsProp
      [ bindingProp "value" identity current, eventProp "onInput" \event -> targetValue event >>= set setter ]
else instance (Supports kind "checked", Supports kind "onChange", TypeEquals value (Signal Boolean)) => Entry kind "bindChecked" value where
  entry signal = case to signal of
    current /\ setter -> propsProp
      [ bindingProp "checked" identity current, eventProp "onChange" \event -> targetChecked event >>= set setter ]
else instance ToBinding value String => Entry kind "innerHTML" value where
  entry = bindingProp "innerHTML" identity
else instance ToBinding value String => Entry kind "textContent" value where
  entry = bindingProp "textContent" identity
else instance
  ( StartsWith "data-" label isData
  , StartsWith "aria-" label isAria
  , StartsWith "on:" label isEvent
  , Prefixed isData isAria isEvent kind label value
  ) =>
  Entry kind label value where
  entry = prefixed @isData @isAria @isEvent @kind @label

-- | `data-*` and `aria-*` attributes, `on:*` events, then everything else.
class Prefixed :: Boolean -> Boolean -> Boolean -> Type -> Symbol -> Type -> Constraint
class Prefixed isData isAria isEvent kind label value where
  prefixed :: value -> Prop ()

instance (IsSymbol label, ToBinding value String) => Prefixed True isAria isEvent kind label value where
  prefixed = bindingProp (reflectSymbol (Proxy @label)) identity

instance (IsSymbol label, ToBinding value String) => Prefixed False True isEvent kind label value where
  prefixed = bindingProp (reflectSymbol (Proxy @label)) identity

instance (IsSymbol label, TypeEquals value (Event -> Effect Unit)) => Prefixed False False True kind label value where
  prefixed =
    let
      name = "on" <> String.drop 3 (reflectSymbol (Proxy @label))
    in
      \callback -> eventProp name (to callback)

instance Attribute kind label value => Prefixed False False False kind label value where
  prefixed = attribute @kind @label

class Supports :: Type -> Symbol -> Constraint
class Supports kind label

instance Row.Cons label type_ rest row => Supports (Typed row) label
instance Supports Untyped label

class ElementType :: Type -> Type -> Constraint
class ElementType kind element | kind -> element

instance Row.Cons "$element" element rest row => ElementType (Typed row) element
instance ElementType Untyped Element

class Attribute :: Type -> Symbol -> Type -> Constraint
class Attribute kind label value where
  attribute :: value -> Prop ()

instance (IsSymbol label, Row.Cons label type_ rest row, RowField type_ value) => Attribute (Typed row) label value where
  attribute = field @type_ (reflectSymbol (Proxy @label))

instance (IsSymbol label, UntypedField value) => Attribute Untyped label value where
  attribute = untypedField (reflectSymbol (Proxy @label))

-- | A row field: an event handler for event types, otherwise an attribute
-- | value or an accessor of one.
class RowField :: Type -> Type -> Constraint
class RowField type_ value where
  field :: String -> value -> Prop ()

instance TypeEquals value (Event -> Effect Unit) => RowField Event value where
  field label = handler label <<< to
else instance TypeEquals value (MouseEvent -> Effect Unit) => RowField MouseEvent value where
  field label = handler label <<< to
else instance TypeEquals value (KeyboardEvent -> Effect Unit) => RowField KeyboardEvent value where
  field label = handler label <<< to
else instance TypeEquals value (FocusEvent -> Effect Unit) => RowField FocusEvent value where
  field label = handler label <<< to
else instance TypeEquals value (PointerEvent -> Effect Unit) => RowField PointerEvent value where
  field label = handler label <<< to
else instance TypeEquals value (DragEvent -> Effect Unit) => RowField DragEvent value where
  field label = handler label <<< to
else instance TypeEquals value (TouchEvent -> Effect Unit) => RowField TouchEvent value where
  field label = handler label <<< to
else instance TypeEquals value (ClipboardEvent -> Effect Unit) => RowField ClipboardEvent value where
  field label = handler label <<< to
else instance TypeEquals value (WheelEvent -> Effect Unit) => RowField WheelEvent value where
  field label = handler label <<< to
else instance (ToBinding value type_, AttrValue type_) => RowField type_ value where
  field label = bindingProp (attributeName label) toAttrValue

handler :: forall event. String -> (event -> Effect Unit) -> Prop ()
handler label = eventProp (eventName label)

-- | On an untyped element, functions are event handlers (label them `onX`)
-- | and anything else is an attribute named exactly as the label.
class UntypedField :: Type -> Constraint
class UntypedField value where
  untypedField :: String -> value -> Prop ()

instance UntypedField (event -> Effect Unit) where
  untypedField = eventProp
else instance (ToBinding value a, AttrValue a) => UntypedField value where
  untypedField label = bindingProp label toAttrValue

-- | `class`: a string (or accessor), or a record of classes to toggles.
class ClassValue :: Type -> Constraint
class ClassValue value where
  classValue :: value -> Prop ()

instance (RL.RowToList classes list, Toggles list classes) => ClassValue (Record classes) where
  classValue = let converters = toggles @list in \record -> propsProp (map (_ $ record) converters)
else instance ToBinding value String => ClassValue value where
  classValue = bindingProp "class" identity

class Toggles :: RL.RowList Type -> Row Type -> Constraint
class Toggles list classes where
  toggles :: Array (Record classes -> Prop ())

instance Toggles RL.Nil classes where
  toggles = []

instance (IsSymbol label, ToBinding value Boolean, Toggles rest classes) => Toggles (RL.Cons label value rest) classes where
  toggles =
    let
      name = reflectSymbol (Proxy @label)
      convert = bindingProp "class" (Object.singleton name)
    in
      Array.cons (\record -> convert (unsafeGet name record :: value)) (toggles @rest)

-- | `style`: CSS text (or an accessor), or a record of CSS properties.
class StyleValue :: Type -> Constraint
class StyleValue value where
  styleValue :: value -> Prop ()

instance (RL.RowToList properties list, StyleEntries list properties) => StyleValue (Record properties) where
  styleValue = let converters = styleEntries @list in \record -> propsProp (map (_ $ record) converters)
else instance ToBinding value String => StyleValue value where
  styleValue = bindingProp "style" identity

class StyleEntries :: RL.RowList Type -> Row Type -> Constraint
class StyleEntries list properties where
  styleEntries :: Array (Record properties -> Prop ())

instance StyleEntries RL.Nil properties where
  styleEntries = []

instance (IsSymbol label, ToBinding value String, StyleEntries rest properties) => StyleEntries (RL.Cons label value rest) properties where
  styleEntries =
    let
      name = reflectSymbol (Proxy @label)
      convert = bindingProp "style" (Object.singleton name)
    in
      Array.cons (\record -> convert (unsafeGet name record :: value)) (styleEntries @rest)

class StartsWith :: Symbol -> Symbol -> Boolean -> Constraint
class StartsWith prefix symbol result | prefix symbol -> result

instance StartsWith "" symbol True
else instance StartsWith prefix "" False
else instance
  ( Symbol.Cons prefixHead prefixTail prefix
  , Symbol.Cons symbolHead symbolTail symbol
  , StartsWithChar prefixHead prefixTail symbolHead symbolTail result
  ) =>
  StartsWith prefix symbol result

class StartsWithChar :: Symbol -> Symbol -> Symbol -> Symbol -> Boolean -> Constraint
class StartsWithChar prefixHead prefixTail symbolHead symbolTail result | prefixHead prefixTail symbolHead symbolTail -> result

instance StartsWith prefixTail symbolTail result => StartsWithChar char prefixTail char symbolTail result
else instance StartsWithChar prefixHead prefixTail symbolHead symbolTail False
