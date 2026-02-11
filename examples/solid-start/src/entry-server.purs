module Examples.SolidStart.Entry.Server
  ( handle
  ) where

import Data.Either (Either)
import Effect (Effect)

import Examples.SolidStart.App as ExampleApp
import Solid.Start.Error (StartError)
import Solid.Start.Entry.Server as Server

handle :: Server.ServerRequest -> Effect (Either StartError Server.ServerResponse)
handle _request =
  Server.renderDocumentResponse 200 ExampleApp.app
