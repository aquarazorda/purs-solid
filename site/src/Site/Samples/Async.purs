module Site.Samples.Async where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff)
import Solid.Async (createAsync, refresh)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.Signal (Accessor)

fetchUser :: Int -> Aff { name :: String }
fetchUser id = pure { name: "User " <> show id }

-- region async
user :: Component.Component { id :: Accessor Int }
user = Component.component \props -> do
  found /\ reload <- createAsync (fetchUser <$> props.id)
  pure $ Control.loading (H.p {} "Loading…") $
    H.div {}
      [ H.h2 {} (_.name <$> found)
      , H.button { onClick: \_ -> refresh reload } "Reload"
      ]
-- endregion
