module Solid.Control
  ( when
  , whenElse
  , forEach
  , forEachElse
  , forEachWithIndex
  , forEachWithIndexElse
  , indexEach
  , indexEachElse
  , matchWhen
  , matchWhenKeyed
  , switchCases
  , switchCasesElse
  , dynamicTag
  , dynamicComponent
  , portal
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

portal :: JSX -> JSX
portal = portalAt Nothing

foreign import portalAtImpl :: Maybe Mountable -> JSX -> JSX

portalAt :: Maybe Mountable -> JSX -> JSX
portalAt = portalAtImpl
