-- | Control flow. A branch is only created while it's shown; render callbacks
-- | run in `Setup`, so each item or branch owns its state until it leaves.
module Solid.Control
  ( when
  , whenElse
  , showMaybe
  , showMaybeElse
  , showMaybeKeyed
  , showMaybeKeyedElse
  , forEach
  , forEachElse
  , forEachByReference
  , forEachByReferenceElse
  , forEachUnkeyed
  , forEachUnkeyedElse
  , forEachBy
  , forEachByElse
  , repeat
  , repeatElse
  , Case
  , match
  , matchMaybe
  , switch
  , switch_
  , caseOn
  , constructorName
  , class ConstructorName
  , constructorNameOf
  , loading
  , loadingOn
  , errored
  , RevealOrder
  , sequential
  , together
  , natural
  , RevealOptions
  , reveal
  , portal
  , portalAt
  , dynamic
  , module Exports
  , noHydration
  , hydration
  ) where

import Prelude hiding (when)

import Data.Function.Uncurried (runFn2, runFn3, runFn4)
import Data.Generic.Rep (class Generic, Constructor, Sum(..), from)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (Nullable, notNull, null, toNullable)
import Effect (Effect)
import Effect.Exception (Error)
import Solid.Component (Component)
import Solid.Component as Component
import Solid.Internal.Equality (eqEquality)
import Solid.Reactivity (createMemoWith)
import Solid.Internal.Identity (class StableIdentity)
import Solid.Internal.Identity (class StableIdentity) as Exports
import Solid.Internal.Setup (Setup, runSetup)
import Prim.Row as Row
import Solid.Internal.View (JSX, WhenValue, empty, erroredImpl, forImpl, hydrationImpl, keyedBy, keyedByIdentity, keyedByPosition, loadingImpl, matchImpl, matchMaybeImpl, noHydrationImpl, portalImpl, repeatImpl, revealImpl, showImpl, showMaybeImpl, switchImpl, whenValue)
import Solid.Internal.View as View
import Solid.Internal.Tracked (class Tracked, Accessor, toAccessor)
import Solid.Signal (sample)
import Type.Proxy (Proxy(..))
import Web.DOM.Element (Element)

when :: forall f. Tracked f => f Boolean -> JSX -> JSX
when condition content = runFn3 showImpl (toAccessor condition) empty content

whenElse :: forall f. Tracked f => f Boolean -> JSX -> JSX -> JSX
whenElse condition content fallback = runFn3 showImpl (toAccessor condition) fallback content

toWhen :: forall f a. Tracked f => f (Maybe a) -> Accessor (Nullable (WhenValue a))
toWhen = map (maybe null (notNull <<< whenValue)) <<< toAccessor

-- | The branch is created once and reads the current value through the accessor.
showMaybe :: forall f a. Tracked f => f (Maybe a) -> (Accessor a -> Setup JSX) -> JSX
showMaybe value render = showMaybeElse value render empty

showMaybeElse :: forall f a. Tracked f => f (Maybe a) -> (Accessor a -> Setup JSX) -> JSX -> JSX
showMaybeElse value render fallback = runFn4 showMaybeImpl false (toWhen value) fallback (runSetup <<< render)

-- | Re-creates the branch whenever the value changes (by identity).
showMaybeKeyed :: forall f a. Tracked f => f (Maybe a) -> (a -> Setup JSX) -> JSX
showMaybeKeyed value render = showMaybeKeyedElse value render empty

showMaybeKeyedElse :: forall f a. Tracked f => f (Maybe a) -> (a -> Setup JSX) -> JSX -> JSX
showMaybeKeyedElse value render fallback = runFn4 showMaybeImpl true (toWhen value) fallback (runSetup <<< render)

-- | Keyed by the items themselves: an item's view is created once and moved
-- | with the item. For primitives and store cursors (`Store.items`).
forEach :: forall f a. Tracked f => StableIdentity a => f (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX
forEach = forEachByReference

forEachElse :: forall f a. Tracked f => StableIdentity a => f (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX -> JSX
forEachElse = forEachByReferenceElse

-- | `forEach` for any values, keyed by reference (`===`). Rows survive only
-- | while the list keeps the same values (moving or filtering them, not
-- | rebuilding them).
forEachByReference :: forall f a. Tracked f => f (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX
forEachByReference items render = forEachByReferenceElse items render empty

forEachByReferenceElse :: forall f a. Tracked f => f (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX -> JSX
forEachByReferenceElse items render fallback = runFn4 forImpl keyedByIdentity (toAccessor items) fallback (\item index -> runSetup (render item index))

-- | Keyed by position: the view at each index stays and its item accessor updates.
forEachUnkeyed :: forall f a. Tracked f => f (Array a) -> (Accessor a -> Int -> Setup JSX) -> JSX
forEachUnkeyed items render = forEachUnkeyedElse items render empty

forEachUnkeyedElse :: forall f a. Tracked f => f (Array a) -> (Accessor a -> Int -> Setup JSX) -> JSX -> JSX
forEachUnkeyedElse items render fallback = runFn4 forImpl keyedByPosition (toAccessor items) fallback (\item index -> runSetup (render item index))

-- | Keyed by a derived key (e.g. `_.id`); the item accessor updates to the newest value.
forEachBy :: forall f a k. Tracked f => (a -> k) -> f (Array a) -> (Accessor a -> Accessor Int -> Setup JSX) -> JSX
forEachBy key items render = forEachByElse key items render empty

forEachByElse :: forall f a k. Tracked f => (a -> k) -> f (Array a) -> (Accessor a -> Accessor Int -> Setup JSX) -> JSX -> JSX
forEachByElse key items render fallback = runFn4 forImpl (keyedBy key) (toAccessor items) fallback (\item index -> runSetup (render item index))

-- | Renders the indices `0 .. count - 1`.
repeat :: forall f. Tracked f => f Int -> (Int -> Setup JSX) -> JSX
repeat count render = repeatElse count render empty

repeatElse :: forall f. Tracked f => f Int -> (Int -> Setup JSX) -> JSX -> JSX
repeatElse count render fallback = runFn3 repeatImpl (toAccessor count) fallback (runSetup <<< render)

newtype Case = Case JSX

match :: forall f. Tracked f => f Boolean -> JSX -> Case
match condition content = Case (runFn2 matchImpl (toAccessor condition) content)

matchMaybe :: forall f a. Tracked f => f (Maybe a) -> (a -> Setup JSX) -> Case
matchMaybe value render = Case (runFn2 matchMaybeImpl (toWhen value) (runSetup <<< render))

-- | The first case whose condition holds, else `fallback`.
switch :: Array Case -> JSX -> JSX
switch cases fallback = runFn2 switchImpl (caseJsx <$> cases) fallback
  where
  caseJsx (Case jsx) = jsx

switch_ :: Array Case -> JSX
switch_ cases = switch cases empty

-- | Renders a branch per key of `value`, rebuilding it only when the key
-- | changes (by `Eq`). The branch gets the value it was built for, to pattern
-- | match on, and the accessor for later changes under the same key:
-- |
-- | ```purescript
-- | caseOn constructorName page \current latest -> case current of
-- |   Home -> homeView
-- |   Profile _ -> profileView latest
-- | ```
caseOn :: forall f a k. Tracked f => Eq k => (a -> k) -> f a -> (a -> Accessor a -> Setup JSX) -> JSX
caseOn toKey value render = Component.element branches {}
  where
  branches = Component.component \_ -> do
    key <- createMemoWith { equals: eqEquality } (toKey <$> value)
    let current = toAccessor value
    pure $ showMaybeKeyed (Just <$> key) \_ -> sample current >>= \initial -> render initial current

-- | The name of a value's constructor, e.g. to key `caseOn` by constructor.
constructorName :: forall a rep. Generic a rep => ConstructorName rep => a -> String
constructorName = constructorNameOf <<< from

class ConstructorName rep where
  constructorNameOf :: rep -> String

instance (ConstructorName a, ConstructorName b) => ConstructorName (Sum a b) where
  constructorNameOf (Inl a) = constructorNameOf a
  constructorNameOf (Inr b) = constructorNameOf b

instance IsSymbol name => ConstructorName (Constructor name arguments) where
  constructorNameOf _ = reflectSymbol (Proxy :: Proxy name)

-- | Shows `fallback` only on the first load; later updates keep the current
-- | content visible (use `Solid.Async.isPending` to show them).
loading :: JSX -> JSX -> JSX
loading fallback content = runFn3 loadingImpl null fallback content

-- | Like `loading`, but shows `fallback` again whenever `key` changes, e.g.
-- | the route's params, instead of keeping the previous content.
loadingOn :: forall f a. Tracked f => f a -> JSX -> JSX -> JSX
loadingOn key fallback content = runFn3 loadingImpl (notNull (toAccessor key)) fallback content

-- | The fallback receives the error and a `reset` effect (call it from an
-- | event handler) that retries.
errored :: (Accessor Error -> Effect Unit -> Setup JSX) -> JSX -> JSX
errored renderFallback content =
  runFn2 erroredImpl (\error reset -> runSetup (renderFallback error reset)) content

newtype RevealOrder = RevealOrder String

derive newtype instance Eq RevealOrder

-- | In order: each waits for the ones before it.
sequential :: RevealOrder
sequential = RevealOrder "sequential"

-- | All at once, when all are ready.
together :: RevealOrder
together = RevealOrder "together"

-- | Each as soon as it's ready.
natural :: RevealOrder
natural = RevealOrder "natural"

type RevealOptions =
  ( order :: RevealOrder
  -- | Unrevealed boundaries show nothing instead of their fallbacks.
  , collapsed :: Boolean
  )

-- | Coordinates the loading boundaries among `children`. Takes any subset of
-- | `RevealOptions`.
reveal :: forall given missing. Row.Union given missing RevealOptions => { | given } -> Array JSX -> JSX
reveal = runFn2 revealImpl

-- | Renders `content` into `document.body` (client only).
portal :: JSX -> JSX
portal = runFn2 portalImpl null

-- | Renders `content` into `mount` (client only).
portalAt :: Element -> JSX -> JSX
portalAt mount = runFn2 portalImpl (toNullable (Just mount))

dynamic :: forall f props. Tracked f => f (Component { | props }) -> { | props } -> JSX
dynamic source props = runFn2 View.dynamicImpl (toAccessor source) props

-- | Server-rendered content that isn't hydrated.
noHydration :: JSX -> JSX
noHydration = noHydrationImpl

-- | Re-enables hydration inside `noHydration`.
hydration :: JSX -> JSX
hydration = hydrationImpl
