-- | Re-exporting this module makes a module a server module, the PureScript
-- | form of a `"use server"` file: `purs-solid/vite` turns each of its exports
-- | into a server function, and none of its code reaches the browser. Every
-- | value it exports must be a `serverFunction`; types are fine.
-- |
-- | ```purescript
-- | module App.Api (module Solid.Start.UseServer, saveTodo) where
-- |
-- | import Solid.Start.UseServer (useServer)
-- |
-- | saveTodo :: ServerFunction NewTodo { id :: Int }
-- | saveTodo = serverFunction \todo -> Db.insert todo
-- | ```
module Solid.Start.UseServer
  ( UseServer
  , useServer
  ) where

data UseServer = UseServer

useServer :: UseServer
useServer = UseServer
