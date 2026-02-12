module Examples.SolidStart.Navigation
  ( navigateToRoute
  ) where

import Prelude

import Effect (Effect)

import Solid.Signal (Setter, set)

navigateToRoute :: String -> Setter String -> Effect Unit
navigateToRoute routeId setCurrentRoute = do
  _ <- set setCurrentRoute routeId
  pure unit
