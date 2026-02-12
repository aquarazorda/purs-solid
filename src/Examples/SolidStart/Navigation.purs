module Examples.SolidStart.Navigation
  ( navigateToRoute
  ) where

import Prelude

import Effect (Effect)

import Solid.Signal (Setter, set)

navigateToRoute :: String -> Setter String -> (String -> Effect String) -> Effect Unit
navigateToRoute routeId setCurrentRoute navigate = do
  nextRoute <- navigate routeId
  _ <- set setCurrentRoute nextRoute
  pure unit
