module Test.Start.ServerFunction
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Solid.Start.Error (StartError(..))
import Solid.Start.Internal.Serialization as Serialization
import Solid.Start.Server.Function as ServerFunction
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  let intCodec =
        Serialization.mkWireCodec
          show
          (\raw -> if raw == "41" then Right 41 else Left "expected 41")

  let responseCodec =
        Serialization.mkWireCodec
          identity
          Right

  let handler input =
        if input == 41 then
          pure (Right "42")
        else
          pure (Left (ServerFunctionExecutionError "unexpected input"))

  let fn = ServerFunction.createServerFunction intCodec responseCodec handler

  decoded <- ServerFunction.dispatchSerialized fn "41"
  assertEqual "dispatchSerialized decodes input and encodes output" (Right "42") decoded

  decodeFailure <- ServerFunction.dispatchSerialized fn "0"
  assertEqual
    "dispatchSerialized maps decode errors"
    (Left (ServerFunctionDecodeError "expected 41"))
    decodeFailure

  directCall <- ServerFunction.call fn 41
  assertEqual "direct call executes server function" (Right "42") directCall
