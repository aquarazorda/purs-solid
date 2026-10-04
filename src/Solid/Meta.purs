-- | Document head tags. Render them anywhere; they're collected into `<head>`
-- | (on the server, into the head markup `Solid.Web.SSR` returns), and the
-- | last registered tag wins per identity. No provider is needed. Props are
-- | the element's, plus `key`: the tag's identity for deduplication, e.g. for
-- | several `og:image` metas.
module Solid.Meta
  ( head
  , title
  , titleWith
  , meta
  , link
  , stylesheet
  , style
  , script
  , base
  ) where

import Data.Function.Uncurried (runFn3)
import DOM.HTML.Indexed as I
import Solid.Internal.Props (class Props, applyProps, props)
import Solid.Internal.View (class ToBinding, JSX, Prop, propsComponentElement)
import Solid.JSX (text)

-- | Same-identity tags inside a group coexist; a later group replaces an
-- | earlier one's set while it's rendered.
head :: Array JSX -> JSX
head children = runFn3 propsComponentElement headImpl ([] :: Array (Prop ())) children

title :: forall v. ToBinding v String => v -> JSX
title = titleWith {}

titleWith :: forall v props. ToBinding v String => Props (key :: String | I.HTMLtitle) props => Record props -> v -> JSX
titleWith record value = tag @(key :: String | I.HTMLtitle) titleImpl record [ text value ]

meta :: forall props. Props (key :: String | I.HTMLmeta) props => Record props -> JSX
meta record = tag @(key :: String | I.HTMLmeta) metaImpl record []

link :: forall props. Props (key :: String | I.HTMLlink) props => Record props -> JSX
link record = tag @(key :: String | I.HTMLlink) linkImpl record []

-- | `<link rel="stylesheet">`.
stylesheet :: forall props. Props (key :: String | I.HTMLlink) props => Record props -> JSX
stylesheet record = tag @(key :: String | I.HTMLlink) stylesheetImpl record []

style :: forall props. Props (key :: String | I.HTMLstyle) props => Record props -> String -> JSX
style record css = tag @(key :: String | I.HTMLstyle) styleImpl record [ text css ]

-- | The content isn't escaped.
script :: forall props. Props (key :: String | I.HTMLscript) props => Record props -> String -> JSX
script record source = tag @(key :: String | I.HTMLscript) scriptImpl record [ text source ]

-- | Rendered with the document shell on the server; ignored on the client.
base :: forall props. Props I.HTMLbase props => Record props -> JSX
base record = tag @I.HTMLbase baseImpl record []

tag :: forall @row props. Props row props => MetaComponent -> Record props -> Array JSX -> JSX
tag component record = runFn3 propsComponentElement component (applyProps (props @row) record)

foreign import data MetaComponent :: Type

foreign import headImpl :: MetaComponent
foreign import titleImpl :: MetaComponent
foreign import metaImpl :: MetaComponent
foreign import linkImpl :: MetaComponent
foreign import stylesheetImpl :: MetaComponent
foreign import styleImpl :: MetaComponent
foreign import scriptImpl :: MetaComponent
foreign import baseImpl :: MetaComponent
