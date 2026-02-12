module Examples.SolidStart.Config
  ( basePath
  , routeStyles
  , routeHref
  , linkClass
  ) where

import Prelude

import Solid.Router.Navigation as RouterNavigation

basePath :: String
basePath = ""

routeStyles :: Array RouterNavigation.RouteStyle
routeStyles = []

routeHref :: String -> String
routeHref routePath =
  if routePath == "" || routePath == "/" then
    "/"
  else
    routePath

linkClass :: String -> String -> String
linkClass currentRoute routeId =
  if isActiveRoute then
    "active"
  else
    ""
  where
  isActiveRoute =
    if routeId == "/" then
      currentRoute == "/"
    else
      currentRoute == routeId
