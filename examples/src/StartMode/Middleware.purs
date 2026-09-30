module Examples.StartMode.Middleware
  ( middleware
  , greeterKey
  ) where

import Prelude

import Effect.Class (liftEffect)
import Solid.Start.Middleware (MiddlewareFn)
import Solid.Start.Middleware as Middleware
import Solid.Start.RequestEvent (LocalKey, localKey, setLocal, setResponseHeader)

greeterKey :: LocalKey String
greeterKey = localKey "greeter"

middleware :: MiddlewareFn
middleware = Middleware.middleware \event request next -> do
  liftEffect do
    setLocal greeterKey "the server" event
    setResponseHeader "x-middleware" "purs-solid" event
  next request
