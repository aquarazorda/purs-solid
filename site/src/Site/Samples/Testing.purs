module Site.Samples.Testing where

import Prelude

import Data.Foldable (for_)
import Data.String (Pattern(..), contains)
import Effect.Class (liftEffect)
import Site.Demo (counter)
import Solid.Component as Component
import Solid.Testing (click, html, mount, query)
import Test.Spec (Spec, it)
import Test.Spec.Assertions (shouldSatisfy)

-- region testing
spec :: Spec Unit
spec = it "counts clicks" do
  mounted <- mount (Component.element counter {})
  button <- query "button" mounted
  for_ button (liftEffect <<< click)
  html mounted >>= (_ `shouldSatisfy` contains (Pattern "<span>1</span>"))
  liftEffect mounted.dispose
-- endregion
