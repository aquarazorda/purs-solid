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
import Solid.DOM (classWhen)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.DOM.SVG as S
import Solid.DOM.SVG.Props as SP
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

  pure $ H.main [ P.id "hydration-app" ]
    [ H.h1_ [ text "Hydration" ]
    , H.button
        [ P.id "increment"
        , P.type_ ButtonButton
        , P.title (("count " <> _) <<< show <$> count)
        , classWhen "odd" ((_ == 1) <<< (_ `mod` 2) <$> count)
        , P.onClick \_ -> modify_ setCount (_ + 1)
        ]
        [ text "clicked ", text (show <$> count), text " times" ]
    , H.ul [ P.id "items" ]
        [ Control.forEach items \item _ -> pure (H.li_ [ text item ]) ]
    , H.button [ P.id "add", P.type_ ButtonButton, P.onClick \_ -> modify_ setItems (_ <> [ "gamma" ]) ] [ text "add" ]
    , H.button [ P.id "toggle", P.type_ ButtonButton, P.onClick \_ -> modify_ setDetail (maybe' (Just "shown")) ] [ text "toggle" ]
    , Control.showMaybeElse detail (\value -> pure (H.p [ P.id "detail" ] [ text value ])) (H.p [ P.id "no-detail" ] [ text "hidden" ])
    , Control.loading (H.p_ [ text "loading" ]) (H.p [ P.id "greeting" ] [ text greeting ])
    , S.svg [ SP.viewBox "0 0 10 10", P.width "10" ] [ S.circle [ SP.cx "5", SP.cy "5", SP.r "4" ] [] ]
    ]
  where
  maybe' next = case _ of
    Nothing -> next
    Just _ -> Nothing
