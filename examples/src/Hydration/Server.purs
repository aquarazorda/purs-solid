module Examples.Hydration.Server
  ( renderPage
  ) where

import Prelude

import Control.Promise (Promise, fromAff)
import Data.Either (Either, either)
import Effect (Effect)
import Effect.Aff (Aff, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (Error)
import Examples.Hydration.App (app)
import Solid.Web.SSR as SSR

-- | The client script isn't `async`: it must run after the serialized data scripts.
renderPage :: Effect (Promise String)
renderPage = fromAff do
  body <- SSR.renderToStringAsync app >>= orFail
  script <- liftEffect SSR.hydrationScript >>= orFail
  pure $ "<!doctype html><html><head><meta charset=\"utf-8\"><title>hydration</title>" <> script
    <> "</head><body><div id=\"app\">"
    <> body
    <> "</div>"
    <> "<script>for (const el of document.querySelectorAll('#app *')) el.__ssr = true;</script>"
    <> "<script src=\"/client.js\"></script></body></html>"

orFail :: forall a. Either Error a -> Aff a
orFail = either throwError pure
