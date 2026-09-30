module Examples.StartMode.Api
  ( module Solid.Start.UseServer
  , greet
  ) where

import Prelude

import Data.Maybe (fromMaybe)
import Effect.Aff (Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Examples.StartMode.Middleware (greeterKey)
import Solid.Start.RequestEvent (getLocal)
import Solid.Start.ServerFunction (ServerFunction, serverFunctionWithEvent)
import Solid.Start.UseServer (useServer)

greet :: ServerFunction String String
greet = serverFunctionWithEvent \event name -> do
  delay (Milliseconds 1.0)
  greeter <- liftEffect (getLocal greeterKey event)
  pure ("hello " <> name <> ", from " <> fromMaybe "nowhere" greeter)
