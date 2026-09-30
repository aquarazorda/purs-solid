-- | Solid components written in JavaScript, declared with their props as a row:
-- |
-- | ```js
-- | // Picker.js
-- | export { DatePicker as datePicker } from "some-solid-library";
-- | ```
-- | ```purescript
-- | foreign import datePicker
-- |   :: JsComponent
-- |        ( value :: Accessor String
-- |        , onChange :: String -> Effect Unit
-- |        , placeholder :: Maybe String
-- |        , children :: JSX
-- |        )
-- |
-- | picker = jsElement datePicker { value: date, onChange: set setDate, children: text "Pick" }
-- | ```
-- |
-- | Fields are converted (top level only):
-- | - `Accessor a`, `JSX`, `Array JSX`: getters, read reactively
-- | - `a -> Effect b`: one-argument callback; `a -> JSX`: render callback
-- | - `Maybe a`: value or `undefined` (the component's default applies)
-- | Any prop can be left out, as if it were `Nothing`.
-- | - anything else as is (use `EffectFn2`.. for more arguments, `Nullable` for `null`)
module Solid.Component.JS
  ( JsComponent
  , jsElement
  , JsValue
  , class ToJsValue
  , toJsValue
  , class ToJsProp
  , toJsProp
  , class ToJsProps
  , jsPropEntries
  ) where

import Prelude

import Data.Function.Uncurried (runFn2)
import Data.Maybe (Maybe, maybe)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Effect (Effect)
import Effect.Uncurried (mkEffectFn1)
import Prim.Row as Row
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Prim.TypeError (class Fail, Text)
import Record.Unsafe (unsafeGet)
import Solid.Internal.View (JSX, JsPropEntry, fragment, jsPropsComponentElement, realize)
import Solid.Signal (Accessor)
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)

foreign import data JsComponent :: Row Type -> Type

jsElement
  :: forall props given missing rl
   . Row.Union given missing props
  => RowToList given rl
  => ToJsProps rl given
  => JsComponent props
  -> { | given }
  -> JSX
jsElement component props = runFn2 jsPropsComponentElement component (jsPropEntries (Proxy :: Proxy rl) props)

foreign import data JsValue :: Type

foreign import undefinedValue :: JsValue

class ToJsValue a where
  toJsValue :: a -> JsValue

instance ToJsValue a => ToJsValue (Maybe a) where
  toJsValue = maybe undefinedValue toJsValue
else instance Fail (Text "JSX can only be passed as a prop of its own (a field of type JSX, Array JSX or Accessor JSX).") => ToJsValue JSX where
  toJsValue = unsafeCoerce
else instance ToJsValue (a -> JSX) where
  toJsValue render = unsafeCoerce \a -> realize (render a)
else instance ToJsValue (a -> Effect b) where
  toJsValue callback = unsafeCoerce (mkEffectFn1 callback)
else instance ToJsValue a where
  toJsValue = unsafeCoerce

class ToJsProp a where
  toJsProp :: String -> a -> JsPropEntry

instance ToJsProp JSX where
  toJsProp key content = getter key (realize <$> pure content)
else instance ToJsProp (Array JSX) where
  toJsProp key content = getter key (realize <$> pure (fragment content))
else instance ToJsProp (Accessor JSX) where
  toJsProp key content = getter key (realize <$> content)
else instance ToJsValue a => ToJsProp (Accessor a) where
  toJsProp key read = getter key (toJsValue <$> read)
else instance ToJsValue a => ToJsProp a where
  toJsProp key value = unsafeCoerce { key, value: toJsValue value }

getter :: forall a. String -> Accessor a -> JsPropEntry
getter key read = unsafeCoerce { key, get: read }

class ToJsProps :: RowList Type -> Row Type -> Constraint
class ToJsProps rl props where
  jsPropEntries :: Proxy rl -> { | props } -> Array JsPropEntry

instance ToJsProps RL.Nil props where
  jsPropEntries _ _ = []

instance
  ( IsSymbol label
  , Row.Cons label a rest props
  , ToJsProp a
  , ToJsProps tail props
  ) =>
  ToJsProps (RL.Cons label a tail) props where
  jsPropEntries _ props =
    [ toJsProp key (unsafeGet key props :: a) ] <> jsPropEntries (Proxy :: Proxy tail) props
    where
    key = reflectSymbol (Proxy :: Proxy label)
