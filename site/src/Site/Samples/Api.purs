-- region server-function
module App.Api
  ( module Solid.Start.UseServer
  , greet
  ) where

import Prelude

import Solid.Start.ServerFunction as Server
import Solid.Start.UseServer (useServer)

greet :: Server.ServerFunction String String
greet = Server.serverFunction \name ->
  pure ("Hello, " <> name)
-- endregion
