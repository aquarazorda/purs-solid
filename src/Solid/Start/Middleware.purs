-- | Start-mode middleware. Point `start.middleware` at a JS module that
-- | default-exports one:
-- | `export { auth as default } from "../output/App.Middleware/index.js";`
module Solid.Start.Middleware
  ( Middleware
  , MiddlewareFn
  , middleware
  ) where


import Control.Promise (Promise, fromAff, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)
import Web.Fetch.Request (Request)
import Web.Fetch.Response (Response)

-- | `next` continues down the chain.
type Middleware = Request -> Aff Response -> Aff Response

foreign import data MiddlewareFn :: Type

middleware :: Middleware -> MiddlewareFn
middleware handler = middlewareImpl \request next -> fromAff (handler request (toAffE next))

foreign import middlewareImpl :: (Request -> Effect (Promise Response) -> Effect (Promise Response)) -> MiddlewareFn
