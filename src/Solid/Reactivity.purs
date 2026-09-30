-- | Memos, effects and scheduling. Effects have a tracked, pure compute phase
-- | (an `Accessor`) and an untracked apply phase (`a -> Effect ...`) whose
-- | cleanup runs before the next apply and on disposal.
module Solid.Reactivity
  ( MemoOptions
  , createMemo
  , createMemoWith
  , createWritableMemo
  , createWritableMemoWith
  , EffectOptions
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

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, mkEffectFn1, runEffectFn1, runEffectFn2, runEffectFn3)
import Prim.Row as Row
import Solid.Internal.Equality (Equality)
import Solid.Internal.Setup (Setup(..))
import Solid.Internal.Tracked (class Tracked, Accessor, fromAccessor, toAccessor)
import Solid.Signal (Setter, Signal)

type MemoOptions a =
  ( name :: String
  , equals :: Equality a
  -- | Defer the first computation until read; dispose when nothing observes it.
  , lazy :: Boolean
  -- | Runs when the last reader stops observing.
  , unobserved :: Effect Unit
  -- | A stable hydration id instead of one from its position.
  , id :: String
  -- | Don't count as an owner level for hydration ids.
  , transparent :: Boolean
  )

-- | Caches a derived accessor: it recomputes only when its dependencies change,
-- | and notifies only when the result changes.
createMemo :: forall f a. Tracked f => f a -> Setup (f a)
createMemo = createMemoWith {}

-- | Takes any subset of `MemoOptions`.
createMemoWith
  :: forall f a given missing
   . Tracked f
  => Row.Union given missing (MemoOptions a)
  => { | given }
  -> f a
  -> Setup (f a)
createMemoWith options compute = Setup (fromAccessor <$> runEffectFn2 createMemoImpl options (toAccessor compute))

foreign import createMemoImpl :: forall options a. EffectFn2 { | options } (Accessor a) (Accessor a)

-- | A signal derived from `compute` that can also be written locally. A write
-- | wins until a dependency of `compute` changes, which re-derives it.
createWritableMemo :: forall a. Accessor a -> Setup (Signal a)
createWritableMemo = createWritableMemoWith {}

-- | Takes any subset of `MemoOptions`.
createWritableMemoWith
  :: forall a given missing
   . Row.Union given missing (MemoOptions a)
  => { | given }
  -> Accessor a
  -> Setup (Signal a)
createWritableMemoWith options compute = Setup do
  parts <- runEffectFn2 createWritableMemoImpl options compute
  pure (parts.get /\ parts.set)

foreign import createWritableMemoImpl
  :: forall options a
   . EffectFn2 { | options } (Accessor a) { get :: Accessor a, set :: Setter a }

type EffectOptions =
  ( name :: String
  -- | Skip the apply phase for the initial value; run it on changes only.
  , defer :: Boolean
  -- | Handles compute-phase errors; without it Solid logs them and skips the run.
  , onError :: Error -> Effect Unit
  -- | Queue the first apply like later ones instead of running it during setup.
  , schedule :: Boolean
  , transparent :: Boolean
  )

-- | Runs `apply` with the value of `compute` now (after the current flush) and
-- | whenever it changes. The `Effect Unit` that `apply` returns is its cleanup.
createEffect :: forall f a. Tracked f => f a -> (a -> Effect (Effect Unit)) -> Setup Unit
createEffect = createEffectWith {}

createEffect_ :: forall f a. Tracked f => f a -> (a -> Effect Unit) -> Setup Unit
createEffect_ compute apply = createEffect compute \value -> apply value $> pure unit

-- | Takes any subset of `EffectOptions`.
createEffectWith
  :: forall f a given missing
   . Tracked f
  => Row.Union given missing EffectOptions
  => { | given }
  -> f a
  -> (a -> Effect (Effect Unit))
  -> Setup Unit
createEffectWith options compute apply =
  Setup (runEffectFn3 createEffectImpl options (toAccessor compute) (mkEffectFn1 apply))

foreign import createEffectImpl
  :: forall options a
   . EffectFn3 { | options } (Accessor a) (EffectFn1 a (Effect Unit)) Unit

-- | Like `createEffect`, but the apply phase runs synchronously during
-- | rendering, before the DOM is committed.
createRenderEffect :: forall f a. Tracked f => f a -> (a -> Effect (Effect Unit)) -> Setup Unit
createRenderEffect compute apply =
  Setup (runEffectFn2 createRenderEffectImpl (toAccessor compute) (mkEffectFn1 apply))

createRenderEffect_ :: forall f a. Tracked f => f a -> (a -> Effect Unit) -> Setup Unit
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
track :: forall f a. Tracked f => Reaction -> f a -> Effect Unit
track reaction value = runEffectFn2 trackImpl reaction (toAccessor value)

foreign import trackImpl :: forall a. EffectFn2 Reaction (Accessor a) Unit

-- | Applies pending writes now instead of at the next microtask.
foreign import flush :: Effect Unit

-- | Runs `action` and applies the writes it made before returning.
withFlush :: forall a. Effect a -> Effect a
withFlush action = runEffectFn1 withFlushImpl action

foreign import withFlushImpl :: forall a. EffectFn1 (Effect a) a
