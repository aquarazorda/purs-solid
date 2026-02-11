module Test.Start.Entry
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.String.CodeUnits as String
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
  let app = App.createApp (pure (JSX.text "entry-ssr"))

  appHtml <- expectRight
    "renderAppHtml renders app through SSR"
    =<< Server.renderAppHtml app
  assertEqual "renderAppHtml returns non-empty output" true (String.length appHtml > 0)

  documentHtml <- expectRight
    "renderDocumentHtml renders full document"
    =<< Server.renderDocumentHtml app
  assertEqual "renderDocumentHtml starts with doctype" "<!doctype html>" (String.take 15 documentHtml)

  documentResponse <- expectRight
    "renderDocumentResponse wraps SSR document into HTML response"
    =<< Server.renderDocumentResponse 200 app
  assertEqual "renderDocumentResponse status" 200 (Server.responseStatus documentResponse)
  case Server.responseBody documentResponse of
    Response.HtmlBody html ->
      assertEqual "renderDocumentResponse includes app mount id" true (String.length html > String.length appHtml)
    other ->
      throw ("renderDocumentResponse should return HtmlBody, got " <> show other)

  mountFailure <- Client.bootstrapInBody Client.RenderMode app
  case mountFailure of
    Left clientError ->
      assertEqual
        "bootstrapInBody returns typed mount error without DOM"
        (Client.MountFailure (Web.MissingMount "document.body is unavailable in current runtime"))
        clientError
    Right _ ->
      throw "bootstrapInBody should fail without DOM"

  mountByIdFailure <- Client.bootstrapAtId Client.RenderMode "app" app
  case mountByIdFailure of
    Left clientError ->
      assertEqual
        "bootstrapAtId returns typed mount-id error without DOM"
        (Client.MountFailure (Web.MissingMount "No mount element found for id: app"))
        clientError
    Right _ ->
      throw "bootstrapAtId should fail without DOM"

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
