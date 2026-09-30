-- | Response status and headers declared while server rendering. They're
-- | withdrawn if their scope is disposed before the response head is sent.
-- | On the client they do nothing.
module Solid.Start.Response
  ( httpStatus
  , httpHeader
  , appendHttpHeader
  ) where

import Prelude

import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Solid.Internal.Setup (Setup(..))

httpStatus :: Int -> Setup Unit
httpStatus code = Setup (runEffectFn1 httpStatusImpl code)

httpHeader :: String -> String -> Setup Unit
httpHeader name value = Setup (runEffectFn3 httpHeaderImpl name value false)

appendHttpHeader :: String -> String -> Setup Unit
appendHttpHeader name value = Setup (runEffectFn3 httpHeaderImpl name value true)

foreign import httpStatusImpl :: EffectFn1 Int Unit

foreign import httpHeaderImpl :: EffectFn3 String String Boolean Unit
