module Solid.Start.Internal.Serialization
  ( WireCodec
  , mkWireCodec
  , encodeWith
  , decodeWith
  ) where

import Data.Either (Either)

newtype WireCodec a = WireCodec
  { encode :: a -> String
  , decode :: String -> Either String a
  }

mkWireCodec
  :: forall a
   . (a -> String)
  -> (String -> Either String a)
  -> WireCodec a
mkWireCodec encode decode =
  WireCodec { encode, decode }

encodeWith :: forall a. WireCodec a -> a -> String
encodeWith (WireCodec codec) value =
  codec.encode value

decodeWith :: forall a. WireCodec a -> String -> Either String a
decodeWith (WireCodec codec) value =
  codec.decode value
