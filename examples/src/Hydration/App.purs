module Examples.Hydration.App
  ( app
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff, Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Effect (Effect)
import Solid.Async (createAsyncWith, serialized)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.DOM.SVG as S
import Solid.JSX (JSX, text)
import Solid.Signal (createSignal, modify_)

fetchGreeting :: Effect Unit -> Aff String
fetchGreeting onFetch = do
  liftEffect onFetch
  delay (Milliseconds 5.0)
  pure "greeting from the server"

-- | `onFetch` runs whenever the async greeting is fetched.
app :: { onFetch :: Effect Unit } -> JSX
app = Component.element root

root :: Component.Component { onFetch :: Effect Unit }
root = Component.component \{ onFetch } -> do
  count /\ setCount <- createSignal 0
  items /\ setItems <- createSignal [ "alpha", "beta" ]
  detail /\ setDetail <- createSignal (Nothing :: Maybe String)
  greeting /\ _ <- createAsyncWith { ssr: serialized } (pure (fetchGreeting onFetch))

  pure $ H.main { id: "hydration-app" }
    [ H.h1 {} "Hydration"
    , H.button
        { id: "increment"
        , type: ButtonButton
        , title: ("count " <> _) <<< show <$> count
        , class: { odd: (_ == 1) <<< (_ `mod` 2) <$> count }
        , onClick: \_ -> modify_ setCount (_ + 1)
        }
        [ text "clicked ", text (show <$> count), text " times" ]
    , H.ul { id: "items" }
        (Control.forEach items \item _ -> pure (H.li {} item))
    , H.button { id: "add", type: ButtonButton, onClick: \_ -> modify_ setItems (_ <> [ "gamma" ]) } "add"
    , H.button { id: "toggle", type: ButtonButton, onClick: \_ -> modify_ setDetail (maybe' (Just "shown")) } "toggle"
    , Control.showMaybeElse detail (\value -> pure (H.p { id: "detail" } value)) (H.p { id: "no-detail" } "hidden")
    , Control.loading (H.p {} "loading") (H.p { id: "greeting" } greeting)
    , S.svg { viewBox: "0 0 10 10", width: "10" } [ S.circle { cx: "5", cy: "5", r: "4" } [] ]
    ]
  where
  maybe' next = case _ of
    Nothing -> next
    Just _ -> Nothing
