module Solid.Control
  ( when
  , whenKeyed
  , whenElse
  , whenElseKeyed
  , showMaybe
  , showMaybeElse
  , showMaybeKeyed
  , showMaybeKeyedElse
  , forEach
  , forEachElse
  , forEachWithIndex
  , forEachWithIndexElse
  , indexEach
  , indexEachElse
  , matchWhen
  , matchWhenKeyed
  , matchMaybe
  , switchCases
  , switchCasesElse
  , dynamicTag
  , dynamicComponent
  , errorBoundary
  , errorBoundaryWith
  , noHydration
  , suspense
  , SuspenseRevealOrder(..)
  , SuspenseTail(..)
  , SuspenseListOptions
  , defaultSuspenseListOptions
  , suspenseList
  , suspenseListWith
  , PortalOptions
  , defaultPortalOptions
  , portal
  , portalWith
  , portalAt
  ) where

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Prelude hiding (when)

import Solid.Component (Component)
import Solid.JSX (JSX, empty)
import Solid.Signal (Accessor)
import Solid.Web (Mountable)

when :: Accessor Boolean -> JSX -> JSX
when condition content = whenElse condition empty content

foreign import whenElseImpl :: Accessor Boolean -> JSX -> JSX -> JSX

whenElse :: Accessor Boolean -> JSX -> JSX -> JSX
whenElse = whenElseImpl

whenKeyed :: Accessor Boolean -> JSX -> JSX
whenKeyed condition content = whenElseKeyed condition empty content

foreign import whenElseKeyedImpl :: Accessor Boolean -> JSX -> JSX -> JSX

whenElseKeyed :: Accessor Boolean -> JSX -> JSX -> JSX
whenElseKeyed = whenElseKeyedImpl

showMaybe :: forall a. Accessor (Maybe a) -> (Accessor a -> Effect JSX) -> JSX
showMaybe condition render = showMaybeElse condition empty render

foreign import showMaybeElseImpl :: forall a. Accessor (Maybe a) -> JSX -> (Accessor a -> Effect JSX) -> JSX

showMaybeElse :: forall a. Accessor (Maybe a) -> JSX -> (Accessor a -> Effect JSX) -> JSX
showMaybeElse = showMaybeElseImpl

showMaybeKeyed :: forall a. Accessor (Maybe a) -> (a -> Effect JSX) -> JSX
showMaybeKeyed condition render = showMaybeKeyedElse condition empty render

foreign import showMaybeKeyedElseImpl :: forall a. Accessor (Maybe a) -> JSX -> (a -> Effect JSX) -> JSX

showMaybeKeyedElse :: forall a. Accessor (Maybe a) -> JSX -> (a -> Effect JSX) -> JSX
showMaybeKeyedElse = showMaybeKeyedElseImpl

forEach :: forall a. Accessor (Array a) -> (a -> Effect JSX) -> JSX
forEach each render = forEachElse each empty render

foreign import forEachElseImpl :: forall a. Accessor (Array a) -> JSX -> (a -> Effect JSX) -> JSX

forEachElse :: forall a. Accessor (Array a) -> JSX -> (a -> Effect JSX) -> JSX
forEachElse = forEachElseImpl

forEachWithIndex
  :: forall a
   . Accessor (Array a)
  -> (a -> Accessor Int -> Effect JSX)
  -> JSX
forEachWithIndex each render = forEachWithIndexElse each empty render

foreign import forEachWithIndexElseImpl
  :: forall a
   . Accessor (Array a)
  -> JSX
  -> (a -> Accessor Int -> Effect JSX)
  -> JSX

forEachWithIndexElse
  :: forall a
   . Accessor (Array a)
  -> JSX
  -> (a -> Accessor Int -> Effect JSX)
  -> JSX
forEachWithIndexElse = forEachWithIndexElseImpl

indexEach :: forall a. Accessor (Array a) -> (Accessor a -> Effect JSX) -> JSX
indexEach each render = indexEachElse each empty render

foreign import indexEachElseImpl :: forall a. Accessor (Array a) -> JSX -> (Accessor a -> Effect JSX) -> JSX

indexEachElse :: forall a. Accessor (Array a) -> JSX -> (Accessor a -> Effect JSX) -> JSX
indexEachElse = indexEachElseImpl

foreign import matchWhen :: Accessor Boolean -> JSX -> JSX

foreign import matchWhenKeyed :: Accessor Boolean -> JSX -> JSX

foreign import matchMaybe :: forall a. Accessor (Maybe a) -> (a -> Effect JSX) -> JSX

switchCases :: Array JSX -> JSX
switchCases = switchCasesElse empty

foreign import switchCasesElseImpl :: JSX -> Array JSX -> JSX

switchCasesElse :: JSX -> Array JSX -> JSX
switchCasesElse = switchCasesElseImpl

foreign import dynamicTag
  :: forall props
   . String
  -> { | props }
  -> JSX

foreign import dynamicComponent
  :: forall props
   . Component { | props }
  -> { | props }
  -> JSX

foreign import errorBoundaryImpl :: JSX -> JSX -> JSX

errorBoundary :: JSX -> JSX -> JSX
errorBoundary = errorBoundaryImpl

foreign import errorBoundaryWithImpl :: (String -> Effect Unit -> Effect JSX) -> JSX -> JSX

errorBoundaryWith :: (String -> Effect Unit -> Effect JSX) -> JSX -> JSX
errorBoundaryWith = errorBoundaryWithImpl

foreign import noHydrationImpl :: JSX -> JSX

noHydration :: JSX -> JSX
noHydration = noHydrationImpl

foreign import suspenseImpl :: JSX -> JSX -> JSX

suspense :: JSX -> JSX -> JSX
suspense = suspenseImpl

data SuspenseRevealOrder
  = Forwards
  | Backwards
  | Together

derive instance eqSuspenseRevealOrder :: Eq SuspenseRevealOrder

instance showSuspenseRevealOrder :: Show SuspenseRevealOrder where
  show = case _ of
    Forwards -> "Forwards"
    Backwards -> "Backwards"
    Together -> "Together"

data SuspenseTail
  = Collapsed
  | Hidden

derive instance eqSuspenseTail :: Eq SuspenseTail

instance showSuspenseTail :: Show SuspenseTail where
  show = case _ of
    Collapsed -> "Collapsed"
    Hidden -> "Hidden"

type SuspenseListOptions =
  { revealOrder :: SuspenseRevealOrder
  , tail :: Maybe SuspenseTail
  }

defaultSuspenseListOptions :: SuspenseListOptions
defaultSuspenseListOptions =
  { revealOrder: Forwards
  , tail: Nothing
  }

suspenseList :: SuspenseRevealOrder -> Array JSX -> JSX
suspenseList revealOrder children =
  suspenseListWith
    (defaultSuspenseListOptions { revealOrder = revealOrder })
    children

foreign import suspenseListImpl :: String -> Maybe String -> Array JSX -> JSX

suspenseListWith :: SuspenseListOptions -> Array JSX -> JSX
suspenseListWith options children =
  suspenseListImpl
    (toRevealOrderTag options.revealOrder)
    (toTailTag <$> options.tail)
    children

toRevealOrderTag :: SuspenseRevealOrder -> String
toRevealOrderTag = case _ of
  Forwards -> "forwards"
  Backwards -> "backwards"
  Together -> "together"

toTailTag :: SuspenseTail -> String
toTailTag = case _ of
  Collapsed -> "collapsed"
  Hidden -> "hidden"

type PortalOptions =
  { mount :: Maybe Mountable
  , useShadow :: Boolean
  , isSVG :: Boolean
  }

defaultPortalOptions :: PortalOptions
defaultPortalOptions =
  { mount: Nothing
  , useShadow: false
  , isSVG: false
  }

portal :: JSX -> JSX
portal = portalWith defaultPortalOptions

foreign import portalWithImpl :: Maybe Mountable -> Boolean -> Boolean -> JSX -> JSX

portalWith :: PortalOptions -> JSX -> JSX
portalWith options content =
  portalWithImpl options.mount options.useShadow options.isSVG content

portalAt :: Maybe Mountable -> JSX -> JSX
portalAt maybeMount content =
  portalWith
    (defaultPortalOptions { mount = maybeMount })
    content
