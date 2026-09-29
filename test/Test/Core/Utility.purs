module Test.Core.Utility
  ( spec
  ) where

import Prelude

import Data.Traversable (traverse)
import Data.Tuple.Nested ((/\))
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Solid.Reactivity (withFlush)
import Solid.Root (createRoot)
import Solid.Setup (unsafeSetupEffect)
import Solid.Signal (createSignal, get, set)
import Solid.Utility (mapArray, mapArrayBy, mapArrayUnkeyed, repeat)
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Solid.Utility" do
  solidIt "mapArray maps each item once while it stays in the list" do
    calls <- liftEffect (Ref.new 0)
    result <- liftEffect do
      parts <- createRoot \_ -> do
        items /\ setItems <- createSignal [ "a", "b" ]
        mapped <- mapArray items \item _ -> do
          unsafeSetupEffect (Ref.modify_ (_ + 1) calls)
          pure ("<" <> item <> ">")
        pure { mapped, setItems }
      _ <- get parts.mapped
      withFlush (set parts.setItems [ "b", "a", "c" ])
      get parts.mapped
    result `shouldEqual` [ "<b>", "<a>", "<c>" ]
    liftEffect (Ref.read calls) >>= shouldEqual 3

  solidIt "mapArrayUnkeyed keeps one result per position" do
    calls <- liftEffect (Ref.new 0)
    liftEffect do
      parts <- createRoot \_ -> do
        items /\ setItems <- createSignal [ 1, 2 ]
        mapped <- mapArrayUnkeyed items \_ index -> do
          unsafeSetupEffect (Ref.modify_ (_ + 1) calls)
          pure index
        pure { mapped, setItems }
      _ <- get parts.mapped
      withFlush (set parts.setItems [ 10, 20 ])
      void (get parts.mapped)
    liftEffect (Ref.read calls) >>= shouldEqual 2

  solidIt "mapArrayBy reuses results for items with the same key" do
    calls <- liftEffect (Ref.new 0)
    labels <- liftEffect do
      parts <- createRoot \_ -> do
        items /\ setItems <- createSignal [ { id: 1, label: "one" } ]
        mapped <- mapArrayBy _.id items \item _ -> do
          unsafeSetupEffect (Ref.modify_ (_ + 1) calls)
          pure (_.label <$> item)
        pure { mapped, setItems }
      _ <- get parts.mapped
      withFlush (set parts.setItems [ { id: 1, label: "uno" } ])
      rows <- get parts.mapped
      traverseGet rows
    labels `shouldEqual` [ "uno" ]
    liftEffect (Ref.read calls) >>= shouldEqual 1

  solidIt "repeat maps indices" do
    result <- liftEffect do
      mapped <- createRoot \_ -> do
        count /\ _ <- createSignal 3
        repeat count (pure <<< (_ * 2))
      get mapped
    result `shouldEqual` [ 0, 2, 4 ]
  where
  traverseGet = traverse get
