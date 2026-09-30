-- | Error reporting hooks. Solid replaces error messages with a generic one
-- | outside the dev build before they reach the client, unless they're
-- | marked safe.
module Solid.Errors
  ( configureClientErrors
  , configureServerErrors
  , resetErrorHalt
  , markSafeError
  , isSafeError
  ) where

import Prelude

import Effect (Effect)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn1, runEffectFn1)

-- | The app-wide client hook: sees every error an `errored` boundary renders
-- | a fallback for, once per error. `Solid.Web.renderWith`'s `onError` comes first.
configureClientErrors :: (Error -> Effect Unit) -> Effect Unit
configureClientErrors = runEffectFn1 configureClientErrorsImpl

foreign import configureClientErrorsImpl :: EffectFn1 (Error -> Effect Unit) Unit

-- | The app-wide server hook: sees every error the server handles (fallbacks,
-- | rejected boundaries, server-function throws). A render's `onError` comes first.
configureServerErrors :: (Error -> Effect Unit) -> Effect Unit
configureServerErrors = runEffectFn1 configureServerErrorsImpl

foreign import configureServerErrorsImpl :: EffectFn1 (Error -> Effect Unit) Unit

-- | Restarts the reactive system after an uncaught error halted it.
foreign import resetErrorHalt :: Effect Unit

-- | Lets the error's message reach the client as is. Returns the same error.
markSafeError :: Error -> Effect Error
markSafeError = runEffectFn1 markSafeErrorImpl

foreign import markSafeErrorImpl :: EffectFn1 Error Error

isSafeError :: Error -> Effect Boolean
isSafeError = runEffectFn1 isSafeErrorImpl

foreign import isSafeErrorImpl :: EffectFn1 Error Boolean
