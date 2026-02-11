module Examples.Counter where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, get, modify, set)
import Solid.Web (render, requireBody)

counterApp :: Component.Component {}
counterApp = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  step /\ setStep <- createSignal 1
  events /\ setEvents <- createSignal ([ "Ready" ] :: Array String)

  doubled <- createMemo do
    n <- get count
    pure (n * 2)

  trend <- createMemo do
    n <- get count
    pure if n == 0 then "balanced" else if n > 0 then "positive" else "negative"

  eventsEmpty <- createMemo do
    xs <- get events
    pure (Array.null xs)

  let
    appendEvent :: String -> Effect Unit
    appendEvent message = do
      _ <- modify setEvents (_ <> [ message ])
      pure unit

    addStep :: Effect Unit
    addStep = do
      s <- get step
      _ <- modify setCount (_ + s)
      _ <- appendEvent ("Incremented by " <> show s)
      pure unit

    subtractStep :: Effect Unit
    subtractStep = do
      s <- get step
      _ <- modify setCount (_ - s)
      _ <- appendEvent ("Decremented by " <> show s)
      pure unit

    resetCount :: Effect Unit
    resetCount = do
      _ <- set setCount 0
      _ <- appendEvent "Reset to zero"
      pure unit

    setPresetStep :: Int -> Effect Unit
    setPresetStep next = do
      _ <- set setStep next
      _ <- appendEvent ("Step set to " <> show next)
      pure unit

    clearEvents :: Effect Unit
    clearEvents = do
      _ <- set setEvents []
      pure unit

    renderEvent :: String -> Effect JSX
    renderEvent message = pure (HTML.li_ [ DOM.text message ])

  pure $ HTML.main { className: "counter-shell" }
    [ HTML.section { className: "counter-card" }
        [ HTML.h1_ [ DOM.text "Signal Counter" ]
        , HTML.p { className: "counter-subtitle" }
            [ DOM.text "A small example focused on signals, memos, and list rendering." ]
        , HTML.div { className: "counter-readout" }
            [ HTML.span { className: "counter-value" } [ Control.dynamicTag "strong" { children: count } ]
            , HTML.span { className: "counter-meta" }
                [ DOM.text "Doubled: "
                , Control.dynamicTag "span" { children: doubled }
                , DOM.text " | Trend: "
                , Control.dynamicTag "span" { children: trend }
                ]
            ]
        , HTML.div { className: "counter-actions" }
            [ HTML.button { onClick: Events.handler_ subtractStep } [ DOM.text "- step" ]
            , HTML.button { onClick: Events.handler_ addStep } [ DOM.text "+ step" ]
            , HTML.button { onClick: Events.handler_ resetCount } [ DOM.text "Reset" ]
            ]
        , HTML.div { className: "counter-presets" }
            [ DOM.text "Step presets:"
            , HTML.button { onClick: Events.handler_ (setPresetStep 1) } [ DOM.text "1" ]
            , HTML.button { onClick: Events.handler_ (setPresetStep 2) } [ DOM.text "2" ]
            , HTML.button { onClick: Events.handler_ (setPresetStep 5) } [ DOM.text "5" ]
            ]
        , HTML.section { className: "counter-log" }
            [ HTML.div { className: "counter-log-head" }
                [ HTML.h2_ [ DOM.text "Event log" ]
                , HTML.button { onClick: Events.handler_ clearEvents } [ DOM.text "Clear" ]
                ]
            , Control.whenElse eventsEmpty
                (HTML.p { className: "counter-empty" } [ DOM.text "No events yet." ])
                (HTML.ol_ [ Control.forEach events renderEvent ])
            ]
        ]
    ]

main :: Effect Unit
main = do
  mountResult <- requireBody
  case mountResult of
    Left webError ->
      log ("Mount error: " <> show webError)

    Right mountNode -> do
      renderResult <- render (pure (Component.element counterApp {})) mountNode
      case renderResult of
        Left webError ->
          log ("Render error: " <> show webError)
        Right _dispose ->
          pure unit
