-- | Internal: not part of the public API.
module Solid.Internal.ServerFunction
  ( ServerFunction
  , checked
  ) where

foreign import data ServerFunction :: Type -> Type -> Type

-- | The function itself, or, in the browser when `@solidjs/vite-plugin` didn't
-- | transform it, one that rejects instead of running the bundled body.
foreign import checked :: forall a b. ServerFunction a b -> ServerFunction a b
