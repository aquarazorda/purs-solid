-- | Rows benchmark, modelled on js-framework-benchmark (keyed).
-- |
-- | Written against the public API only, the way an application would use it,
-- | so the numbers track what users get. Driven by `test/bench/run-bench.mjs`.
module Bench.Rows
  ( main
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (fromMaybe)
import Data.Traversable (for_, traverse)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Effect.Ref as Ref
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Signal (Accessor, Setter, createSignal, get, modify, set)
import Solid.Utility (batch)
import Solid.Web (render, requireMountById)

type RowItem =
  { id :: Int
  , label :: Accessor String
  , setLabel :: Setter String
  }

adjectives :: Array String
adjectives =
  [ "pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint"
  , "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly"
  , "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"
  ]

colours :: Array String
colours =
  [ "red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange" ]

nouns :: Array String
nouns =
  [ "table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger"
  , "pizza", "mouse", "keyboard"
  ]

-- | Deterministic pseudo-random index so every run renders the same labels.
nextIndex :: Ref.Ref Int -> Int -> Effect Int
nextIndex seed bound = do
  current <- Ref.modify (\s -> (s * 75 + 74) `mod` 65537) seed
  pure (current `mod` bound)

pick :: Ref.Ref Int -> Array String -> Effect String
pick seed words = do
  index <- nextIndex seed (Array.length words)
  pure (fromMaybe "" (Array.index words index))

buildRows :: Ref.Ref Int -> Ref.Ref Int -> Int -> Effect (Array RowItem)
buildRows seed nextId count =
  traverse (const buildRow) (Array.range 1 count)
  where
  buildRow = do
    id <- Ref.modify (_ + 1) nextId
    adjective <- pick seed adjectives
    colour <- pick seed colours
    noun <- pick seed nouns
    label /\ setLabel <- createSignal (adjective <> " " <> colour <> " " <> noun)
    pure { id, label, setLabel }

swapAt :: Int -> Int -> Array RowItem -> Array RowItem
swapAt i j rows = fromMaybe rows do
  a <- Array.index rows i
  b <- Array.index rows j
  Array.updateAt i b rows >>= Array.updateAt j a

app :: Component.Component {}
app = Component.component \_ -> do
  seed <- Ref.new 42
  nextId <- Ref.new 0
  rows /\ setRows <- createSignal ([] :: Array RowItem)
  probe /\ _ <- createSignal "reactive-ok"

  let
    replaceWith count = do
      fresh <- buildRows seed nextId count
      void (set setRows fresh)

    append count = do
      fresh <- buildRows seed nextId count
      void (modify setRows (_ <> fresh))

    updateEveryTenth = do
      current <- get rows
      batch do
        for_ (Array.mapWithIndex (\i row -> { i, row }) current) \{ i, row } ->
          when (i `mod` 10 == 0) do
            void (modify row.setLabel (_ <> " !!!"))

    removeRow id =
      void (modify setRows (Array.filter (\row -> row.id /= id)))

    button id label action =
      HTML.button { id, type: "button", onClick: Events.handler_ action } [ DOM.text label ]

    renderRow :: RowItem -> Effect JSX
    renderRow row = pure $ HTML.tr_
      [ HTML.td { className: "col-md-1" } [ DOM.text (show row.id) ]
      , HTML.td { className: "col-md-4" } [ Control.dynamicTag "a" { children: row.label } ]
      , HTML.td { className: "col-md-1" }
          [ HTML.a { className: "remove", onClick: Events.handler_ (removeRow row.id) } [ DOM.text "x" ] ]
      , HTML.td { className: "col-md-6" } []
      ]

  pure $ HTML.div { className: "container" }
    [ HTML.div { className: "jumbotron" }
        [ button "run" "Create 1,000 rows" (replaceWith 1000)
        , button "runlots" "Create 10,000 rows" (replaceWith 10000)
        , button "add" "Append 1,000 rows" (append 1000)
        , button "update" "Update every 10th row" updateEveryTenth
        , button "clear" "Clear" (void (set setRows []))
        , button "swaprows" "Swap Rows" (void (modify setRows (swapAt 1 998)))
        ]
    -- Probe: is an Accessor passed as an attribute value applied reactively?
    , HTML.input { id: "reactive-attr-probe", value: probe } []
    , HTML.table { className: "table" }
        [ HTML.tbody { id: "tbody" } [ Control.forEach rows renderRow ] ]
    ]

main :: Effect Unit
main = do
  mountResult <- requireMountById "main"
  case mountResult of
    Left webError -> log ("Mount error: " <> show webError)
    Right mountNode -> do
      renderResult <- render (pure (Component.element app {})) mountNode
      case renderResult of
        Left webError -> log ("Render error: " <> show webError)
        Right _ -> pure unit
