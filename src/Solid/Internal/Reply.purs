-- | Internal: not part of the public API.
module Solid.Internal.Reply
  ( Reply
  ) where

-- | A result of `b`, or a redirect or reload with no value.
foreign import data Reply :: Type -> Type
