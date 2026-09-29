module Solid.DOM.Typed
  ( Prop
  , GlobalTag
  , AnchorTag
  , ButtonTag
  , InputTag
  , FormTag
  , DivTag
  , SpanTag
  , UlTag
  , LiTag
  , customProp
  , idProp
  , className
  , title
  , href
  , target
  , rel
  , type_
  , value
  , checked
  , placeholder
  , autofocus
  , onClick
  , onInput
  , onChange
  , onKeyDown
  , render
  , render_
  ) where

import Solid.DOM.Events (EventHandler)
import Solid.JSX (JSX)

foreign import data Prop :: Type -> Type

foreign import data GlobalTag :: Type

foreign import data AnchorTag :: Type

foreign import data ButtonTag :: Type

foreign import data InputTag :: Type

foreign import data FormTag :: Type

foreign import data DivTag :: Type

foreign import data SpanTag :: Type

foreign import data UlTag :: Type

foreign import data LiTag :: Type

foreign import customProp :: forall tag a. String -> a -> Prop tag

idProp :: forall tag. String -> Prop tag
idProp = customProp "id"

className :: forall tag. String -> Prop tag
className = customProp "className"

title :: forall tag. String -> Prop tag
title = customProp "title"

href :: String -> Prop AnchorTag
href = customProp "href"

target :: String -> Prop AnchorTag
target = customProp "target"

rel :: String -> Prop AnchorTag
rel = customProp "rel"

type_ :: String -> Prop InputTag
type_ = customProp "type"

value :: String -> Prop InputTag
value = customProp "value"

checked :: Boolean -> Prop InputTag
checked = customProp "checked"

placeholder :: String -> Prop InputTag
placeholder = customProp "placeholder"

autofocus :: Boolean -> Prop InputTag
autofocus = customProp "autofocus"

onClick :: forall tag. EventHandler -> Prop tag
onClick = customProp "onClick"

onInput :: forall tag. EventHandler -> Prop tag
onInput = customProp "onInput"

onChange :: forall tag. EventHandler -> Prop tag
onChange = customProp "onChange"

onKeyDown :: forall tag. EventHandler -> Prop tag
onKeyDown = customProp "onKeyDown"

foreign import render
  :: forall tag
   . String
  -> Array (Prop tag)
  -> Array JSX
  -> JSX

foreign import render_ :: String -> Array JSX -> JSX
