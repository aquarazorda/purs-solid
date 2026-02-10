module Solid.JSX
  ( JSX
  , empty
  , text
  , fragment
  , keyed
  ) where

foreign import data JSX :: Type

foreign import empty :: JSX

foreign import text :: String -> JSX

foreign import fragment :: Array JSX -> JSX

foreign import keyed :: String -> JSX -> JSX
