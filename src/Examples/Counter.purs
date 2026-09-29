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
import Solid.Setup (Setup)
import Solid.Signal (createSignal, get, modify_, set)
import Solid.Web (render, requireBody)

counterApp :: Component.Component {}
counterApp = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  step /\ setStep <- createSignal 1
  events /\ setEvents <- createSignal ([ "Ready" ] :: Array String)

  doubled <- createMemo ((_ * 2) <$> count)

  trend <- createMemo $ count <#> \n ->
    if n == 0 then "balanced" else if n > 0 then "positive" else "negative"

  eventsEmpty <- createMemo (Array.null <$> events)

  let
    appendEvent :: String -> Effect Unit
    appendEvent message = modify_ setEvents (_ <> [ message ])

    addStep :: Effect Unit
    addStep = do
      s <- get step
      modify_ setCount (_ + s)
      appendEvent ("Incremented by " <> show s)

    subtractStep :: Effect Unit
    subtractStep = do
      s <- get step
      modify_ setCount (_ - s)
      appendEvent ("Decremented by " <> show s)

    resetCount :: Effect Unit
    resetCount = do
      set setCount 0
      appendEvent "Reset to zero"

    setPresetStep :: Int -> Effect Unit
    setPresetStep next = do
      set setStep next
      appendEvent ("Step set to " <> show next)

    clearEvents :: Effect Unit
    clearEvents = set setEvents []

    renderEvent :: String -> Setup JSX
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
