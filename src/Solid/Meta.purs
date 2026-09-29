-- | Document head tags (`@solidjs/meta` 1.0).
-- |
-- | Render these anywhere in the tree; they're collected into `<head>` (on the
-- | server, into the head markup `Solid.Web.SSR` returns). The last registered
-- | tag wins per identity. `key` sets that identity explicitly, e.g. to have
-- | several `og:image` metas. No provider is needed.
-- |
-- | Attributes are typed by `Solid.DOM.Props` like any element, and may be
-- | reactive: `Meta.title (("Inbox (" <> _) <<< (_ <> ")") <<< show <$> unread)`.
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

-- | The tag's identity for deduplication (the last registered tag with the
-- | same identity wins).
key :: forall r. String -> Prop (key :: String | r)
key = staticProp "key"

-- | Groups tags into one replacement set: same-identity tags inside a group
-- | coexist, and a later group replaces an earlier one's set while it's
-- | rendered.
head :: Array JSX -> JSX
head children = runFn3 propsComponentElement headImpl ([] :: Array (Prop ())) children

-- | The document title; may be reactive.
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

-- | An inline stylesheet.
style :: Array (Prop (key :: String | I.HTMLstyle)) -> String -> JSX
style props css = runFn3 propsComponentElement styleImpl props [ text css ]

-- | A script tag (e.g. analytics or JSON-LD). The content isn't escaped.
script :: Array (Prop (key :: String | I.HTMLscript)) -> String -> JSX
script props source = runFn3 propsComponentElement scriptImpl props [ text source ]

-- | `<base>`. Rendered with the document shell on the server; ignored on the
-- | client.
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
