module Examples.SolidStart.Config
  ( basePath
  , routeStyles
  , routeHref
  , linkClass
  ) where

import Prelude

import Solid.Start.Client.Navigation as ClientNavigation

basePath :: String
basePath = ""

routeStyles :: Array ClientNavigation.RouteStyle
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
