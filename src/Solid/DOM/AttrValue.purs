-- | How attribute values are handed to the DOM. Instances cover primitives
-- | and the `dom-indexed` value types; add one for your own types to use them
-- | with the property helpers (e.g. a newtype over `String`).
module Solid.DOM.AttrValue
  ( class AttrValue
  , toAttrValue
  , AttrRep
  , stringAttr
  , booleanAttr
  , numberAttr
  ) where

import Prelude

import DOM.HTML.Indexed.AutocompleteType (AutocompleteType, renderAutocompleteType)
import DOM.HTML.Indexed.ButtonType (ButtonType, renderButtonType)
import DOM.HTML.Indexed.CrossOriginValue (CrossOriginValue, renderCrossOriginValue)
import DOM.HTML.Indexed.DirValue (DirValue, renderDirValue)
import DOM.HTML.Indexed.FormMethod (FormMethod, renderFormMethod)
import DOM.HTML.Indexed.InputAcceptType (InputAcceptType, renderInputAcceptType)
import DOM.HTML.Indexed.InputType (InputType, renderInputType)
import DOM.HTML.Indexed.KindValue (KindValue, renderKindValue)
import DOM.HTML.Indexed.MenuType (MenuType, renderMenuType)
import DOM.HTML.Indexed.MenuitemType (MenuitemType, renderMenuitemType)
import DOM.HTML.Indexed.OrderedListType (OrderedListType, renderOrderedListType)
import DOM.HTML.Indexed.PreloadValue (PreloadValue, renderPreloadValue)
import DOM.HTML.Indexed.ScopeValue (ScopeValue, renderScopeValue)
import DOM.HTML.Indexed.StepValue (StepValue, renderStepValue)
import DOM.HTML.Indexed.WrapValue (WrapValue, renderWrapValue)
import Data.MediaType (MediaType(..))
import Unsafe.Coerce (unsafeCoerce)

foreign import data AttrRep :: Type

stringAttr :: String -> AttrRep
stringAttr = unsafeCoerce

numberAttr :: Number -> AttrRep
numberAttr = unsafeCoerce

-- | `true` sets the attribute (empty value), `false` removes it.
booleanAttr :: Boolean -> AttrRep
booleanAttr = unsafeCoerce

class AttrValue a where
  toAttrValue :: a -> AttrRep

instance AttrValue String where
  toAttrValue = stringAttr

instance AttrValue Boolean where
  toAttrValue = booleanAttr

instance AttrValue Int where
  toAttrValue = unsafeCoerce

instance AttrValue Number where
  toAttrValue = numberAttr

instance AttrValue MediaType where
  toAttrValue (MediaType mediaType) = stringAttr mediaType

instance AttrValue AutocompleteType where
  toAttrValue = stringAttr <<< renderAutocompleteType

instance AttrValue ButtonType where
  toAttrValue = stringAttr <<< renderButtonType

instance AttrValue CrossOriginValue where
  toAttrValue = stringAttr <<< renderCrossOriginValue

instance AttrValue DirValue where
  toAttrValue = stringAttr <<< renderDirValue

instance AttrValue FormMethod where
  toAttrValue = stringAttr <<< renderFormMethod

instance AttrValue InputAcceptType where
  toAttrValue = stringAttr <<< renderInputAcceptType

instance AttrValue InputType where
  toAttrValue = stringAttr <<< renderInputType

instance AttrValue KindValue where
  toAttrValue = stringAttr <<< renderKindValue

instance AttrValue MenuType where
  toAttrValue = stringAttr <<< renderMenuType

instance AttrValue MenuitemType where
  toAttrValue = stringAttr <<< renderMenuitemType

instance AttrValue OrderedListType where
  toAttrValue = stringAttr <<< renderOrderedListType

instance AttrValue PreloadValue where
  toAttrValue = stringAttr <<< renderPreloadValue

instance AttrValue ScopeValue where
  toAttrValue = stringAttr <<< renderScopeValue

instance AttrValue StepValue where
  toAttrValue = stringAttr <<< renderStepValue

instance AttrValue WrapValue where
  toAttrValue = stringAttr <<< renderWrapValue
