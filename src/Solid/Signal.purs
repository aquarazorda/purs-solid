-- | Signals: the writable sources of the reactive graph. `map` / `do` on an
-- | `Accessor` build derived accessors that recompute when read (cache them
-- | with `Solid.Reactivity.createMemo`). Writes are batched until the next flush.
-- | Values that may not have loaded yet are `Async` instead, and can't be read
-- | directly.
module Solid.Signal
  ( Setter
  , toAsync
  , Signal
  , module Exports
  , SignalOptions
  , createSignal
  , createSignalWith
  , get
  , sample
  , untrack
  , set
  , modify
  , modify_
  ) where

import Prelude

import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Effect.Uncurried (EffectFn2, runEffectFn2)
import Prim.Row as Row
import Solid.Internal.Equality (Equality)
import Solid.Internal.Equality (Equality, alwaysNotify, customEquals, eqEquality) as Exports
import Solid.Internal.Setup (class MonadReactive, Setup(..), liftReactive)
import Solid.Internal.Tracked (class Tracked, Accessor, Async, fromAccessor, toAccessor)
import Solid.Internal.Tracked (class Tracked, Accessor, Async) as Exports

foreign import data Setter :: Type -> Type

type Signal a = Accessor a /\ Setter a

-- | An `Async` from a value that is always ready, e.g. to combine it with
-- | async values in a `do` block.
toAsync :: forall a. Accessor a -> Async a
toAsync = fromAccessor

type SignalOptions a =
  ( name :: String
  , equals :: Equality a
  -- | Allow writes from owned scopes (only reachable through `liftSetup`).
  , ownedWrite :: Boolean
  -- | Runs when the last reader stops observing.
  , unobserved :: Effect Unit
  )

-- | Works in `Effect` or `Setup`; signals need no disposal.
createSignal :: forall m a. MonadReactive m => a -> m (Signal a)
createSignal = createSignalWith {}

-- | Takes any subset of `SignalOptions`.
createSignalWith
  :: forall m a given missing
   . MonadReactive m
  => Row.Union given missing (SignalOptions a)
  => { | given }
  -> a
  -> m (Signal a)
createSignalWith options initial = liftReactive do
  parts <- runEffectFn2 createSignalImpl options initial
  pure (parts.get /\ parts.set)

foreign import createSignalImpl
  :: forall options a
   . EffectFn2 { | options } a { get :: Accessor a, set :: Setter a }

-- | Reads the current value without subscribing. An `Async` value can't be
-- | read this way; `Solid.Async.resolve` waits for it.
foreign import get :: forall a. Accessor a -> Effect a

-- | Reads the current value during setup without tracking. For initial values;
-- | pass the `Accessor` on for anything that should stay reactive.
sample :: forall a. Accessor a -> Setup a
sample accessor = Setup (get (untrack accessor))

-- | Reads `value` without subscribing the computation reading it.
untrack :: forall f a. Tracked f => f a -> f a
untrack = fromAccessor <<< untrackImpl <<< toAccessor

foreign import untrackImpl :: forall a. Accessor a -> Accessor a

-- | Writes a value. Visible to reads after the next flush.
set :: forall a. Setter a -> a -> Effect Unit
set setter value = runEffectFn2 setImpl setter value

foreign import setImpl :: forall a. EffectFn2 (Setter a) a Unit

-- | Updates the value from its latest (possibly not yet flushed) value and
-- | returns the value written.
modify :: forall a. Setter a -> (a -> a) -> Effect a
modify setter update = runEffectFn2 modifyImpl setter update

modify_ :: forall a. Setter a -> (a -> a) -> Effect Unit
modify_ setter update = void (modify setter update)

foreign import modifyImpl :: forall a. EffectFn2 (Setter a) (a -> a) a
