module Test.Core.Async
  ( spec
  ) where

import Prelude

import Data.Either (isLeft)
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff, Milliseconds(..), delay, error, forkAff, joinFiber, killFiber, throwError, try)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Solid.Async (createAsync, isPending, refreshAff, resolve, until, untilWith)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, set)
import Test.Solid (settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

fetchUser :: Ref.Ref (Array Int) -> Int -> Aff String
fetchUser finished id = do
  delay (Milliseconds 20.0)
  liftEffect (Ref.modify_ (_ <> [ id ]) finished)
  pure ("user-" <> show id)

spec :: Spec Unit
spec = describe "Solid.Async" do
  solidIt "createAsync runs the Aff and resolves with its value" do
    finished <- liftEffect (Ref.new [])
    user <- liftEffect $ createRoot \_ -> do
      userId /\ _ <- createSignal 1
      user /\ _ <- createAsync (fetchUser finished <$> userId)
      pure user
    resolve user >>= shouldEqual "user-1"

  solidIt "superseded requests are cancelled, not just ignored" do
    finished <- liftEffect (Ref.new [])
    parts <- liftEffect $ createRoot \_ -> do
      userId /\ setUserId <- createSignal 1
      user /\ _ <- createAsync (fetchUser finished <$> userId)
      pure { user, setUserId }
    delay (Milliseconds 5.0)
    liftEffect (set parts.setUserId 2)
    delay (Milliseconds 5.0)
    liftEffect (set parts.setUserId 3)
    resolve parts.user >>= shouldEqual "user-3"
    delay (Milliseconds 40.0)
    liftEffect (Ref.read finished) >>= shouldEqual [ 3 ]

  solidIt "isPending is true while a change is in flight" do
    finished <- liftEffect (Ref.new [])
    parts <- liftEffect $ createRoot \_ -> do
      userId /\ setUserId <- createSignal 1
      user /\ _ <- createAsync (fetchUser finished <$> userId)
      pure { user, setUserId }
    _ <- resolve parts.user
    liftEffect (set parts.setUserId 2)
    settle
    pendingDuring <- liftEffect (get (isPending parts.user))
    _ <- resolve parts.user
    delay (Milliseconds 30.0)
    pendingAfter <- liftEffect (get (isPending parts.user))
    { pendingDuring, pendingAfter } `shouldEqual` { pendingDuring: true, pendingAfter: false }

  solidIt "refreshAff re-runs the work with unchanged inputs" do
    finished <- liftEffect (Ref.new [])
    parts <- liftEffect $ createRoot \_ -> do
      userId /\ _ <- createSignal 7
      user /\ refreshUser <- createAsync (fetchUser finished <$> userId)
      pure { user, refreshUser }
    _ <- resolve parts.user
    _ <- refreshAff parts.refreshUser
    liftEffect (Ref.read finished) >>= shouldEqual [ 7, 7 ]

  solidIt "a failing Aff rejects resolve" do
    user <- liftEffect $ createRoot \_ -> do
      trigger /\ _ <- createSignal unit
      user /\ _ <- createAsync (trigger $> (throwError (error "offline") :: Aff String))
      pure user
    result <- try (resolve user)
    isLeft result `shouldEqual` true

  solidIt "until waits for the predicate to hold" do
    count /\ setCount <- liftEffect (createSignal 0)
    waiting <- forkAff (until ((\n -> if n > 2 then Just n else Nothing) <$> count))
    liftEffect (set setCount 1)
    settle
    liftEffect (set setCount 3)
    joinFiber waiting >>= shouldEqual 3

  solidIt "until fails after its timeout" do
    result <- try (untilWith { timeout: Milliseconds 10.0 } (pure (Nothing :: Maybe Int)))
    isLeft result `shouldEqual` true

  solidIt "killing an until fiber stops waiting" do
    count /\ setCount <- liftEffect (createSignal 0)
    waiting <- forkAff (until ((\n -> if n > 0 then Just n else Nothing) <$> count))
    killFiber (error "no longer needed") waiting
    liftEffect (set setCount 1)
    settle
    result <- try (joinFiber waiting)
    isLeft result `shouldEqual` true
