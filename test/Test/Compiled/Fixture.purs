-- | Every kind of element field, for comparing compiled templates with the
-- | runtime path (`test/compiled`).
module Test.Compiled.Fixture
  ( fixture
  , main
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import DOM.HTML.Indexed.InputType (InputType(..))
import Data.Tuple.Nested ((/\))
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM (element)
import Solid.DOM.Aria as Aria
import Solid.DOM.HTML as H
import Solid.DOM.SVG as S
import Solid.JSX (text)
import Solid.Signal (createSignal, modify_)
import Solid.Web (mountAt)
import Effect (Effect)
import Web.DOM.Element (setAttribute)
import Web.HTML.HTMLElement as HTMLElement

fixture :: Component.Component {}
fixture = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  name /\ setName <- createSignal "ada"
  done /\ setDone <- createSignal false
  items /\ _ <- createSignal [ "a", "b" ]
  let
    label = (\n -> "count " <> show n) <$> count
    odd = (\n -> n `mod` 2 == 1) <$> count
  pure $ H.main { id: "fixture", class: "shell", "data-kind": "fixture" }
    [ H.h1 { title: label, tabIndex: 2, hidden: false } [ text "Count: ", text (show <$> count) ]
    , H.button { id: "inc", type: ButtonButton, onClick: \_ -> modify_ setCount (_ + 1) } "+1"
    , H.button { disabled: odd } "disabled when odd"
    , H.p { class: { odd, even: not <$> odd, static: true } } label
    , H.p { class: label } "class from an accessor"
    , H.p { style: "padding: 1px" } "style text"
    , H.p { style: { color: (\o -> if o then "red" else "blue") <$> odd, margin: "0" } } "style record"
    , H.section { ref: \section -> setAttribute "data-ref" "yes" (HTMLElement.toElement section) } []
    , H.input { id: "name", type: InputText, bindValue: name /\ setName, placeholder: "name" }
    , H.input { id: "done", type: InputCheckbox, bindChecked: done /\ setDone }
    , H.div { innerHTML: "<b>bold</b>" } []
    , H.p { textContent: label } []
    , H.div
        { role: "status"
        , "aria-live": Aria.Polite
        , "aria-hidden": odd
        , "aria-level": 2
        , "aria-valuenow": 0.5
        , "aria-relevant": Aria.AdditionsText
        , "on:ping": \_ -> modify_ setCount (_ + 10)
        }
        "aria"
    , S.svg { viewBox: "0 0 10 10", width: "10" } (S.circle { cx: "5", cy: "5", r: "4", fill: label } [])
    , H.br {}
    , element "x-widget" { "label-text": "hi", count: 2 } [ text "custom" ]
    , H.ul {} (Control.forEach items \item _ -> pure (H.li { "data-item": item } item))
    , H.p {} [ text "a", H.b {} "b", text label, H.i {} [], text "c" ]
    , H.p {} (H.span {} "single child")
    , Control.when odd (H.em {} "odd")
    ]

main :: Effect Unit
main = mountAt "app" (Component.element fixture {})
