module Examples.Counter where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Array as Array
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.JSX (text)
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, get, modify_, set)
import Solid.Web (mount)

counterApp :: Component.Component {}
counterApp = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  step /\ setStep <- createSignal 1
  events /\ setEvents <- createSignal ([ "Ready" ] :: Array String)

  doubled <- createMemo ((_ * 2) <$> count)

  trend <- createMemo $ count <#> \n ->
    if n == 0 then "balanced" else if n > 0 then "positive" else "negative"

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

    button label action = H.button { type: ButtonButton, onClick: \_ -> action } label

  pure $ H.main { class: "counter-shell" }
    [ H.section { class: "counter-card" }
        [ H.h1 {} "Signal Counter"
        , H.p { class: "counter-subtitle" }
            [ text "A small example focused on signals, memos, and list rendering." ]
        , H.div { class: "counter-readout" }
            [ H.span { class: "counter-value" } [ H.strong {} (show <$> count) ]
            , H.span { class: "counter-meta" }
                [ text "Doubled: "
                , H.span {} (show <$> doubled)
                , text " | Trend: "
                , H.span { class: trend } trend
                ]
            ]
        , H.div { class: "counter-actions" }
            [ button "- step" subtractStep
            , button "+ step" addStep
            , button "Reset" resetCount
            ]
        , H.div { class: "counter-presets" }
            [ text "Step presets:"
            , button "1" (setPresetStep 1)
            , button "2" (setPresetStep 2)
            , button "5" (setPresetStep 5)
            ]
        , H.section { class: "counter-log" }
            [ H.div { class: "counter-log-head" }
                [ H.h2 {} "Event log"
                , button "Clear" (set setEvents [])
                ]
            , Control.whenElse ((not <<< Array.null) <$> events)
                (H.ol {} [ Control.forEachUnkeyed events \message _ -> pure (H.li {} message) ])
                (H.p { class: "counter-empty" } "No events yet.")
            ]
        ]
    ]

main :: Effect Unit
main = mount (Component.element counterApp {})
