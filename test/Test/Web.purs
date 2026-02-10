module Test.Web
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (isNothing)
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Web as Web
import Test.Assert (assertEqual)

foreign import serverMountStub :: Web.Mountable

run :: Effect Unit
run = do
  assertEqual "Solid.Web reports server runtime in node tests" true Web.isServer

  webBody <- Web.documentBody
  assertEqual "documentBody is unavailable without browser DOM" true (isNothing webBody)

  webMissingMount <- Web.mountById "app"
  assertEqual "mountById returns Nothing without browser DOM" true (isNothing webMissingMount)

  requiredBody <- Web.requireBody
  case requiredBody of
    Left (Web.MissingMount message) ->
      assertEqual
        "requireBody returns functional MissingMount error"
        "document.body is unavailable in current runtime"
        message
    _ ->
      throw "requireBody should return MissingMount without browser DOM"

  requiredAppMount <- Web.requireMountById "app"
  case requiredAppMount of
    Left (Web.MissingMount message) ->
      assertEqual
        "requireMountById returns functional MissingMount error"
        "No mount element found for id: app"
        message
    _ ->
      throw "requireMountById should return MissingMount when element is absent"

  renderAttempt <- Web.render (pure unit) serverMountStub
  case renderAttempt of
    Left (Web.ClientOnlyApi message) ->
      assertEqual
        "render returns client-only error value on server runtime"
        "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
        message
    Left other ->
      throw ("render should classify as ClientOnlyApi, got " <> show other)
    Right _ ->
      throw "render should return Left on server runtime"

  hydrateAttempt <- Web.hydrate (pure unit) serverMountStub
  case hydrateAttempt of
    Left (Web.ClientOnlyApi message) ->
      assertEqual
        "hydrate returns client-only error value on server runtime"
        "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
        message
    Left other ->
      throw ("hydrate should classify as ClientOnlyApi, got " <> show other)
    Right _ ->
      throw "hydrate should return Left on server runtime"
