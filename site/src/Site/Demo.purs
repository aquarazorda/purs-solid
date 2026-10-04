module Site.Demo
  ( counter
  ) where

import Prelude

-- region counter
import Data.Tuple.Nested ((/\))
import Solid.Component as Component
import Solid.DOM.HTML as H
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, modify_)

counter :: Component.Component {}
counter = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  doubled <- createMemo ((_ * 2) <$> count)
  pure $ H.div { class: "counter" }
    [ H.button
        { onClick: \_ -> modify_ setCount (_ + 1)
        , class: { big: (_ > 3) <$> count }
        }
        "+1"
    , H.span {} (show <$> count)
    , H.small {} ((\n -> "doubled: " <> show n) <$> doubled)
    ]
-- endregion
