-- | The `aria-*` attributes elements accept, typed by the WAI-ARIA 1.2 spec.
-- | Import qualified: `"aria-checked": Aria.Mixed`.
module Solid.DOM.Aria
  ( Aria
  , Tristate(..)
  , Autocomplete(..)
  , Current(..)
  , HasPopup(..)
  , Invalid(..)
  , Live(..)
  , Orientation(..)
  , Sort(..)
  , Relevant(..)
  , class AriaValue
  , ariaValue
  ) where

import Prelude

import Solid.DOM.AttrValue (AttrRep, stringAttr, toAttrValue)

type Aria =
  ( "aria-activedescendant" :: String
  , "aria-atomic" :: Boolean
  , "aria-autocomplete" :: Autocomplete
  , "aria-busy" :: Boolean
  , "aria-checked" :: Tristate
  , "aria-colcount" :: Int
  , "aria-colindex" :: Int
  , "aria-colspan" :: Int
  , "aria-controls" :: String
  , "aria-current" :: Current
  , "aria-describedby" :: String
  , "aria-description" :: String
  , "aria-details" :: String
  , "aria-disabled" :: Boolean
  , "aria-errormessage" :: String
  , "aria-expanded" :: Boolean
  , "aria-flowto" :: String
  , "aria-haspopup" :: HasPopup
  , "aria-hidden" :: Boolean
  , "aria-invalid" :: Invalid
  , "aria-keyshortcuts" :: String
  , "aria-label" :: String
  , "aria-labelledby" :: String
  , "aria-level" :: Int
  , "aria-live" :: Live
  , "aria-modal" :: Boolean
  , "aria-multiline" :: Boolean
  , "aria-multiselectable" :: Boolean
  , "aria-orientation" :: Orientation
  , "aria-owns" :: String
  , "aria-placeholder" :: String
  , "aria-posinset" :: Int
  , "aria-pressed" :: Tristate
  , "aria-readonly" :: Boolean
  , "aria-relevant" :: Relevant
  , "aria-required" :: Boolean
  , "aria-roledescription" :: String
  , "aria-rowcount" :: Int
  , "aria-rowindex" :: Int
  , "aria-rowspan" :: Int
  , "aria-selected" :: Boolean
  , "aria-setsize" :: Int
  , "aria-sort" :: Sort
  , "aria-valuemax" :: Number
  , "aria-valuemin" :: Number
  , "aria-valuenow" :: Number
  , "aria-valuetext" :: String
  )

-- | `aria-checked`, `aria-pressed`.
data Tristate = True | False | Mixed

data Autocomplete = Inline | List | Both | NoAutocomplete

-- | `Current` is `"true"`: the current item of a set with no more specific kind.
data Current = Page | Step | Location | Date | Time | Current | NotCurrent

-- | `"true"` means a menu, so it's `Menu`.
data HasPopup = Menu | Listbox | Tree | Grid | Dialog | NoPopup

data Invalid = Invalid | Grammar | Spelling | Valid

data Live = Off | Polite | Assertive

data Orientation = Horizontal | Vertical

data Sort = Ascending | Descending | Other | Unsorted

-- | The changes `aria-relevant` announces: each combination once, with
-- | `All` for all three.
data Relevant = Additions | Removals | Text | AdditionsRemovals | AdditionsText | RemovalsText | All

derive instance Eq Tristate
derive instance Eq Autocomplete
derive instance Eq Current
derive instance Eq HasPopup
derive instance Eq Invalid
derive instance Eq Live
derive instance Eq Orientation
derive instance Eq Sort
derive instance Eq Relevant

-- | How a value is written to its attribute. ARIA booleans are the strings
-- | `"true"` / `"false"`, not present / absent.
class AriaValue :: Type -> Constraint
class AriaValue a where
  ariaValue :: a -> AttrRep

instance AriaValue Boolean where
  ariaValue value = stringAttr (if value then "true" else "false")

instance AriaValue Tristate where
  ariaValue = stringAttr <<< case _ of
    True -> "true"
    False -> "false"
    Mixed -> "mixed"

instance AriaValue Autocomplete where
  ariaValue = stringAttr <<< case _ of
    Inline -> "inline"
    List -> "list"
    Both -> "both"
    NoAutocomplete -> "none"

instance AriaValue Current where
  ariaValue = stringAttr <<< case _ of
    Page -> "page"
    Step -> "step"
    Location -> "location"
    Date -> "date"
    Time -> "time"
    Current -> "true"
    NotCurrent -> "false"

instance AriaValue HasPopup where
  ariaValue = stringAttr <<< case _ of
    Menu -> "menu"
    Listbox -> "listbox"
    Tree -> "tree"
    Grid -> "grid"
    Dialog -> "dialog"
    NoPopup -> "false"

instance AriaValue Invalid where
  ariaValue = stringAttr <<< case _ of
    Invalid -> "true"
    Grammar -> "grammar"
    Spelling -> "spelling"
    Valid -> "false"

instance AriaValue Live where
  ariaValue = stringAttr <<< case _ of
    Off -> "off"
    Polite -> "polite"
    Assertive -> "assertive"

instance AriaValue Orientation where
  ariaValue = stringAttr <<< case _ of
    Horizontal -> "horizontal"
    Vertical -> "vertical"

instance AriaValue Sort where
  ariaValue = stringAttr <<< case _ of
    Ascending -> "ascending"
    Descending -> "descending"
    Other -> "other"
    Unsorted -> "none"

instance AriaValue Relevant where
  ariaValue = stringAttr <<< case _ of
    Additions -> "additions"
    Removals -> "removals"
    Text -> "text"
    AdditionsRemovals -> "additions removals"
    AdditionsText -> "additions text"
    RemovalsText -> "removals text"
    All -> "all"

instance AriaValue String where
  ariaValue = toAttrValue

instance AriaValue Int where
  ariaValue = toAttrValue

instance AriaValue Number where
  ariaValue = toAttrValue
