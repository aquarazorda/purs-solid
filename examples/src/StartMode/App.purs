module Examples.StartMode.App
  ( app
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Solid.Async (createAsyncWith, defaultAsyncOptions, serialized)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (text)
import Solid.Signal (createSignal, set)
import Solid.Start.ServerFunction (ServerFunction, call)

foreign import greetOnServer :: ServerFunction String String

greet :: String -> Aff String
greet = call greetOnServer

app :: Component.Component {}
app = Component.component \_ -> do
  greeting /\ _ <- createAsyncWith (defaultAsyncOptions { ssr = serialized }) (pure (greet "page"))
  reply /\ setReply <- createSignal "not asked"
  pure $ H.main_
    [ H.h1_ [ text "start mode" ]
    , Control.loading (H.p_ [ text "loading" ]) (H.p [ P.id "greeting" ] [ text greeting ])
    , H.button
        [ P.id "ask"
        , P.type_ ButtonButton
        , P.onClick \_ -> launchAff_ (greet "button" >>= liftEffect <<< set setReply)
        ]
        [ text "ask the server" ]
    , H.p [ P.id "reply" ] [ text reply ]
    ]
