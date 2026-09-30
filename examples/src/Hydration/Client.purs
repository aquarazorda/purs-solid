module Examples.Hydration.Client
  ( main
  ) where

import Prelude

import Data.Foldable (for_)
import Effect (Effect)
import Examples.Hydration.App (app)
import Solid.Web (hydrateAt, requireElementById)
import Web.DOM.Element (setAttribute)

-- | Marks `#app` for the hydration test: `data-fetched` if the client fetched
-- | the greeting itself, `data-hydrated` once hydrated.
main :: Effect Unit
main = do
  hydrateAt "app" (app { onFetch: mark "data-fetched" })
  mark "data-hydrated"
  where
  mark name = requireElementById "app" >>= flip for_ (setAttribute name "")
