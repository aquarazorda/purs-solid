module Test.AdvancedUtility
  ( run
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Exception (throw)
import Solid.Root (createRoot)
import Solid.Signal (createSignal, get, set)
import Solid.Utility as Utility
import Test.Assert (assertEqual)

run :: Effect Unit
run = do
  safeValue <- Utility.catchError (pure 10) \_ -> pure unit
  assertEqual "catchError leaves successful computation untouched" (Just 10) safeValue

  recoveredValue <- Utility.catchError (throw "boom") \message ->
    if message == "boom" then
      pure unit
    else
      throw "catchError normalized message mismatch"
  assertEqual "catchError reports errors as Nothing" (Nothing :: Maybe Int) recoveredValue

  fixture <- createRoot \dispose -> do
    source /\ setSource <- createSignal [ 1, 2 ]

    mapped <- Utility.mapArray source \value indexAccessor -> do
      index <- get indexAccessor
      pure (show index <> ":" <> show value)

    indexed <- Utility.indexArray source \valueAccessor index -> do
      value <- get valueAccessor
      pure (show index <> ":" <> show value)

    streamed <- Utility.from \push -> do
      _ <- push 9
      pure (pure unit)

    streamedWithInitial <- Utility.fromWithInitial 7 \_ ->
      pure (pure unit)

    _observable <- Utility.observable source

    transitionPending /\ startTransition <- Utility.useTransition

    pure
      { mapped
      , indexed
      , streamed
      , streamedWithInitial
      , source
      , setSource
      , transitionPending
      , startTransition
      , dispose
      }

  mappedInitial <- get fixture.mapped
  assertEqual "mapArray maps with reactive index accessor" [ "0:1", "1:2" ] mappedInitial

  indexedInitial <- get fixture.indexed
  assertEqual "indexArray maps with stable index" [ "0:1", "1:2" ] indexedInitial

  streamedValue <- get fixture.streamed
  assertEqual "from converts producer stream to maybe accessor" (Just 9) streamedValue

  streamedInitialValue <- get fixture.streamedWithInitial
  assertEqual "fromWithInitial exposes initial value" 7 streamedInitialValue

  _ <- set fixture.setSource [ 3, 4, 5 ]

  mappedUpdated <- get fixture.mapped
  assertEqual "mapArray updates mapped projection after source updates" [ "0:3", "1:4", "2:5" ] mappedUpdated

  indexedUpdated <- get fixture.indexed
  assertEqual
    "indexArray preserves prior mapped values when map callback is non-reactive"
    [ "0:1", "1:2", "2:5" ]
    indexedUpdated

  _ <- Utility.startTransition (pure unit)
  _ <- fixture.startTransition (pure unit)
  _ <- get fixture.transitionPending

  let
    mergedTwo =
      Utility.mergeProps2
        { left: 1
        , shared: 2
        }
        { shared: 9
        , right: 3
        }
        ::
          { left :: Int
          , shared :: Int
          , right :: Int
          }

    mergedThree =
      Utility.mergeProps3
        { alpha: "a" }
        { beta: "b" }
        { gamma: "c" }
        ::
          { alpha :: String
          , beta :: String
          , gamma :: String
          }

    mergedMany =
      Utility.mergePropsMany
        [ { shared: 2
          , left: 1
          , right: 0
          }
        , { shared: 4
          , left: 9
          , right: 2
          }
        ]
        ::
          { shared :: Int
          , left :: Int
          , right :: Int
          }

    split =
      Utility.splitProps
        { a: 1
        , b: 2
        , c: 3
        }
        [ "a", "c" ]
        :: Utility.SplitResult
            { a :: Int
            , c :: Int
            }
            { b :: Int }

  assertEqual "mergeProps2 applies right-side override" 9 mergedTwo.shared
  assertEqual "mergeProps3 keeps all input objects" "c" mergedThree.gamma
  assertEqual "mergePropsMany merges array of prop objects" 4 mergedMany.shared
  assertEqual "splitProps picks requested keys" 1 split.picked.a
  assertEqual "splitProps omits requested keys" 2 split.omitted.b

  fixture.dispose
