module Examples.Hydration.Client
  ( main
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Effect.Class.Console (log)
import Examples.Hydration.App (app)
import Solid.Web (hydrate, requireElementById)

foreign import markHydrated :: Effect Unit

main :: Effect Unit
main = requireElementById "app" >>= case _ of
  Left webError -> log (show webError)
  Right mount -> hydrate app mount >>= case _ of
    Left webError -> log ("hydrate failed: " <> show webError)
    Right _ -> markHydrated
