module Test.Start.Middleware
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Ref as Ref
import Solid.Start.Error (StartError(..))
import Solid.Start.Middleware as Middleware
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
  let request = Request.mkRequest Request.GET "/api/hello" [ "x-auth" /\ "ok" ] [] Nothing
  let postRequest =
        Request.mkRequest
          Request.POST
          "/api/hello"
          [ "x-auth" /\ "ok"
          , "x-csrf-token" /\ "csrf-123"
          , "cookie" /\ "csrf-token=csrf-123; sid=s1"
          , "x-user-id" /\ "user-123"
          ]
          []
          (Just "{}")
  let responseHandler _ = pure (Right (Response.text 200 "hello"))

  response <- expectRight
    "middleware appends headers in order"
    =<< Middleware.run
      [ Middleware.appendResponseHeader "x-first" "1"
      , Middleware.appendResponseHeader "x-second" "2"
      ]
      responseHandler
      request

  assertEqual
    "middleware onion order applies outer transform last"
    [ "content-type" /\ "text/plain; charset=utf-8"
    , "x-second" /\ "2"
    , "x-first" /\ "1"
    ]
    (Response.headers response)

  missingHeader <- Middleware.run
    [ Middleware.requireHeader "x-session" ]
    responseHandler
    request

  assertEqual
    "requireHeader short-circuits with typed middleware error"
    (Left (MiddlewareError "Missing required header: x-session"))
    missingHeader

  presentHeader <- expectRight
    "requireHeader passes request when header exists"
    =<< Middleware.run
      [ Middleware.requireHeader "x-auth" ]
      responseHandler
      request

  assertEqual "requireHeader successful response status" 200 (Response.status presentHeader)

  csrfSafe <- expectRight
    "requireCsrfToken bypasses safe methods"
    =<< Middleware.run
      [ Middleware.requireCsrfToken Middleware.defaultCsrfConfig ]
      responseHandler
      request

  assertEqual "requireCsrfToken safe-method status" 200 (Response.status csrfSafe)

  csrfSuccess <- expectRight
    "requireCsrfToken allows matching header + cookie tokens"
    =<< Middleware.run
      [ Middleware.requireCsrfToken Middleware.defaultCsrfConfig ]
      responseHandler
      postRequest

  assertEqual "requireCsrfToken successful status" 200 (Response.status csrfSuccess)

  csrfFailure <- Middleware.run
    [ Middleware.requireCsrfToken Middleware.defaultCsrfConfig ]
    responseHandler
    (Request.withHeader "x-csrf-token" "mismatch" postRequest)

  assertEqual
    "requireCsrfToken rejects mismatched token"
    (Left (MiddlewareError "Invalid CSRF token: expected matching x-csrf-token header and csrf-token cookie"))
    csrfFailure

  authenticatedRef <- Ref.new false
  unauthenticatedRef <- Ref.new false

  identityResponse <- expectRight
    "requireIdentity resolves identity, runs auth hook, and propagates identity"
    =<< Middleware.run
      [ Middleware.requireIdentity
          { resolveIdentity: \incoming -> pure (Right (Request.lookupHeader "x-user-id" incoming))
          , onAuthenticated: \identity _ ->
              if identity == "user-123" then
                Ref.write true authenticatedRef
              else
                pure unit
          , onUnauthenticated: \_ -> Ref.write true unauthenticatedRef
          }
      ]
      (\incoming ->
        pure
          ( Right
              (Response.okText ("identity=" <> show (Request.lookupHeader "x-auth-identity" incoming)))
          )
      )
      postRequest

  assertEqual
    "requireIdentity propagates identity via request header"
    (Response.TextBody "identity=(Just \"user-123\")")
    (Response.body identityResponse)

  authenticatedCalled <- Ref.read authenticatedRef
  unauthenticatedCalled <- Ref.read unauthenticatedRef
  assertEqual "requireIdentity calls onAuthenticated hook" true authenticatedCalled
  assertEqual "requireIdentity does not call onUnauthenticated hook on success" false unauthenticatedCalled

  missingIdentityRef <- Ref.new false
  missingIdentity <- Middleware.run
    [ Middleware.requireIdentity
        { resolveIdentity: \_ -> pure (Right Nothing)
        , onAuthenticated: \_ _ -> pure unit
        , onUnauthenticated: \_ -> Ref.write true missingIdentityRef
        }
    ]
    responseHandler
    request

  assertEqual
    "requireIdentity rejects missing identity"
    (Left (MiddlewareError "Missing auth identity"))
    missingIdentity

  missingIdentityCalled <- Ref.read missingIdentityRef
  assertEqual "requireIdentity calls onUnauthenticated hook" true missingIdentityCalled
