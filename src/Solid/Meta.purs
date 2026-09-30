-- | Document head tags. Render them anywhere; they're collected into `<head>`
-- | (on the server, into the head markup `Solid.Web.SSR` returns), and the
-- | last registered tag wins per identity. No provider is needed.
module Solid.Meta
  ( key
  , head
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
import Solid.Internal.View (class ToBinding, JSX, Prop, propsComponentElement, staticProp)
import Solid.JSX (text)

-- | Sets the tag's identity for deduplication, e.g. for several `og:image` metas.
key :: forall r. String -> Prop (key :: String | r)
key = staticProp "key"

-- | Same-identity tags inside a group coexist; a later group replaces an
-- | earlier one's set while it's rendered.
head :: Array JSX -> JSX
head children = runFn3 propsComponentElement headImpl ([] :: Array (Prop ())) children

title :: forall v. ToBinding v String => v -> JSX
title = titleWith []

titleWith :: forall v. ToBinding v String => Array (Prop (key :: String | I.HTMLtitle)) -> v -> JSX
titleWith props value = runFn3 propsComponentElement titleImpl props [ text value ]

meta :: Array (Prop (key :: String | I.HTMLmeta)) -> JSX
meta props = runFn3 propsComponentElement metaImpl props []

link :: Array (Prop (key :: String | I.HTMLlink)) -> JSX
link props = runFn3 propsComponentElement linkImpl props []

-- | `<link rel="stylesheet">`.
stylesheet :: Array (Prop (key :: String | I.HTMLlink)) -> JSX
stylesheet props = runFn3 propsComponentElement stylesheetImpl props []

style :: Array (Prop (key :: String | I.HTMLstyle)) -> String -> JSX
style props css = runFn3 propsComponentElement styleImpl props [ text css ]

-- | The content isn't escaped.
script :: Array (Prop (key :: String | I.HTMLscript)) -> String -> JSX
script props source = runFn3 propsComponentElement scriptImpl props [ text source ]

-- | Rendered with the document shell on the server; ignored on the client.
base :: Array (Prop I.HTMLbase) -> JSX
base props = runFn3 propsComponentElement baseImpl props []

foreign import data MetaComponent :: Type

foreign import headImpl :: MetaComponent
foreign import titleImpl :: MetaComponent
foreign import metaImpl :: MetaComponent
foreign import linkImpl :: MetaComponent
foreign import stylesheetImpl :: MetaComponent
foreign import styleImpl :: MetaComponent
foreign import scriptImpl :: MetaComponent
foreign import baseImpl :: MetaComponent
