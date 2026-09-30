module Examples.Hydration.Client
  ( main
  ) where

import Prelude

import Effect (Effect)
import Examples.Hydration.App (app)
import Solid.Web (hydrateAt)

foreign import markHydrated :: Effect Unit

main :: Effect Unit
main = hydrateAt "app" app *> markHydrated
