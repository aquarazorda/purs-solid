module Solid.Start.Entry.Server
  ( ServerRequest
  , ServerResponse
  , ServerHandler
  , renderAppHtml
  , renderDocumentHtmlWithMeta
  , renderDocumentHtmlWithAssets
  , renderDocumentHtml
  , renderDocumentResponseWithAssets
  , renderDocumentResponseWithMeta
  , renderDocumentResponse
  , mkRequest
  , requestPath
  , requestMethod
  , responseStatus
  , responseHeaders
  , responseBody
  , okText
  , notFoundText
  , handleRequest
  ) where

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.Tuple.Nested (type (/\))
import Effect (Effect)
import Prelude

import Solid.Start.App (App, StartConfig, defaultStartConfig, runApp)
import Solid.Start.Error (StartError(..))
import Solid.Start.Meta as Meta
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Start.StaticAssets as StaticAssets
import Solid.Web.SSR as SSR

type ServerRequest = Request.Request

type ServerResponse = Response.Response

type ServerHandler = ServerRequest -> Effect (Either StartError ServerResponse)

renderAppHtml :: App -> Effect (Either StartError String)
renderAppHtml app = do
  result <- SSR.renderToString (runApp app)
  pure case result of
    Left (SSR.RuntimeError message) -> Left (EnvironmentError message)
    Right html -> Right html

renderDocumentHtmlWithMeta :: Meta.MetaDoc -> App -> Effect (Either StartError String)
renderDocumentHtmlWithMeta metaDoc =
  renderDocumentHtmlWithAssets defaultStartConfig metaDoc []

renderDocumentHtmlWithAssets
  :: StartConfig
  -> Meta.MetaDoc
  -> Array String
  -> App
  -> Effect (Either StartError String)
renderDocumentHtmlWithAssets config metaDoc scriptAssets app = do
  bodyResult <- renderAppHtml app
  hydrationResult <- SSR.hydrationScript
  pure case bodyResult, hydrationResult of
    Left startError, _ -> Left startError
    _, Left (SSR.RuntimeError message) -> Left (HydrationError message)
    Right bodyHtml, Right hydrationTag ->
      Right
        ( "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\" />"
            <> Meta.renderHeadHtml metaDoc
            <> hydrationTag
            <> String.joinWith "" (map (renderAssetScriptTag config) scriptAssets)
            <> "</head><body><div id=\"app\">"
            <> bodyHtml
            <> "</div></body></html>"
        )

renderDocumentHtml :: App -> Effect (Either StartError String)
renderDocumentHtml =
  renderDocumentHtmlWithMeta Meta.empty

renderDocumentResponseWithMeta
  :: Int
  -> Meta.MetaDoc
  -> App
  -> Effect (Either StartError ServerResponse)
renderDocumentResponseWithMeta statusCode metaDoc app = do
  htmlResult <- renderDocumentHtmlWithMeta metaDoc app
  pure case htmlResult of
    Left startError -> Left startError
    Right html -> Right (Response.html statusCode html)

renderDocumentResponseWithAssets
  :: Int
  -> StartConfig
  -> Meta.MetaDoc
  -> Array String
  -> App
  -> Effect (Either StartError ServerResponse)
renderDocumentResponseWithAssets statusCode config metaDoc scriptAssets app = do
  htmlResult <- renderDocumentHtmlWithAssets config metaDoc scriptAssets app
  pure case htmlResult of
    Left startError -> Left startError
    Right html -> Right (Response.html statusCode html)

renderDocumentResponse :: Int -> App -> Effect (Either StartError ServerResponse)
renderDocumentResponse statusCode =
  renderDocumentResponseWithMeta statusCode Meta.empty

mkRequest :: Request.Method -> String -> ServerRequest
mkRequest method path =
  Request.mkRequest method path [] [] Nothing

requestPath :: ServerRequest -> String
requestPath = Request.path

requestMethod :: ServerRequest -> Request.Method
requestMethod = Request.method

responseStatus :: ServerResponse -> Int
responseStatus = Response.status

responseHeaders :: ServerResponse -> Array (String /\ String)
responseHeaders = Response.headers

responseBody :: ServerResponse -> Response.ResponseBody
responseBody = Response.body

okText :: String -> ServerResponse
okText = Response.text 200

notFoundText :: String -> ServerResponse
notFoundText = Response.text 404

handleRequest :: ServerHandler -> ServerRequest -> Effect (Either StartError ServerResponse)
handleRequest handler request =
  handler request

renderAssetScriptTag :: StartConfig -> String -> String
renderAssetScriptTag config assetPath =
  "<script defer src=\"" <> StaticAssets.resolveAssetUrl config assetPath <> "\"></script>"
