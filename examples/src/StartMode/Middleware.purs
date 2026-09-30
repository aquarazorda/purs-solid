module Examples.StartMode.Middleware
  ( middleware
  , greeterKey
  ) where

import Prelude

import Data.Foldable (for_)
import Effect.Class (liftEffect)
import Solid.Start.Middleware (MiddlewareFn)
import Solid.Start.Middleware as Middleware
import Solid.Start.RequestEvent (LocalKey, getRequestEvent, localKey, setLocal, setResponseHeader)

greeterKey :: LocalKey String
greeterKey = localKey "greeter"

middleware :: MiddlewareFn
middleware = Middleware.middleware \request next -> do
  liftEffect $ getRequestEvent >>= flip for_ \event -> do
    setLocal greeterKey "the server" event
    setResponseHeader "x-middleware" "purs-solid" event
  next request
