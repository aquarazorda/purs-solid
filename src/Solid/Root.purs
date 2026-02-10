module Solid.Root
  ( createRoot
  ) where

import Prelude

import Effect (Effect)

foreign import createRoot :: forall a. (Effect Unit -> Effect a) -> Effect a
