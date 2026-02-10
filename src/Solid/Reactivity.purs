module Solid.Reactivity
  ( MemoOptions
  , defaultMemoOptions
  , createMemo
  , createMemoWith
  , createEffect
  ) where

import Prelude

import Effect (Effect)
import Solid.Signal (Accessor, Equality(..))

type MemoOptions a =
  { name :: String
  , equality :: Equality a
  }

defaultMemoOptions :: forall a. MemoOptions a
defaultMemoOptions =
  { name: ""
  , equality: DefaultEquals
  }

createMemo :: forall a. Effect a -> Effect (Accessor a)
createMemo = createMemoWith defaultMemoOptions

createMemoWith :: forall a. MemoOptions a -> Effect a -> Effect (Accessor a)
createMemoWith options compute =
  case options.equality of
    DefaultEquals -> createMemoWithDefaultEqImpl options.name compute
    AlwaysNotify -> createMemoWithAlwaysImpl options.name compute
    CustomEquals equals -> createMemoWithCustomEqImpl options.name equals compute

foreign import createMemoWithDefaultEqImpl :: forall a. String -> Effect a -> Effect (Accessor a)

foreign import createMemoWithAlwaysImpl :: forall a. String -> Effect a -> Effect (Accessor a)

foreign import createMemoWithCustomEqImpl
  :: forall a
   . String
  -> (a -> a -> Boolean)
  -> Effect a
  -> Effect (Accessor a)

foreign import createEffect :: Effect Unit -> Effect Unit
