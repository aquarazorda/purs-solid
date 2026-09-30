module Test.Core.Context
  ( spec
  ) where

import Prelude

import Effect.Class (liftEffect)
import Solid.Context (createContext, provide, useContext)
import Solid.JSX as JSX
import Solid.Root (createRoot)
import Test.Solid (jsxValue, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Solid.Context" do
  solidIt "useContext returns the default outside any provider" do
    value <- liftEffect do
      context <- createContext "default"
      createRoot \_ -> useContext context
    value `shouldEqual` "default"

  solidIt "provide makes the value visible to its children" do
    rendered <- liftEffect do
      context <- createContext "default"
      view <- createRoot \_ -> pure $
        provide context "provided" (JSX.text <$> useContext context)
      jsxValue view
    rendered `shouldEqual` "provided"

  solidIt "the nearest provider wins" do
    rendered <- liftEffect do
      context <- createContext 0
      view <- createRoot \_ -> pure $
        provide context 1 $ pure $
          provide context 2 (JSX.text <<< show <$> useContext context)
      jsxValue view
    rendered `shouldEqual` "2"
