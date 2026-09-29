-- | Memos, effects and scheduling.
-- |
-- | Solid 2 splits every effect in two phases, and the types follow it:
-- |
-- | - **compute**: an `Accessor a`. Tracked and pure: whatever it reads becomes
-- |   a dependency, and it can't perform effects or write signals.
-- | - **apply**: `a -> Effect ...`. Untracked; this is where side effects and
-- |   signal writes belong. It may return a cleanup, which runs before the
-- |   next apply and when the owner is disposed.
-- |
-- | All primitives here create owned computations, so they run in `Setup`.
module Solid.Reactivity
  ( MemoOptions
  , defaultMemoOptions
  , createMemo
  , createMemoWith
  , createWritableMemo
  , EffectOptions
  , defaultEffectOptions
  , createEffect
  , createEffect_
  , createEffectWith
  , createRenderEffect
  , createRenderEffect_
  , Reaction
  , createReaction
  , track
  , flush
  , withFlush
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toNullable)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn5, mkEffectFn1, runEffectFn1, runEffectFn2, runEffectFn5)
import Solid.Internal.Equality (Equality(..), EqualityFn, toEqualityFn)
import Solid.Internal.Setup (Setup(..))
import Solid.Signal (Accessor, Setter, Signal)

type MemoOptions a =
  { name :: String
  , equality :: Equality a
  -- | Defer the first computation until the memo is read, and dispose it
  -- | when nothing observes it.
  , lazy :: Boolean
  }

defaultMemoOptions :: forall a. MemoOptions a
defaultMemoOptions =
  { name: ""
  , equality: DefaultEquals
  , lazy: false
  }

-- | Caches a derived accessor: it recomputes only when its dependencies change,
-- | and notifies only when the result changes.
createMemo :: forall a. Accessor a -> Setup (Accessor a)
createMemo = createMemoWith defaultMemoOptions

createMemoWith :: forall a. MemoOptions a -> Accessor a -> Setup (Accessor a)
createMemoWith options compute =
  Setup (runEffectFn5 createMemoImpl options.name mode equals options.lazy compute)
  where
  { mode, equals } = toEqualityFn options.equality

foreign import createMemoImpl
  :: forall a
   . EffectFn5 String String (EqualityFn a) Boolean (Accessor a) (Accessor a)

-- | A signal derived from `compute` that can also be written locally. A write
-- | wins until a dependency of `compute` changes, which re-derives it.
-- | (Solid 2's function form of `createSignal`.)
createWritableMemo :: forall a. Accessor a -> Setup (Signal a)
createWritableMemo compute = Setup do
  parts <- runEffectFn1 createWritableMemoImpl compute
  pure (parts.get /\ parts.set)

foreign import createWritableMemoImpl
  :: forall a
   . EffectFn1 (Accessor a) { get :: Accessor a, set :: Setter a }

type EffectOptions =
  { name :: String
  -- | Skip the apply phase for the initial value; run it on changes only.
  , defer :: Boolean
  -- | Handles errors thrown by the compute phase. Without a handler Solid
  -- | logs them and skips that run.
  , onError :: Maybe (Error -> Effect Unit)
  }

defaultEffectOptions :: EffectOptions
defaultEffectOptions =
  { name: ""
  , defer: false
  , onError: Nothing
  }

-- | Runs `apply` with the value of `compute` now (after the current flush) and
-- | whenever it changes. The `Effect Unit` that `apply` returns is its cleanup.
createEffect :: forall a. Accessor a -> (a -> Effect (Effect Unit)) -> Setup Unit
createEffect = createEffectWith defaultEffectOptions

-- | `createEffect` without a cleanup.
createEffect_ :: forall a. Accessor a -> (a -> Effect Unit) -> Setup Unit
createEffect_ compute apply = createEffect compute \value -> apply value $> pure unit

createEffectWith :: forall a. EffectOptions -> Accessor a -> (a -> Effect (Effect Unit)) -> Setup Unit
createEffectWith options compute apply =
  Setup
    ( runEffectFn5 createEffectImpl
        options.name
        options.defer
        (toNullable (mkEffectFn1 <$> options.onError))
        compute
        (mkEffectFn1 apply)
    )

foreign import createEffectImpl
  :: forall a
   . EffectFn5 String Boolean (Nullable (EffectFn1 Error Unit)) (Accessor a) (EffectFn1 a (Effect Unit)) Unit

-- | Like `createEffect`, but the apply phase runs synchronously during
-- | rendering, before the DOM is committed. For DOM measurements and writes
-- | that must not wait for the next frame.
createRenderEffect :: forall a. Accessor a -> (a -> Effect (Effect Unit)) -> Setup Unit
createRenderEffect compute apply =
  Setup (runEffectFn2 createRenderEffectImpl compute (mkEffectFn1 apply))

createRenderEffect_ :: forall a. Accessor a -> (a -> Effect Unit) -> Setup Unit
createRenderEffect_ compute apply = createRenderEffect compute \value -> apply value $> pure unit

foreign import createRenderEffectImpl
  :: forall a
   . EffectFn2 (Accessor a) (EffectFn1 a (Effect Unit)) Unit

-- | A reaction runs its handler once, the next time anything read by the
-- | last `track` changes.
foreign import data Reaction :: Type

createReaction :: Effect Unit -> Setup Reaction
createReaction onInvalidate = Setup (runEffectFn1 createReactionImpl onInvalidate)

foreign import createReactionImpl :: EffectFn1 (Effect Unit) Reaction

-- | Reads `accessor` under the reaction, recording its dependencies.
track :: forall a. Reaction -> Accessor a -> Effect Unit
track reaction accessor = runEffectFn2 trackImpl reaction accessor

foreign import trackImpl :: forall a. EffectFn2 Reaction (Accessor a) Unit

-- | Applies pending writes now instead of at the next microtask.
foreign import flush :: Effect Unit

-- | Runs `action` and applies the writes it made before returning.
withFlush :: forall a. Effect a -> Effect a
withFlush action = runEffectFn1 withFlushImpl action

foreign import withFlushImpl :: forall a. EffectFn1 (Effect a) a
