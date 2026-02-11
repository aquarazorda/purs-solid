module Test.Start.Session
  ( run
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect)
import Solid.Start.Error (StartError(..))
import Solid.Start.Server.Request as Request
import Solid.Start.Server.Response as Response
import Solid.Start.Session as Session
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
  let session = Session.withValue "role" "admin" Session.emptySession
  assertEqual "lookupValue finds inserted session key" (Just "admin") (Session.lookupValue "role" session)

  store <- Session.createInMemoryStore
  initialRead <- store.read "s1"
  assertEqual "empty in-memory store returns Nothing" (Right Nothing) initialRead

  _ <- store.write "s1" session

  writtenRead <- store.read "s1"
  assertEqual "in-memory store returns written session" (Right (Just session)) writtenRead

  _ <- store.delete "s1"

  deletedRead <- store.read "s1"
  assertEqual "in-memory store deletes session" (Right Nothing) deletedRead

  let cookieAdapter = Session.createCookieSessionAdapter Session.defaultCookieSessionConfig

  decodedSession <- cookieAdapter.readFromRequest
    (Request.mkRequest Request.GET "/" [ "cookie" /\ "sid=role=admin&theme=dark" ] [] Nothing)
  assertEqual
    "cookie adapter decodes session from cookie"
    (Right (Session.withValue "theme" "dark" (Session.withValue "role" "admin" Session.emptySession)))
    decodedSession

  encodedResponse <- expectRight
    "cookie adapter write should not fail"
    =<< cookieAdapter.writeToResponse session (Response.okText "ok")
  assertEqual
    "cookie adapter writes set-cookie header"
    (Just "sid=role=admin; Path=/; SameSite=Lax; HttpOnly")
    (lookupHeader "set-cookie" (Response.headers encodedResponse))

  clearedResponse <- expectRight
    "cookie adapter clear should not fail"
    =<< cookieAdapter.clearInResponse (Response.okText "ok")
  assertEqual
    "cookie adapter clearing writes Max-Age=0"
    (Just "sid=; Path=/; SameSite=Lax; HttpOnly; Max-Age=0")
    (lookupHeader "set-cookie" (Response.headers clearedResponse))

  assertEqual
    "encodeSessionToken serializes session values"
    "role=admin"
    (Session.encodeSessionToken session)

  assertEqual
    "decodeSessionToken maps malformed payload to SessionError"
    (Left (SessionError "Session cookie key cannot be empty"))
    (Session.decodeSessionToken "=broken")

lookupHeader :: String -> Array (String /\ String) -> Maybe String
lookupHeader key pairs =
  case Array.uncons pairs of
    Nothing -> Nothing
    Just { head: currentKey /\ value, tail: rest } ->
      if currentKey == key then
        Just value
      else
        lookupHeader key rest
