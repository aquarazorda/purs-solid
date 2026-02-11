module Test.Start.RequestEvent
  ( run
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.Start.Request.Event as RequestEvent
import Solid.Start.Server.Request as Request
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  let baseRequest = Request.mkRequest Request.GET "/api/profile" [] [] Nothing
  let event0 = RequestEvent.mkRequestEvent baseRequest

  assertEqual "request accessor returns original request path" "/api/profile" (Request.path (RequestEvent.request event0))
  assertEqual "empty context has no value" Nothing (RequestEvent.lookupContextValue "user" event0)

  let event1 = RequestEvent.withContextValue "user" "alice" event0
  assertEqual "context value is retrievable" (Just "alice") (RequestEvent.lookupContextValue "user" event1)

  let event2 = RequestEvent.withContextValue "user" "bob" event1
  assertEqual "context value overwrite keeps latest value" (Just "bob") (RequestEvent.lookupContextValue "user" event2)
