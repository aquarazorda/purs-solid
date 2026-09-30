module Test.Core.Router.Admin
  ( routes
  ) where

import Prelude

import Solid.JSX (text)
import Solid.Router (Route, route)

routes :: Array Route
routes = [ route @"/users" \_ -> pure (text "admin users") ]
