module Test.Core.Component
  ( spec
  ) where

import Prelude

import Data.String as String
import Effect.Class (liftEffect)
import Solid.Component as Component
import Solid.JSX as JSX
import Solid.Root (createRoot)
import Solid.DOM.HTML as H
import Test.Solid (html, jsxValue, mount, solidIt)
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

  solidIt "children resolves once and can be placed in the view" do
    let
      wrapper = Component.component \props -> do
        resolved <- Component.children (pure props.child)
        pure (H.section_ [ JSX.reactive resolved ])
    mounted <- mount (Component.element wrapper { child: JSX.text "child" })
    html mounted >>= shouldEqual "<section>child</section>"
    liftEffect mounted.dispose

  solidIt "createUniqueId returns distinct ids" do
    ids <- liftEffect $ createRoot \_ -> do
      a <- Component.createUniqueId
      b <- Component.createUniqueId
      pure { a, b }
    (ids.a /= ids.b && String.length ids.a > 0) `shouldEqual` true
