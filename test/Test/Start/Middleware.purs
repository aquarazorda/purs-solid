module Test.Start.Middleware
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Start.Error (StartError(..))
import Solid.Start.Middleware as Middleware
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
  let request = Request.mkRequest Request.GET "/api/hello" [ "x-auth" /\ "ok" ] [] Nothing
  let responseHandler _ = pure (Right (Response.text 200 "hello"))

  response <- expectRight
    "middleware appends headers in order"
    =<< Middleware.run
      [ Middleware.appendResponseHeader "x-first" "1"
      , Middleware.appendResponseHeader "x-second" "2"
      ]
      responseHandler
      request

  assertEqual
    "middleware onion order applies outer transform last"
    [ "content-type" /\ "text/plain; charset=utf-8"
    , "x-second" /\ "2"
    , "x-first" /\ "1"
    ]
    (Response.headers response)

  missingHeader <- Middleware.run
    [ Middleware.requireHeader "x-session" ]
    responseHandler
    request

  assertEqual
    "requireHeader short-circuits with typed middleware error"
    (Left (MiddlewareError "Missing required header: x-session"))
    missingHeader

  presentHeader <- expectRight
    "requireHeader passes request when header exists"
    =<< Middleware.run
      [ Middleware.requireHeader "x-auth" ]
      responseHandler
      request

  assertEqual "requireHeader successful response status" 200 (Response.status presentHeader)
