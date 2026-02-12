module Examples.SolidStartSSR.Api
  ( fetchText
  ) where

import Control.Promise as Promise
import Data.Either (Either)
import Effect (Effect)
import Effect.Aff (Aff)

fetchText :: String -> Aff (Either String String)
fetchText url =
  Promise.toAffE (fetchTextImpl url)

foreign import fetchTextImpl
  :: String
  -> Effect (Promise.Promise (Either String String))
