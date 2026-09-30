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
import Effect.Ref as Ref
import Examples.Hydration.App (app)
import Solid.Web.SSR as SSR

-- | The page and how often it fetched the greeting. The client script isn't
-- | `async`: it must run after the serialized data scripts.
renderPage :: Effect (Promise { html :: String, fetches :: Int })
renderPage = fromAff do
  fetches <- liftEffect (Ref.new 0)
  body <- SSR.renderToStringAsync (app { onFetch: Ref.modify_ (_ + 1) fetches }) >>= orFail
  script <- liftEffect SSR.hydrationScript >>= orFail
  count <- liftEffect (Ref.read fetches)
  pure $ { fetches: count, html: _ } $ "<!doctype html><html><head><meta charset=\"utf-8\"><title>hydration</title>" <> script
    <> "</head><body><div id=\"app\">"
    <> body
    <> "</div>"
    <> "<script>for (const el of document.querySelectorAll('#app *')) el.__ssr = true;</script>"
    <> "<script src=\"/client.js\"></script></body></html>"

orFail :: forall a. Either Error a -> Aff a
orFail = either throwError pure
