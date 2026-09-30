module Test.Server.Main where

import Prelude

import Effect (Effect)
import Test.Spec (Spec, describe)
import Test.Spec.Reporter (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.Server.Meta as Meta
import Test.Server.SSR as SSR
import Test.Server.Start as Start

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] spec

spec :: Spec Unit
spec = describe "server" do
  SSR.spec
  Meta.spec
  Start.spec
