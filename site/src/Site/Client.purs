module Site.Client
  ( main
  ) where

import Prelude

import Effect (Effect)
import Site.Demo (counter)
import Solid.Component as Component
import Solid.Web (hydrateAt)

main :: Effect Unit
main = hydrateAt "demo" (Component.element counter {})
