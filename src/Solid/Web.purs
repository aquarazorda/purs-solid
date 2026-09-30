-- | Mounting views in the browser.
module Solid.Web
  ( isServer
  , ClientRenderOptions
  , render
  , renderWith
  , hydrate
  , hydrateWith
  , requireBody
  , requireElementById
  , mount
  , mountAt
  , hydrateAt
  ) where

import Prelude

import Data.Either (Either(..), either)
import Data.Maybe (maybe)
import Effect (Effect)
import Effect.Exception (Error, error, throw, throwException, try)
import Effect.Uncurried (EffectFn4, runEffectFn4)
import Prim.Row as Row
import Solid.Owner (Owner)
import Solid.Internal.View (JSX, Realized, realize)
import Web.DOM.Element (Element)
import Web.DOM.NonElementParentNode (getElementById)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLElement as HTMLElement
import Web.HTML.Window (document)

foreign import isServer :: Boolean

type ClientRenderOptions =
  ( -- | Sees every error an `errored` boundary under this root renders a
    -- | fallback for, once per error.
    onError :: Error -> Effect Unit
  -- | Distinguishes several independently hydrated roots on one page.
  , renderId :: String
  -- | Parent the root under an existing owner.
  , owner :: Owner
  )

-- | Appends the view to `mount`'s children. The result disposes it.
render :: JSX -> Element -> Effect (Either Error (Effect Unit))
render = renderWith {}

-- | Takes any subset of `ClientRenderOptions`.
renderWith
  :: forall given missing
   . Row.Union given missing ClientRenderOptions
  => { | given }
  -> JSX
  -> Element
  -> Effect (Either Error (Effect Unit))
renderWith options view mount = clientOnly (runEffectFn4 renderImpl realize options view mount)

hydrate :: JSX -> Element -> Effect (Either Error (Effect Unit))
hydrate = hydrateWith {}

hydrateWith
  :: forall given missing
   . Row.Union given missing ClientRenderOptions
  => { | given }
  -> JSX
  -> Element
  -> Effect (Either Error (Effect Unit))
hydrateWith options view mount = clientOnly (runEffectFn4 hydrateImpl realize options view mount)

requireBody :: Effect (Either Error Element)
requireBody = clientOnly do
  body <- HTMLDocument.body =<< document =<< window
  maybe (throw "document.body is missing") (pure <<< HTMLElement.toElement) body

requireElementById :: String -> Effect (Either Error Element)
requireElementById id = clientOnly do
  found <- getElementById id <<< HTMLDocument.toNonElementParentNode =<< document =<< window
  maybe (throw ("no element with id " <> show id)) pure found

clientOnly :: forall a. Effect a -> Effect (Either Error a)
clientOnly action
  | isServer = pure (Left (error "Solid.Web: client-only API called on the server"))
  | otherwise = try action

foreign import renderImpl :: forall options. EffectFn4 (JSX -> Realized) { | options } JSX Element (Effect Unit)
foreign import hydrateImpl :: forall options. EffectFn4 (JSX -> Realized) { | options } JSX Element (Effect Unit)

-- | Renders `view` into `document.body`, for an app's `main`. Throws if that
-- | fails; `render` returns the error and a way to unmount instead.
mount :: JSX -> Effect Unit
mount view = void (requireBody >>= rethrow >>= render view >>= rethrow)

-- | `mount` into the element with the given id.
mountAt :: String -> JSX -> Effect Unit
mountAt id view = void (requireElementById id >>= rethrow >>= render view >>= rethrow)

-- | Hydrates the server-rendered element with the given id. Throws if that
-- | fails.
hydrateAt :: String -> JSX -> Effect Unit
hydrateAt id view = void (requireElementById id >>= rethrow >>= hydrate view >>= rethrow)

rethrow :: forall a. Either Error a -> Effect a
rethrow = either throwException pure
