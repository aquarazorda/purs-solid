module Test.Start.Entry
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.JSX as JSX
import Solid.Start.App as App
import Solid.Start.Entry.Client as Client
import Solid.Start.Entry.Server as Server
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Web as Web
import Test.Assert (assertEqual, expectRight)

foreign import serverMountStub :: Web.Mountable

run :: Effect Unit
run = do
  let app = App.createApp (pure JSX.empty)

  mountFailure <- Client.bootstrapInBody Client.RenderMode app
  case mountFailure of
    Left clientError ->
      assertEqual
        "bootstrapInBody returns typed mount error without DOM"
        (Client.MountFailure (Web.MissingMount "document.body is unavailable in current runtime"))
        clientError
    Right _ ->
      throw "bootstrapInBody should fail without DOM"

  renderFailure <- Client.bootstrapAt Client.RenderMode app serverMountStub
  case renderFailure of
    Left clientError ->
      assertEqual
        "bootstrapAt render maps web error to ClientEntryError"
        ( Client.RenderFailure
            ( Web.ClientOnlyApi
                "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
            )
        )
        clientError
    Right _ ->
      throw "bootstrapAt render should fail on server runtime"

  hydrateFailure <- Client.bootstrapAt Client.HydrateMode app serverMountStub
  case hydrateFailure of
    Left clientError ->
      assertEqual
        "bootstrapAt hydrate maps web error to ClientEntryError"
        ( Client.HydrateFailure
            ( Web.ClientOnlyApi
                "Client-only API called on the server side. Run client-only code in onMount, or conditionally run client-only component with <Show>."
            )
        )
        clientError
    Right _ ->
      throw "bootstrapAt hydrate should fail on server runtime"

  let request = Server.mkRequest Request.GET "/notes"
  assertEqual "request method accessor" Request.GET (Server.requestMethod request)
  assertEqual "request path accessor" "/notes" (Server.requestPath request)

  response <- expectRight
    "server handler returns Right response"
    =<< Server.handleRequest
      (\incoming -> pure (Right (Server.okText ("ok:" <> Server.requestPath incoming))))
      request

  assertEqual "okText status" 200 (Server.responseStatus response)
  assertEqual "okText body" (Response.TextBody "ok:/notes") (Server.responseBody response)

  let notFound = Server.notFoundText "missing"
  assertEqual "notFoundText status" 404 (Server.responseStatus notFound)
  assertEqual "notFoundText body" (Response.TextBody "missing") (Server.responseBody notFound)
