-- | Rows benchmark, modelled on js-framework-benchmark (keyed).
module Bench.Rows
  ( main
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
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
import Solid.DOM (classWhen)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (JSX, text)
import Solid.Setup (Setup, liftSetup)
import Solid.Signal (Accessor, Setter, createSignal, get, modify_, set)
import Solid.Store (createSelector)
import Solid.Web (render, requireElementById)

type RowItem =
  { id :: Int
  , label :: Accessor String
  , setLabel :: Setter String
  }

adjectives :: Array String
adjectives =
  [ "pretty"
  , "large"
  , "big"
  , "small"
  , "tall"
  , "short"
  , "long"
  , "handsome"
  , "plain"
  , "quaint"
  , "clean"
  , "elegant"
  , "easy"
  , "angry"
  , "crazy"
  , "helpful"
  , "mushy"
  , "odd"
  , "unsightly"
  , "adorable"
  , "important"
  , "inexpensive"
  , "cheap"
  , "expensive"
  , "fancy"
  ]

colours :: Array String
colours =
  [ "red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange" ]

nouns :: Array String
nouns =
  [ "table"
  , "chair"
  , "house"
  , "bbq"
  , "desk"
  , "car"
  , "pony"
  , "cookie"
  , "sandwich"
  , "burger"
  , "pizza"
  , "mouse"
  , "keyboard"
  ]

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
  seed <- liftSetup (Ref.new 42)
  nextId <- liftSetup (Ref.new 0)
  rows /\ setRows <- createSignal ([] :: Array RowItem)
  selected /\ setSelected <- createSignal 0
  isSelected <- createSelector show selected

  let
    replaceWith count = buildRows seed nextId count >>= set setRows

    append count = do
      fresh <- buildRows seed nextId count
      modify_ setRows (_ <> fresh)

    updateEveryTenth = do
      current <- get rows
      for_ (Array.mapWithIndex (\i row -> { i, row }) current) \{ i, row } ->
        when (i `mod` 10 == 0) do
          modify_ row.setLabel (_ <> " !!!")

    removeRow id = modify_ setRows (Array.filter (\row -> row.id /= id))

    button id label action =
      H.button [ P.id id, P.type_ ButtonButton, P.onClick \_ -> action ] [ text label ]

    renderRow :: RowItem -> Accessor Int -> Setup JSX
    renderRow row _ = pure $ H.tr [ classWhen "danger" (isSelected row.id) ]
      [ H.td [ P.class_ "col-md-1" ] [ text (show row.id) ]
      , H.td [ P.class_ "col-md-4" ] [ H.a [ P.onClick \_ -> set setSelected row.id ] [ text row.label ] ]
      , H.td [ P.class_ "col-md-1" ]
          [ H.a [ P.class_ "remove", P.onClick \_ -> removeRow row.id ] [ text "x" ] ]
      , H.td [ P.class_ "col-md-6" ] []
      ]

  pure $ H.div [ P.class_ "container" ]
    [ H.div [ P.class_ "jumbotron" ]
        [ button "run" "Create 1,000 rows" (replaceWith 1000)
        , button "runlots" "Create 10,000 rows" (replaceWith 10000)
        , button "add" "Append 1,000 rows" (append 1000)
        , button "update" "Update every 10th row" updateEveryTenth
        , button "clear" "Clear" (set setRows [])
        , button "swaprows" "Swap Rows" (modify_ setRows (swapAt 1 998))
        ]
    , H.table [ P.class_ "table" ]
        [ H.tbody [ P.id "tbody" ] [ Control.forEachByReference rows renderRow ] ]
    ]

main :: Effect Unit
main = do
  mountResult <- requireElementById "main"
  case mountResult of
    Left webError -> log ("Mount error: " <> show webError)
    Right mountNode -> do
      renderResult <- render (Component.element app {}) mountNode
      case renderResult of
        Left webError -> log ("Render error: " <> show webError)
        Right _ -> pure unit
