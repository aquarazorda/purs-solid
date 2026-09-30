module Examples.Counter where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Array as Array
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
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

    button label action = H.button [ P.type_ ButtonButton, P.onClick \_ -> action ] [ text label ]

  pure $ H.main [ P.class_ "counter-shell" ]
    [ H.section [ P.class_ "counter-card" ]
        [ H.h1_ [ text "Signal Counter" ]
        , H.p [ P.class_ "counter-subtitle" ]
            [ text "A small example focused on signals, memos, and list rendering." ]
        , H.div [ P.class_ "counter-readout" ]
            [ H.span [ P.class_ "counter-value" ] [ H.strong_ [ text (show <$> count) ] ]
            , H.span [ P.class_ "counter-meta" ]
                [ text "Doubled: "
                , H.span_ [ text (show <$> doubled) ]
                , text " | Trend: "
                , H.span [ P.class_ trend ] [ text trend ]
                ]
            ]
        , H.div [ P.class_ "counter-actions" ]
            [ button "- step" subtractStep
            , button "+ step" addStep
            , button "Reset" resetCount
            ]
        , H.div [ P.class_ "counter-presets" ]
            [ text "Step presets:"
            , button "1" (setPresetStep 1)
            , button "2" (setPresetStep 2)
            , button "5" (setPresetStep 5)
            ]
        , H.section [ P.class_ "counter-log" ]
            [ H.div [ P.class_ "counter-log-head" ]
                [ H.h2_ [ text "Event log" ]
                , button "Clear" (set setEvents [])
                ]
            , Control.whenElse ((not <<< Array.null) <$> events)
                (H.ol_ [ Control.forEachUnkeyed events \message _ -> pure (H.li_ [ text message ]) ])
                (H.p [ P.class_ "counter-empty" ] [ text "No events yet." ])
            ]
        ]
    ]

main :: Effect Unit
main = mount (Component.element counterApp {})
