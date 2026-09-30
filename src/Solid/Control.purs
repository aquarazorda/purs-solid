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
import Prim.Row as Row
import Solid.Internal.View (JSX, WhenValue, empty, erroredImpl, forImpl, hydrationImpl, keyedBy, keyedByIdentity, keyedByPosition, loadingImpl, matchImpl, matchMaybeImpl, noHydrationImpl, portalImpl, repeatImpl, revealImpl, showImpl, showMaybeImpl, switchImpl, whenValue)
import Solid.Internal.View as View
import Solid.Signal (Accessor)
import Web.DOM.Element (Element)

when :: Accessor Boolean -> JSX -> JSX
when condition content = runFn3 showImpl condition empty content

whenElse :: Accessor Boolean -> JSX -> JSX -> JSX
whenElse condition content fallback = runFn3 showImpl condition fallback content

toWhen :: forall a. Accessor (Maybe a) -> Accessor (Nullable (WhenValue a))
toWhen = map (maybe null (notNull <<< whenValue))

-- | The branch is created once and reads the current value through the accessor.
showMaybe :: forall a. Accessor (Maybe a) -> (Accessor a -> Setup JSX) -> JSX
showMaybe value render = showMaybeElse value render empty

showMaybeElse :: forall a. Accessor (Maybe a) -> (Accessor a -> Setup JSX) -> JSX -> JSX
showMaybeElse value render fallback = runFn4 showMaybeImpl false (toWhen value) fallback (runSetup <<< render)

-- | Re-creates the branch whenever the value changes (by identity).
showMaybeKeyed :: forall a. Accessor (Maybe a) -> (a -> Setup JSX) -> JSX
showMaybeKeyed value render = showMaybeKeyedElse value render empty

showMaybeKeyedElse :: forall a. Accessor (Maybe a) -> (a -> Setup JSX) -> JSX -> JSX
showMaybeKeyedElse value render fallback = runFn4 showMaybeImpl true (toWhen value) fallback (runSetup <<< render)

-- | Keyed by item identity (`===`): an item's view is created once and moved
-- | with the item. Use store `items` or stable values.
forEach :: forall a. Accessor (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX
forEach items render = forEachElse items render empty

forEachElse :: forall a. Accessor (Array a) -> (a -> Accessor Int -> Setup JSX) -> JSX -> JSX
forEachElse items render fallback = runFn4 forImpl keyedByIdentity items fallback (\item index -> runSetup (render item index))

-- | Keyed by position: the view at each index stays and its item accessor updates.
forEachUnkeyed :: forall a. Accessor (Array a) -> (Accessor a -> Int -> Setup JSX) -> JSX
forEachUnkeyed items render = forEachUnkeyedElse items render empty

forEachUnkeyedElse :: forall a. Accessor (Array a) -> (Accessor a -> Int -> Setup JSX) -> JSX -> JSX
forEachUnkeyedElse items render fallback = runFn4 forImpl keyedByPosition items fallback (\item index -> runSetup (render item index))

-- | Keyed by a derived key (e.g. `_.id`); the item accessor updates to the newest value.
forEachBy :: forall a k. (a -> k) -> Accessor (Array a) -> (Accessor a -> Accessor Int -> Setup JSX) -> JSX
forEachBy key items render = forEachByElse key items render empty

forEachByElse :: forall a k. (a -> k) -> Accessor (Array a) -> (Accessor a -> Accessor Int -> Setup JSX) -> JSX -> JSX
forEachByElse key items render fallback = runFn4 forImpl (keyedBy key) items fallback (\item index -> runSetup (render item index))

-- | Renders the indices `0 .. count - 1`.
repeat :: Accessor Int -> (Int -> Setup JSX) -> JSX
repeat count render = repeatElse count render empty

repeatElse :: Accessor Int -> (Int -> Setup JSX) -> JSX -> JSX
repeatElse count render fallback = runFn3 repeatImpl count fallback (runSetup <<< render)

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

-- | Shows `fallback` only on the first load; later updates keep the current
-- | content visible (use `Solid.Async.isPending` to show them).
loading :: JSX -> JSX -> JSX
loading fallback content = runFn3 loadingImpl null fallback content

-- | Like `loading`, but shows `fallback` again whenever `key` changes, e.g.
-- | the route's params, instead of keeping the previous content.
loadingOn :: forall a. Accessor a -> JSX -> JSX -> JSX
loadingOn key fallback content = runFn3 loadingImpl (notNull key) fallback content

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

dynamic :: forall props. Accessor (Component { | props }) -> { | props } -> JSX
dynamic source props = runFn2 View.dynamicImpl source props

-- | Server-rendered content that isn't hydrated.
noHydration :: JSX -> JSX
noHydration = noHydrationImpl

-- | Re-enables hydration inside `noHydration`.
hydration :: JSX -> JSX
hydration = hydrationImpl
