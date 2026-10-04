module Site.Samples.Store where

import Prelude

import Data.Tuple.Nested ((/\))
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.Store as Store

-- region store
type Todo = { id :: Int, title :: String, done :: Boolean }

todos :: Component.Component {}
todos = Component.component \_ -> do
  state /\ setState <- Store.createStore { todos: [] :: Array Todo }
  let
    add title = Store.update setState $
      Store.atKey @"todos" (Store.push { id: 0, title, done: false })
    whereId id = Store.atKey @"todos" <<< Store.eachWhere (\todo -> todo.id == id)
    toggle id = Store.update setState $
      whereId id (Store.atKey @"done" (Store.modify not))
    rows = Store.items (Store.focusKey @"todos" state)
  pure $ H.div {}
    [ H.button { onClick: \_ -> add "Write docs" } "Add"
    , H.ul {} $ Control.forEach rows \row _ -> pure $
        H.li
          { onClick: \_ -> Store.snapshot (Store.focusKey @"id" row) >>= toggle }
          (Store.value (Store.focusKey @"title" row))
    ]
-- endregion
