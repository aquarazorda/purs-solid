module Test.Server.Start
  ( spec
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe, isNothing, maybe)
import Data.Nullable (Nullable, notNull, null, toMaybe, toNullable)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.Component as Component
import Solid.JSX (text)
import Solid.Start.Middleware (MiddlewareFn, middleware)
import Solid.Router.Query as Query
import Solid.Start.RequestEvent as Request
import Solid.Start.Response (Reply, httpHeader, httpStatus, redirectWith, reloadWith, reply, respondWith)
import Solid.Start.ServerFunction (class Serializable, ServerFunction, call, serverFunction, serverFunctionWithEvent)
import Solid.Web.SSR as SSR
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Web.Fetch.Request (Request)
import Web.Fetch.Response (Response)

echo :: ServerFunction { name :: String, tag :: Nullable String } { greeting :: String }
echo = serverFunction \{ name, tag } ->
  pure { greeting: "hello " <> name <> maybe "" (\t -> " (" <> t <> ")") (toMaybe tag) }

newtype UserId = UserId String

derive newtype instance Serializable UserId
derive newtype instance Eq UserId
derive newtype instance Show UserId

echoId :: ServerFunction UserId UserId
echoId = serverFunction pure

session :: ServerFunction String (Nullable String)
session = serverFunctionWithEvent \event name -> pure (toNullable (Request.cookie name event))

foreign import newRequest :: String -> String -> Effect Request
foreign import textResponse :: String -> Effect Response
foreign import responseHeader :: String -> Response -> Effect String
foreign import runMiddleware :: MiddlewareFn -> Request -> Effect (Promise Response)

foreign import withRequestEventImpl
  :: forall a. Request -> Effect a -> Effect { result :: a, status :: Int, headers :: Array String, trace :: String }

foreign import responseText :: Response -> Effect (Promise String)

foreign import replyInfo
  :: forall a. Reply a -> { status :: Int, location :: String, revalidate :: String, value :: Nullable a }

spec :: Spec Unit
spec = describe "Solid.Start" do
  solidIt "server functions called on the server run directly" do
    result <- call echo { name: "ada", tag: notNull "x" }
    result `shouldEqual` { greeting: "hello ada (x)" }
    result' <- call echo { name: "bob", tag: null }
    result' `shouldEqual` { greeting: "hello bob" }
    call echoId (UserId "7") >>= shouldEqual (UserId "7")

  solidIt "middleware wraps the rest of the chain" do
    request <- liftEffect (newRequest "https://app.test/" "")
    let
      addHeader = middleware \_ forwarded next -> do
        response <- next forwarded
        liftEffect (setHeader "x-app" "purs-solid" response)
        pure response
    response <- toAffE (runMiddleware addHeader request)
    liftEffect (responseHeader "x-app" response) >>= shouldEqual "purs-solid"

  solidIt "middleware can pass a rewritten request on" do
    request <- liftEffect (newRequest "https://app.test/old" "")
    let
      rewrite = middleware \_ _ next -> do
        moved <- liftEffect (newRequest "https://app.test/new" "")
        next moved
    response <- toAffE (runMiddleware rewrite request)
    toAffE (responseText response) >>= shouldEqual "ok https://app.test/new"

  solidIt "middleware and server functions get the request event" do
    request <- liftEffect (newRequest "https://app.test/" "session=abc")
    let
      check = middleware \event _ next -> do
        found <- call session "session"
        let seen = fromMaybe "" (toMaybe found) <> "-" <> fromMaybe "" (Request.cookie "session" event)
        next =<< liftEffect (newRequest ("https://app.test/" <> seen) "")
    response <- toAffE (runMiddleware check request)
    toAffE (responseText response) >>= shouldEqual "ok https://app.test/abc-abc"

  solidIt "server functions and middleware set the response status and headers" do
    request <- liftEffect (newRequest "https://app.test/" "")
    scoped <- liftEffect $ withRequestEventImpl request do
      event <- Request.getRequestEvent >>= maybe' (throw "no request event")
      Request.setResponseStatus 201 event
      Request.setResponseHeader "x-trace" "a" event
      Request.appendResponseHeader "x-trace" "b" event
      Request.deleteCookie "session" {} event
    scoped.status `shouldEqual` 201
    scoped.trace `shouldEqual` "a, b"
    scoped.headers `shouldEqual` [ "session=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT" ]

  solidIt "replies carry redirects, reloads and values" do
    replyInfo (redirectWith { status: 303 } "/done" :: Reply Int) `shouldEqual` { status: 303, location: "/done", revalidate: "", value: null }
    let todos = Query.query "todos" (\(_ :: Unit) -> pure [ "a" ])
    replyInfo (reloadWith { revalidate: [ Query.queryKey todos ] } :: Reply Int) `shouldEqual` { status: 200, location: "", revalidate: "todos[", value: null }
    replyInfo (respondWith { revalidate: [] } 7) `shouldEqual` { status: 0, location: "", revalidate: "", value: notNull 7 }
    replyInfo (reply 7) `shouldEqual` { status: 0, location: "", revalidate: "", value: notNull 7 }

  solidIt "the request event exposes cookies, locals and sets cookies" do
    request <- liftEffect (newRequest "https://app.test/" "session=abc%20123; theme=dark")
    let userKey = Request.localKey "user" :: Request.LocalKey { name :: String }
    scoped <- liftEffect $ withRequestEventImpl request do
      event <- Request.getRequestEvent >>= maybe' (throw "no request event")
      Request.setLocal userKey { name: "ada" } event
      user <- Request.getLocal userKey event
      Request.setCookie "seen" "yes" {} event
      Request.setCookie "pref" "1" { maxAge: 60, httpOnly: false, sameSite: Request.strict } event
      pure { session: Request.cookie "session" event, theme: Request.cookie "theme" event, user }
    scoped.result `shouldEqual` { session: Just "abc 123", theme: Just "dark", user: Just { name: "ada" } }
    scoped.headers `shouldEqual`
      [ "seen=yes; Path=/; HttpOnly; Secure; SameSite=Lax"
      , "pref=1; Path=/; Max-Age=60; Secure; SameSite=Strict"
      ]

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
