module Test.Server.Start
  ( spec
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), isNothing)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.Component as Component
import Solid.JSX (text)
import Solid.Start.Middleware (MiddlewareFn, middleware)
import Solid.Start.RequestEvent as Request
import Solid.Start.Response (httpHeader, httpStatus)
import Solid.Start.ServerFunction (ServerFunction, call)
import Solid.Web.SSR as SSR
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Web.Fetch.Request (Request)
import Web.Fetch.Response (Response)

foreign import echo :: ServerFunction { name :: String, tag :: Nullable String } { greeting :: String }

foreign import newRequest :: String -> String -> Effect Request
foreign import textResponse :: String -> Effect Response
foreign import responseHeader :: String -> Response -> Effect String
foreign import runMiddleware :: MiddlewareFn -> Request -> Effect (Promise Response)

-- | Runs an effect inside a request scope; returns its result and the
-- | response head the scope produced.
foreign import withRequestEventImpl
  :: forall a. Request -> Effect a -> Effect { result :: a, status :: Int, headers :: Array String }

spec :: Spec Unit
spec = describe "Solid.Start" do
  solidIt "server functions called on the server run directly" do
    result <- call echo { name: "ada", tag: notNull "x" }
    result `shouldEqual` { greeting: "hello ada (x)" }
    result' <- call echo { name: "bob", tag: null }
    result' `shouldEqual` { greeting: "hello bob" }

  solidIt "middleware wraps the rest of the chain" do
    request <- liftEffect (newRequest "https://app.test/" "")
    let
      addHeader = middleware \_ next -> do
        response <- next
        liftEffect (setHeader "x-app" "purs-solid" response)
        pure response
    response <- toAffE (runMiddleware addHeader request)
    liftEffect (responseHeader "x-app" response) >>= shouldEqual "purs-solid"

  solidIt "the request event exposes cookies, locals and sets cookies" do
    request <- liftEffect (newRequest "https://app.test/" "session=abc%20123; theme=dark")
    let userKey = Request.localKey "user" :: Request.LocalKey { name :: String }
    scoped <- liftEffect $ withRequestEventImpl request do
      event <- Request.getRequestEvent >>= maybe' (throw "no request event")
      Request.setLocal userKey { name: "ada" } event
      user <- Request.getLocal userKey event
      Request.setCookie "seen" "yes" Request.defaultCookieOptions event
      pure { session: Request.cookie "session" event, theme: Request.cookie "theme" event, user }
    scoped.result `shouldEqual` { session: Just "abc 123", theme: Just "dark", user: Just { name: "ada" } }
    scoped.headers `shouldEqual` [ "seen=yes; Path=/; HttpOnly; Secure; SameSite=Lax" ]

  solidIt "outside a request there is no request event" do
    event <- liftEffect Request.getRequestEvent
    isNothing event `shouldEqual` true

  solidIt "status and headers declared while rendering reach the response" do
    request <- liftEffect (newRequest "https://app.test/missing" "")
    let
      notFound = Component.component \_ -> do
        httpStatus 404
        httpHeader "cache-control" "no-store"
        pure (text "not found")
    scoped <- liftEffect $ withRequestEventImpl request (SSR.renderToString (Component.element notFound {}))
    render scoped.result >>= shouldEqual true
    scoped.status `shouldEqual` 404
  where
  maybe' err = case _ of
    Just event -> pure event
    Nothing -> err
  render = case _ of
    Left error -> liftEffect (throw (show error)) :: Aff Boolean
    Right _ -> pure true

foreign import setHeader :: String -> String -> Response -> Effect Unit
