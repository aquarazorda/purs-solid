module Test.Core.Component
  ( spec
  ) where

import Prelude

import Data.String as String
import Effect.Class (liftEffect)
import Solid.Component as Component
import Solid.JSX as JSX
import Solid.Root (createRoot)
import Test.Solid (jsxValue, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

greeting :: Component.Component { name :: String }
greeting = Component.component \props -> pure (JSX.text ("hello " <> props.name))

spec :: Spec Unit
spec = describe "Solid.Component" do
  solidIt "element renders a component with its props" do
    rendered <- liftEffect do
      view <- createRoot \_ -> pure (Component.element greeting { name: "ada" })
      jsxValue view
    rendered `shouldEqual` "hello ada"

  solidIt "children resolves once into an accessor" do
    rendered <- liftEffect do
      resolved <- createRoot \_ -> Component.children (pure (JSX.text "child"))
      jsxValue resolved
    rendered `shouldEqual` "child"

  solidIt "createUniqueId returns distinct ids" do
    ids <- liftEffect $ createRoot \_ -> do
      a <- Component.createUniqueId
      b <- Component.createUniqueId
      pure { a, b }
    (ids.a /= ids.b && String.length ids.a > 0) `shouldEqual` true
