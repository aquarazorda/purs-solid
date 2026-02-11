module Examples.SolidStart.Entry.ClientMain
  ( main
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Examples.SolidStart as Example
import Solid.Component as Component
import Solid.Start.App as StartApp
import Solid.Start.Entry.Client as ClientEntry

main :: Effect Unit
main = do
  let app = StartApp.createApp (pure (Component.element Example.app {}))
  hydrateResult <- ClientEntry.bootstrapInBody ClientEntry.HydrateMode app
  case hydrateResult of
    Right _dispose ->
      setBootstrapMode "hydrate"
    Left _hydrateError -> do
      setBootstrapMode "render-fallback"
      renderResult <- ClientEntry.bootstrapInBody ClientEntry.RenderMode app
      case renderResult of
        Right _dispose ->
          pure unit
        Left _renderError ->
          setBootstrapMode "failure"

foreign import setBootstrapMode :: String -> Effect Unit
