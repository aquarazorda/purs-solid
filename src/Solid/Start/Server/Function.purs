module Solid.Start.Server.Function
  ( ServerFunction
  , createServerFunction
  , call
  , dispatchSerialized
  ) where

import Data.Either (Either(..))
import Effect (Effect)
import Prelude

import Solid.Start.Error (StartError(..))
import Solid.Start.Internal.Serialization (WireCodec, decodeWith, encodeWith)

newtype ServerFunction input output = ServerFunction
  { decodeInput :: String -> Either String input
  , encodeOutput :: output -> String
  , execute :: input -> Effect (Either StartError output)
  }

createServerFunction
  :: forall input output
   . WireCodec input
  -> WireCodec output
  -> (input -> Effect (Either StartError output))
  -> ServerFunction input output
createServerFunction inputCodec outputCodec execute =
  ServerFunction
    { decodeInput: decodeWith inputCodec
    , encodeOutput: encodeWith outputCodec
    , execute
    }

call
  :: forall input output
   . ServerFunction input output
  -> input
  -> Effect (Either StartError output)
call (ServerFunction serverFunction) input =
  serverFunction.execute input

dispatchSerialized
  :: forall input output
   . ServerFunction input output
  -> String
  -> Effect (Either StartError String)
dispatchSerialized (ServerFunction serverFunction) serializedInput =
  case serverFunction.decodeInput serializedInput of
    Left decodeError ->
      pure (Left (ServerFunctionDecodeError decodeError))
    Right input -> do
      result <- serverFunction.execute input
      pure case result of
        Left startError -> Left startError
        Right output -> Right (serverFunction.encodeOutput output)
