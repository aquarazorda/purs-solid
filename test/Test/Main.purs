module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Class.Console (log)
import Test.Context as Context
import Test.Lifecycle as Lifecycle
import Test.Resource as Resource
import Test.Secondary as Secondary
import Test.Signal as Signal
import Test.Store as Store
import Test.Utility as Utility
import Test.Web as Web

runSuite :: String -> Effect Unit -> Effect Unit
runSuite label suite = do
  log (label <> " tests starting")
  suite

main :: Effect Unit
main = do
  runSuite "Signal" Signal.run
  log "Signal tests passed"
  runSuite "Utility" Utility.run
  runSuite "Lifecycle" Lifecycle.run
  runSuite "Secondary primitive" Secondary.run
  runSuite "Resource" Resource.run
  runSuite "Context" Context.run
  runSuite "Store" Store.run
  runSuite "Web" Web.run
  log "All tests passed"
