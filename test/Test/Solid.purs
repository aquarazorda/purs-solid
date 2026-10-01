module Test.Solid
  ( solidIt
  , expectDiagnostic
  , jsxValue
  , mountFirstText
  , waitForHtml
  , module Exports
  ) where

import Prelude

import Control.Monad.Error.Class (throwError, try)
import Data.Array as Array
import Data.Either (either)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Effect.Ref as Ref
import Solid.JSX (JSX)
import Solid.Reactivity (flush)
import Solid.Testing (Mounted, collectDiagnostics, html, ignoreDiagnostic, mountUsing, settle)
import Solid.Web as Web
import Test.Spec.Assertions (shouldEqual)
import Web.DOM.Element as Element
import Web.DOM.Node (textContent)
import Solid.Testing (Mounted, click, html, inputText, mount, mountUsing, query, settle) as Exports
import Test.Spec (Spec, it)

-- | A spec that fails on any Solid diagnostic above `info`.
solidIt :: String -> Aff Unit -> Spec Unit
solidIt name body = it name do
  stop <- liftEffect collectDiagnostics
  outcome <- try (body *> settle)
  diagnostics <- liftEffect stop
  either throwError pure outcome
  let reported = Array.filter (\d -> d.severity /= "info") diagnostics
  unless (Array.null reported) do
    liftEffect $ throw $ "Solid reported diagnostics:\n" <> joinWith "\n" (reported <#> \d -> d.code <> ": " <> d.message)

expectDiagnostic :: String -> Aff Unit -> Aff Unit
expectDiagnostic code body = do
  stop <- liftEffect collectDiagnostics
  _ <- try (body *> settle)
  diagnostics <- liftEffect stop
  unless (Array.any (\d -> d.code == code) diagnostics) do
    liftEffect $ throw $ "Expected diagnostic " <> code <> ", got: " <> joinWith ", " (_.code <$> diagnostics)
  liftEffect (ignoreDiagnostic code)

foreign import jsxValue :: JSX -> Effect String

-- | Mounts `view` and also returns its text right after the first render,
-- | before async work (a lazy import, say) can finish, however fast it is.
mountFirstText :: JSX -> Aff { mounted :: Mounted, first :: String }
mountFirstText view = do
  first <- liftEffect (Ref.new "")
  mounted <- mountUsing
    (\jsx element -> Web.render jsx element <* (flush *> textContent (Element.toNode element) >>= flip Ref.write first))
    view
  { mounted, first: _ } <$> liftEffect (Ref.read first)

-- | Waits until the container's HTML is `expected`, for work whose timing is
-- | outside the test's control (a real module import); fails after 2 seconds.
waitForHtml :: String -> Mounted -> Aff Unit
waitForHtml expected mounted = go 400
  where
  go tries = do
    current <- html mounted
    if current == expected || tries == 0 then current `shouldEqual` expected
    else delay (Milliseconds 5.0) *> go (tries - 1)
