-- | Error helpers shared by the FFI wrappers.
module Solid.Internal.Error
  ( errorMessage
  , tryMessage
  ) where

import Prelude

import Data.Bifunctor (lmap)
import Data.Either (Either)
import Effect (Effect)
import Effect.Exception (Error, try)

-- | The message of a caught exception. Also handles non-`Error` values
-- | thrown by JavaScript code (strings, plain objects).
foreign import errorMessage :: Error -> String

-- | Runs an effect, catching any exception as its message.
tryMessage :: forall a. Effect a -> Effect (Either String a)
tryMessage action = lmap errorMessage <$> try action
