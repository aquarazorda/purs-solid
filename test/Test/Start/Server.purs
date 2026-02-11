module Test.Start.Server
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Start.Server.API as API
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
  let request =
        Request.mkRequest
          Request.GET
          "/api/todos"
          [ "accept" /\ "application/json" ]
          [ "page" /\ "1" ]
          (Just "{}")

  assertEqual "request method accessor" Request.GET (Request.method request)
  assertEqual "request path accessor" "/api/todos" (Request.path request)
  assertEqual "request header lookup" (Just "application/json") (Request.lookupHeader "accept" request)
  assertEqual "request query lookup" (Just "1") (Request.lookupQuery "page" request)
  assertEqual "request body accessor" (Just "{}") (Request.body request)

  let requestWithCookie =
        Request.withHeader
          "cookie"
          "sid=abc123; csrf-token=csrf123"
          request
  assertEqual "request withHeader updates header value" (Just "sid=abc123; csrf-token=csrf123") (Request.lookupHeader "cookie" requestWithCookie)
  assertEqual "request lookupCookie reads cookie by name" (Just "abc123") (Request.lookupCookie "sid" requestWithCookie)
  assertEqual "request lookupCookie reads second cookie by name" (Just "csrf123") (Request.lookupCookie "csrf-token" requestWithCookie)

  let textResponse = Response.text 200 "ok"
  assertEqual "text response status" 200 (Response.status textResponse)
  assertEqual "text response body" (Response.TextBody "ok") (Response.body textResponse)

  let jsonResponse = Response.json 201 "{\"ok\":true}"
  assertEqual "json response status" 201 (Response.status jsonResponse)
  assertEqual "json response body" (Response.JsonBody "{\"ok\":true}") (Response.body jsonResponse)

  let htmlResponse = Response.html 200 "<h1>hello</h1>"
  assertEqual "html response body" (Response.HtmlBody "<h1>hello</h1>") (Response.body htmlResponse)

  let streamResponse = Response.streamText 200 [ "a", "b", "c" ]
  assertEqual "stream response status" 200 (Response.status streamResponse)
  assertEqual "stream response body" (Response.StreamBody [ "a", "b", "c" ]) (Response.body streamResponse)

  let redirectResponse = Response.redirect 302 "/login"
  assertEqual "redirect response status" 302 (Response.status redirectResponse)
  assertEqual "redirect response body is empty" Response.EmptyBody (Response.body redirectResponse)

  assertEqual "okText helper status" 200 (Response.status (Response.okText "ok"))
  assertEqual "createdJson helper status" 201 (Response.status (Response.createdJson "{}"))
  assertEqual "acceptedText helper status" 202 (Response.status (Response.acceptedText "queued"))
  assertEqual "noContent helper status" 204 (Response.status Response.noContent)
  assertEqual "badRequestText helper status" 400 (Response.status (Response.badRequestText "bad"))
  assertEqual "unauthorizedText helper status" 401 (Response.status (Response.unauthorizedText "nope"))
  assertEqual "forbiddenText helper status" 403 (Response.status (Response.forbiddenText "forbidden"))
  assertEqual "notFoundText helper status" 404 (Response.status (Response.notFoundText "missing"))
  assertEqual "conflictText helper status" 409 (Response.status (Response.conflictText "conflict"))
  assertEqual "unprocessableEntityText helper status" 422 (Response.status (Response.unprocessableEntityText "invalid"))
  assertEqual "internalServerErrorText helper status" 500 (Response.status (Response.internalServerErrorText "error"))

  let withHeaderResponse = Response.withHeader "x-trace" "abc" textResponse
  assertEqual
    "withHeader appends response header"
    [ "content-type" /\ "text/plain; charset=utf-8", "x-trace" /\ "abc" ]
    (Response.headers withHeaderResponse)

  let handler = \_ -> pure (Right (Response.json 200 "{}"))

  allowed <- expectRight
    "onlyMethod allows matching method"
    =<< API.handle (API.onlyMethod Request.GET handler) request
  assertEqual "allowed handler body" (Response.JsonBody "{}") (Response.body allowed)

  blocked <- expectRight
    "onlyMethod returns methodNotAllowed response for mismatched method"
    =<< API.handle (API.onlyMethod Request.POST handler) request
  assertEqual "blocked handler status" 405 (Response.status blocked)
  assertEqual "blocked handler body" (Response.TextBody "Method Not Allowed") (Response.body blocked)
