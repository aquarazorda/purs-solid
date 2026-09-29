-- | Control flow: conditionals, lists, async and error boundaries.
-- |
-- | Content arguments are lazy `JSX`: a branch is only created while it's
-- | shown. Render callbacks run in `Setup`, so each rendered item or branch
-- | can hold its own state, and it's disposed when the item leaves.
module Solid.Control
  ( when
  , whenElse
  , showMaybe
  , showMaybeElse
  , showMaybeKeyed
  , showMaybeKeyedElse
  , forEach
  , forEachElse
  , forEachUnkeyed
  , forEachBy
  , repeat
  , Case
  , match
  , matchMaybe
  , switch
  , switch_
  , loading
  , errored
  , RevealOrder(..)
  , reveal
  , portal
  , portalAt
  , dynamic
  , noHydration
  , hydration
  ) where

import Prelude hiding (when)

import Data.Function.Uncurried (runFn2, runFn3, runFn4)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (Nullable, notNull, null, toNullable)
import Effect (Effect)
import Effect.Exception (Error)
import Solid.Component (Component)
import Solid.Internal.Setup (Setup, runSetup)
import Solid.Internal.View (JSX, WhenValue, empty, erroredImpl, forByImpl, forImpl, forUnkeyedImpl, hydrationImpl, loadingImpl, matchImpl, matchMaybeImpl, noHydrationImpl, portalImpl, repeatImpl, revealImpl, showImpl, showMaybeImpl, showMaybeKeyedImpl, switchImpl, whenValue)
import Solid.Internal.View as View
import Solid.Signal (Accessor)
import Web.DOM.Element (Element)

-- | `content` while the condition holds.
when :: Accessor Boolean -> JSX -> JSX
when condition content = runFn3 showImpl condition empty content

-- | `content` while the condition holds, `fallback` otherwise.
whenElse :: Accessor Boolean -> JSX -> JSX -> JSX
whenElse condition content fallback = runFn3 showImpl condition fallback content

toWhen :: forall a. Accessor (Maybe a) -> Accessor (Nullable (WhenValue a))
toWhen = map (maybe null (notNull <<< whenValue))

-- | Renders while the value is `Just`. The branch is created once and reads
-- | the current value through the accessor.
showMaybe :: forall a. Accessor (Maybe a) -> (Accessor a -> Setup JSX) -> JSX
showMaybe value render = showMaybeElse value render empty

showMaybeElse :: forall a. Accessor (Maybe a) -> (Accessor a -> Setup JSX) -> JSX -> JSX
showMaybeElse value render fallback = runFn3 showMaybeImpl (toWhen value) fallback (runSetup <<< render)

-- | Renders while the value is `Just`, re-creating the branch whenever the
-- | value changes (by identity).
showMaybeKeyed :: forall a. Accessor (Maybe a) -> (a -> Setup JSX) -> JSX
showMaybeKeyed value render = showMaybeKeyedElse value render empty

showMaybeKeyedElse :: forall a. Accessor (Maybe a) -> (a -> Setup JSX) -> JSX -> JSX
showMaybeKeyedElse value render fallback = runFn3 showMaybeKeyedImpl (toWhen value) fallback (runSetup <<< render)

-- | A list keyed by item identity (`===`): an item's view is created once and
-- | moved when the item moves. Use store `items` or stable values for items.
forEach :: forall a. Accessor (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX
forEach items render = forEachElse items render empty

forEachElse :: forall a. Accessor (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX -> JSX
forEachElse items render fallback = runFn3 forImpl items fallback (\item index -> runSetup (render item index))

-- | A list keyed by position: the view at each index stays, and its item
-- | accessor updates when a different value lands there.
forEachUnkeyed :: forall a. Accessor (Array a) -> (Accessor a -> Int -> Setup JSX) -> JSX
forEachUnkeyed items render = runFn3 forUnkeyedImpl items empty (\item index -> runSetup (render item index))

-- | A list keyed by a derived key (e.g. `_.id`): items with the same key share
-- | a view, whose item accessor updates to the newest value.
forEachBy :: forall a k. (a -> k) -> Accessor (Array a) -> (Accessor a -> Accessor Int -> Setup JSX) -> JSX
forEachBy key items render = runFn4 forByImpl key items empty (\item index -> runSetup (render item index))

-- | Renders the indices `0 .. count - 1`.
repeat :: Accessor Int -> (Int -> Setup JSX) -> JSX
repeat count render = runFn3 repeatImpl count empty (runSetup <<< render)

-- | One case of a `switch`.
newtype Case = Case JSX

match :: Accessor Boolean -> JSX -> Case
match condition content = Case (runFn2 matchImpl condition content)

matchMaybe :: forall a. Accessor (Maybe a) -> (a -> Setup JSX) -> Case
matchMaybe value render = Case (runFn2 matchMaybeImpl (toWhen value) (runSetup <<< render))

-- | The first case whose condition holds, else `fallback`.
switch :: Array Case -> JSX -> JSX
switch cases fallback = runFn2 switchImpl (caseJsx <$> cases) fallback
  where
  caseJsx (Case jsx) = jsx

switch_ :: Array Case -> JSX
switch_ cases = switch cases empty

-- | Shows `fallback` while async values read by `content` load for the first
-- | time. Later updates keep the current content visible (ask
-- | `Solid.Async.isPending` to show that something is in flight).
loading :: JSX -> JSX -> JSX
loading fallback content = runFn2 loadingImpl fallback content

-- | Renders the fallback if `content` throws. The fallback receives the error
-- | and a `reset` effect (call it from an event handler) that retries.
errored :: (Accessor Error -> Effect Unit -> Setup JSX) -> JSX -> JSX
errored renderFallback content =
  runFn2 erroredImpl (\error reset -> runSetup (renderFallback error reset)) content

-- | How `reveal` shows its loading children.
data RevealOrder
  -- | In order: each waits for the ones before it.
  = Sequential
  -- | All at once, when all are ready.
  | Together
  -- | Each as soon as it's ready.
  | Natural

derive instance Eq RevealOrder

-- | Coordinates the loading boundaries among `children`. With `collapsed`,
-- | boundaries not yet revealed show nothing instead of their fallbacks.
reveal :: { order :: RevealOrder, collapsed :: Boolean } -> Array JSX -> JSX
reveal options children = runFn3 revealImpl order options.collapsed children
  where
  order = case options.order of
    Sequential -> "sequential"
    Together -> "together"
    Natural -> "natural"

-- | Renders `content` into `document.body` (client only).
portal :: JSX -> JSX
portal = runFn2 portalImpl null

-- | Renders `content` into `mount` (client only).
portalAt :: Element -> JSX -> JSX
portalAt mount = runFn2 portalImpl (toNullable (Just mount))

-- | Renders whichever component the accessor currently holds.
dynamic :: forall props. Accessor (Component { | props }) -> { | props } -> JSX
dynamic source props = runFn2 View.dynamicImpl source props

-- | Server-rendered content that isn't hydrated.
noHydration :: JSX -> JSX
noHydration = noHydrationImpl

-- | Re-enables hydration inside `noHydration`.
hydration :: JSX -> JSX
hydration = hydrationImpl
