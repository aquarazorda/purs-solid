-- | Hydrates the island on the current page: the landing page's demo or the
-- | guide's contents.
module Site.Client
  ( main
  ) where

import Prelude

import Data.Foldable (for_)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Site.Demo (counter)
import Site.Toc (toc)
import Solid.Component as Component
import Solid.Web (hydrateAt)
import Web.DOM.NonElementParentNode (getElementById)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window (document)

main :: Effect Unit
main = do
  doc <- HTMLDocument.toNonElementParentNode <$> (document =<< window)
  for_ [ "demo" /\ Component.element counter {}, "toc" /\ Component.element toc {} ] \(id /\ view) ->
    getElementById id doc >>= flip for_ \_ -> hydrateAt id view
