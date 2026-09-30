-- | Mounting views in the browser.
module Solid.Web
  ( isServer
  , render
  , hydrate
  , requireBody
  , requireElementById
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (maybe)
import Effect (Effect)
import Effect.Exception (Error, error, throw, try)
import Effect.Uncurried (EffectFn3, runEffectFn3)
import Solid.Internal.View (JSX, Realized, realize)
import Web.DOM.Element (Element)
import Web.DOM.NonElementParentNode (getElementById)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLElement as HTMLElement
import Web.HTML.Window (document)

foreign import isServer :: Boolean

-- | Appends the view to `mount`'s children. The result disposes it.
render :: JSX -> Element -> Effect (Either Error (Effect Unit))
render view mount = clientOnly (runEffectFn3 renderImpl realize view mount)

hydrate :: JSX -> Element -> Effect (Either Error (Effect Unit))
hydrate view mount = clientOnly (runEffectFn3 hydrateImpl realize view mount)

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

foreign import renderImpl :: EffectFn3 (JSX -> Realized) JSX Element (Effect Unit)
foreign import hydrateImpl :: EffectFn3 (JSX -> Realized) JSX Element (Effect Unit)
