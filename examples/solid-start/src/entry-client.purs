module Examples.SolidStart.Entry.Client
  ( main
  ) where

import Prelude

import Effect (Effect)
import Effect.Class.Console (log)
import Examples.SolidStart.App as ExampleApp
import Solid.Start.Entry.Client as Client

main :: Effect Unit
main = do
  hydrationAttempt <- Client.bootstrapInBody Client.HydrateMode ExampleApp.app
  case hydrationAttempt of
    Left hydrationError -> do
      log ("Hydrate bootstrap failed; falling back to render mode: " <> show hydrationError)
      renderAttempt <- Client.bootstrapInBody Client.RenderMode ExampleApp.app
      case renderAttempt of
        Left renderError ->
          log ("Render fallback failed: " <> show renderError)
        Right _dispose ->
          pure unit
    Right _dispose ->
      pure unit
