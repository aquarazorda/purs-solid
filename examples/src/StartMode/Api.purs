module Examples.StartMode.Api
  ( module Solid.Start.UseServer
  , greet
  ) where

import Prelude

import Data.Maybe (fromMaybe)
import Data.Traversable (traverse)
import Effect.Aff (Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Examples.StartMode.Middleware (greeterKey)
import Solid.Start.RequestEvent (getLocal, getRequestEvent)
import Solid.Start.ServerFunction (ServerFunction, serverFunction)
import Solid.Start.UseServer (useServer)

greet :: ServerFunction String String
greet = serverFunction \name -> do
  delay (Milliseconds 1.0)
  greeter <- liftEffect $ getRequestEvent >>= traverse (getLocal greeterKey)
  pure ("hello " <> name <> ", from " <> fromMaybe "nowhere" (join greeter))
