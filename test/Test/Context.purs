module Test.Context
  ( run
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.Context as Context
import Solid.Root (createRoot)
import Test.Assert (assertEqual)

run :: Effect Unit
run =
  createRoot \dispose -> do
    plainContext <- Context.createContext
    defaultContext <- Context.createContextWithDefault 7

    plainWithoutProvider <- Context.useContext plainContext
    assertEqual "context without provider returns Nothing" (Nothing :: Maybe Int) plainWithoutProvider

    defaultWithoutProvider <- Context.useContext defaultContext
    assertEqual "context default value is returned without provider" (Just 7) defaultWithoutProvider

    providedPlain <- Context.withContext plainContext 11 (Context.useContext plainContext)
    assertEqual "withContext provides value within current scope" (Just 11) providedPlain

    plainAfterProvide <- Context.useContext plainContext
    assertEqual "withContext restores previous scope after action" (Nothing :: Maybe Int) plainAfterProvide

    nestedValues <- Context.withContext plainContext 20 do
      outer <- Context.useContext plainContext
      inner <- Context.withContext plainContext 30 (Context.useContext plainContext)
      outerAfterInner <- Context.useContext plainContext
      pure
        { outer
        , inner
        , outerAfterInner
        }

    assertEqual "outer scope context value is visible" (Just 20) nestedValues.outer
    assertEqual "inner scope context overrides outer scope value" (Just 30) nestedValues.inner
    assertEqual "outer scope value is restored after inner override" (Just 20) nestedValues.outerAfterInner

    childScope <- Context.withContext plainContext 40 do
      createRoot \disposeChild -> do
        inherited <- Context.useContext plainContext
        pure
          { inherited
          , disposeChild
          }

    assertEqual "context value is inherited by nested ownership scope" (Just 40) childScope.inherited
    childScope.disposeChild

    nestedOwnership <- Context.withContext plainContext 50 do
      createRoot \disposeChild -> do
        childValue <- Context.useContext plainContext

        grandchildScope <- Context.withContext plainContext 60 do
          createRoot \disposeGrandchild -> do
            grandchildValue <- Context.useContext plainContext
            pure
              { grandchildValue
              , disposeGrandchild
              }

        pure
          { childValue
          , grandchildScope
          , disposeChild
          }

    assertEqual "nested ownership sees parent-provided value" (Just 50) nestedOwnership.childValue
    assertEqual "inner context override applies in deeper ownership scope" (Just 60) nestedOwnership.grandchildScope.grandchildValue

    nestedOwnership.grandchildScope.disposeGrandchild
    nestedOwnership.disposeChild

    overriddenDefault <- Context.withContext defaultContext 9 (Context.useContext defaultContext)
    assertEqual "withContext overrides default value in scope" (Just 9) overriddenDefault

    defaultAfterOverride <- Context.useContext defaultContext
    assertEqual "default value restored after scoped override" (Just 7) defaultAfterOverride

    dispose
