-- | Renders the site's pages to HTML, for `site/build.mjs`.
module Site.Prerender
  ( render
  ) where

import Prelude

import Data.Either (Either, either)
import Effect (Effect)
import Effect.Exception (Error, throwException)
import Site.Demo (counter)
import Site.Pages (Snippets, docs, landing)
import Solid.Component as Component
import Solid.Control (noHydration)
import Solid.Web.SSR as SSR

render :: Snippets -> Effect { landing :: String, docs :: String, hydration :: String }
render snippets = do
  demo <- SSR.renderToString (Component.element counter {}) >>= orThrow
  landingHtml <- SSR.renderToString (noHydration (landing snippets demo)) >>= orThrow
  docsHtml <- SSR.renderToString (noHydration (docs snippets)) >>= orThrow
  hydration <- SSR.hydrationScript >>= orThrow
  pure { landing: landingHtml, docs: docsHtml, hydration }

orThrow :: forall a. Either Error a -> Effect a
orThrow = either throwException pure
