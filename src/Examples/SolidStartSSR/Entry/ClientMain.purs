module Examples.SolidStartSSR.Entry.ClientMain
  ( main
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Effect.Class.Console (log)
import Examples.SolidStartSSR.App as Example
import Solid.Start.Entry.Client as ClientEntry

main :: Effect Unit
main = do
  hydrateResult <- ClientEntry.bootstrapAtId ClientEntry.HydrateMode "app" Example.app
  case hydrateResult of
    Right _dispose ->
      pure unit
    Left hydrateError -> do
      log ("Hydration failed, falling back to render: " <> show hydrateError)
      renderResult <- ClientEntry.bootstrapAtId ClientEntry.RenderMode "app" Example.app
      case renderResult of
        Right _dispose ->
          pure unit
        Left renderError ->
          log ("Render fallback failed: " <> show renderError)
