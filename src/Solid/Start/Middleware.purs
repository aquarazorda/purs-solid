module Solid.Start.Middleware
  ( Next
  , Middleware
  , CsrfConfig
  , defaultCsrfConfig
  , AuthHooks
  , defaultAuthHooks
  , run
  , appendResponseHeader
  , requireHeader
  , requireCsrfToken
  , requireIdentity
  ) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Prelude

import Solid.Start.Error (StartError(..))
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response

type Next = Request.Request -> Effect (Either StartError Response.Response)

type Middleware =
  Request.Request
  -> Next
  -> Effect (Either StartError Response.Response)

type CsrfConfig =
  { headerName :: String
  , cookieName :: String
  , safeMethods :: Array Request.Method
  }

type AuthHooks =
  { resolveIdentity :: Request.Request -> Effect (Either StartError (Maybe String))
  , onAuthenticated :: String -> Request.Request -> Effect Unit
  , onUnauthenticated :: Request.Request -> Effect Unit
  }

defaultCsrfConfig :: CsrfConfig
defaultCsrfConfig =
  { headerName: "x-csrf-token"
  , cookieName: "csrf-token"
  , safeMethods: [ Request.GET, Request.HEAD, Request.OPTIONS ]
  }

defaultAuthHooks :: AuthHooks
defaultAuthHooks =
  { resolveIdentity: \request -> pure (Right (Request.lookupHeader "x-user-id" request))
  , onAuthenticated: \_ _ -> pure unit
  , onUnauthenticated: \_ -> pure unit
  }

run :: Array Middleware -> Next -> Next
run middlewares finalNext =
  case Array.uncons middlewares of
    Nothing -> finalNext
    Just { head: middleware, tail: remaining } ->
      \request -> middleware request (run remaining finalNext)

appendResponseHeader :: String -> String -> Middleware
appendResponseHeader key value request next = do
  result <- next request
  pure case result of
    Left startError -> Left startError
    Right response -> Right (Response.withHeader key value response)

requireHeader :: String -> Middleware
requireHeader key request next =
  case Request.lookupHeader key request of
    Just _ -> next request
    Nothing ->
      pure (Left (MiddlewareError ("Missing required header: " <> key)))

requireCsrfToken :: CsrfConfig -> Middleware
requireCsrfToken config request next =
  if isSafeMethod config.safeMethods (Request.method request) then
    next request
  else
    case Request.lookupHeader config.headerName request, Request.lookupCookie config.cookieName request of
      Just headerToken, Just cookieToken
        | headerToken == cookieToken -> next request
      _, _ ->
        pure (Left (MiddlewareError csrfFailureMessage))
  where
  csrfFailureMessage =
    "Invalid CSRF token: expected matching "
      <> config.headerName
      <> " header and "
      <> config.cookieName
      <> " cookie"

isSafeMethod :: Array Request.Method -> Request.Method -> Boolean
isSafeMethod methods current =
  Array.any (_ == current) methods

requireIdentity :: AuthHooks -> Middleware
requireIdentity hooks request next = do
  identityResult <- hooks.resolveIdentity request
  case identityResult of
    Left startError ->
      pure (Left startError)
    Right Nothing -> do
      _ <- hooks.onUnauthenticated request
      pure (Left (MiddlewareError "Missing auth identity"))
    Right (Just identity) -> do
      _ <- hooks.onAuthenticated identity request
      next (Request.withHeader "x-auth-identity" identity request)
