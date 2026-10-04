module Site.Samples.Server where

import Prelude

import Data.Either (either)
import Effect (Effect)
import Effect.Aff (Aff, throwError)
import Effect.Class (liftEffect)
import Site.Samples.Router (app)
import Solid.Component as Component
import Solid.Web (hydrateAt)
import Solid.Web.SSR as SSR

-- region ssr
renderPage :: Aff String
renderPage = do
  body <- SSR.renderToStringAsync (Component.element app {}) >>= orThrow
  script <- liftEffect SSR.hydrationScript >>= orThrow
  pure $ "<!doctype html><html><head>" <> script <> "</head><body>"
    <> ("<div id=\"app\">" <> body <> "</div>")
    <> "<script src=\"/client.js\"></script></body></html>"

  where
  orThrow = either throwError pure

main :: Effect Unit
main = hydrateAt "app" (Component.element app {})
-- endregion
