module Test.Start.Entry
  ( run
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.String as String
import Data.String.CodeUnits as StringCodeUnits
import Data.String.Pattern (Pattern(..))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.JSX as JSX
import Solid.Start.App as App
import Solid.Start.Entry.Client as Client
import Solid.Start.Entry.Server as Server
import Solid.Start.Meta as Meta
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
  assertEqual "renderAppHtml returns non-empty output" true (StringCodeUnits.length appHtml > 0)

  documentHtml <- expectRight
    "renderDocumentHtml renders full document"
    =<< Server.renderDocumentHtml app
  assertEqual "renderDocumentHtml starts with doctype" "<!doctype html>" (StringCodeUnits.take 15 documentHtml)

  documentHtmlWithMeta <- expectRight
    "renderDocumentHtmlWithMeta includes rendered head tags"
    =<< Server.renderDocumentHtmlWithMeta
      ( Meta.fromTitle "entry-title"
          # Meta.withTag (Meta.MetaNameTag "description" "entry-description")
      )
      app
  assertEqual
    "renderDocumentHtmlWithMeta emits title"
    true
    (containsPattern "<title>entry-title</title>" documentHtmlWithMeta)
  assertEqual
    "renderDocumentHtmlWithMeta emits meta description"
    true
    (containsPattern "name=\"description\" content=\"entry-description\"" documentHtmlWithMeta)

  documentHtmlWithAssets <- expectRight
    "renderDocumentHtmlWithAssets includes script asset tags"
    =<< Server.renderDocumentHtmlWithAssets
      App.defaultStartConfig
      Meta.empty
      [ "/dist/entry-client.js", "/dist/chunk.js" ]
      app
  assertEqual
    "renderDocumentHtmlWithAssets emits first script"
    true
    (containsPattern "src=\"/dist/entry-client.js\"" documentHtmlWithAssets)
  assertEqual
    "renderDocumentHtmlWithAssets emits second script"
    true
    (containsPattern "src=\"/dist/chunk.js\"" documentHtmlWithAssets)

  documentResponse <- expectRight
    "renderDocumentResponse wraps SSR document into HTML response"
    =<< Server.renderDocumentResponse 200 app
  assertEqual "renderDocumentResponse status" 200 (Server.responseStatus documentResponse)
  case Server.responseBody documentResponse of
    Response.HtmlBody html ->
      assertEqual "renderDocumentResponse includes app mount id" true (StringCodeUnits.length html > StringCodeUnits.length appHtml)
    other ->
      throw ("renderDocumentResponse should return HtmlBody, got " <> show other)

  documentResponseWithMeta <- expectRight
    "renderDocumentResponseWithMeta wraps meta-aware SSR document into response"
    =<< Server.renderDocumentResponseWithMeta
      200
      (Meta.fromTitle "entry-response-title")
      app
  case Server.responseBody documentResponseWithMeta of
    Response.HtmlBody html ->
      assertEqual
        "renderDocumentResponseWithMeta includes title"
        true
        (containsPattern "<title>entry-response-title</title>" html)
    other ->
      throw ("renderDocumentResponseWithMeta should return HtmlBody, got " <> show other)

  documentResponseWithAssets <- expectRight
    "renderDocumentResponseWithAssets wraps script asset SSR document into response"
    =<< Server.renderDocumentResponseWithAssets
      200
      App.defaultStartConfig
      Meta.empty
      [ "/dist/assets.js" ]
      app
  case Server.responseBody documentResponseWithAssets of
    Response.HtmlBody html ->
      assertEqual
        "renderDocumentResponseWithAssets includes script asset"
        true
        (containsPattern "src=\"/dist/assets.js\"" html)
    other ->
      throw ("renderDocumentResponseWithAssets should return HtmlBody, got " <> show other)

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

containsPattern :: String -> String -> Boolean
containsPattern needle haystack =
  Array.length (String.split (Pattern needle) haystack) > 1
