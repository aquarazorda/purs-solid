module Examples.StartMode.App
  ( app
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Examples.StartMode.Api as Api
import Solid.Async (createAsyncWith, serialized)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.JSX (empty)
import Solid.Signal (createSignal, set)
import Solid.Start.ServerFunction (call)

greet :: String -> Aff String
greet = call Api.greet

app :: Component.Component {}
app = Component.component \_ -> do
  greeting /\ _ <- createAsyncWith { ssr: serialized } (pure (greet "page"))
  reply /\ setReply <- createSignal "not asked"
  pure $ H.main {}
    [ H.h1 {} "start mode"
    , Control.loading (H.p {} "loading") (H.p { id: "greeting" } greeting)
    , H.button
        { id: "ask"
        , type: ButtonButton
        , onClick: \_ -> launchAff_ (greet "button" >>= liftEffect <<< set setReply)
        }
        "ask the server"
    , H.p { id: "reply" } reply
    , Control.loading empty (Component.element footer {})
    ]

footer :: Component.Component {}
footer = Component.lazy @"Examples.StartMode.Footer.footer"
