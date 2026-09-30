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
    value <- liftEffect $ createRoot \_ -> useContext (createContext "test.outside" "default")
    value `shouldEqual` "default"

  solidIt "provide makes the value visible to its children" do
    rendered <- liftEffect do
      let context = createContext "test.provided" "default"
      view <- createRoot \_ -> pure $
        provide context "provided" (JSX.text <$> useContext context)
      jsxValue view
    rendered `shouldEqual` "provided"

  solidIt "the nearest provider wins" do
    rendered <- liftEffect do
      let context = createContext "test.nearest" 0
      view <- createRoot \_ -> pure
        $ provide context 1
        $ pure
        $
          provide context 2 (JSX.text <<< show <$> useContext context)
      jsxValue view
    rendered `shouldEqual` "2"

  solidIt "a context can hold unit" do
    value <- liftEffect $ createRoot \_ -> useContext (createContext "test.unit" unit)
    value `shouldEqual` unit

  solidIt "contexts with the same name are the same context" do
    rendered <- liftEffect do
      view <- createRoot \_ -> pure $
        provide (createContext "test.shared" "a") "b" (JSX.text <$> useContext (createContext "test.shared" "c"))
      jsxValue view
    rendered `shouldEqual` "b"
