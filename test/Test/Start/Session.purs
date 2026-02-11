module Test.Start.Session
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.Start.Session as Session
import Test.Assert (assertEqual)

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
