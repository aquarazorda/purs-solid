module Examples.StartSSRSmoke.ClientMain
  ( main
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)

import Examples.StartSSRSmoke.App as SmokeApp
import Solid.Start.Entry.Client as ClientEntry

main :: Effect Unit
main = do
  hydrateResult <- ClientEntry.bootstrapAtId ClientEntry.HydrateMode "app" SmokeApp.app
  case hydrateResult of
    Right _dispose ->
      setBootstrapMode "hydrate"
    Left _hydrateError -> do
      setBootstrapMode "render-fallback"
      renderResult <- ClientEntry.bootstrapAtId ClientEntry.RenderMode "app" SmokeApp.app
      case renderResult of
        Right _dispose ->
          pure unit
        Left _renderError ->
          setBootstrapMode "failure"

foreign import setBootstrapMode :: String -> Effect Unit
