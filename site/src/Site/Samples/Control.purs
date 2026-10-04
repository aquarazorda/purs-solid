module Site.Samples.Control where

import Prelude

import Data.Array as Array
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe)
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.JSX (JSX, text)
import Solid.Signal (Accessor)

type Todo = { id :: Int, title :: String }

-- region control
todoList :: Accessor (Array Todo) -> Accessor (Maybe String) -> JSX
todoList todos error = H.section {}
  [ Control.whenElse (Array.null <$> todos)
      (H.p {} "Nothing to do")
      (H.h2 {} "Todos")
  , H.ul {} $ Control.forEachBy _.id todos \todo _ ->
      pure (H.li {} (_.title <$> todo))
  , Control.showMaybe error \message -> pure (H.p { role: "alert" } message)
  ]

-- endregion

-- region case
data Page = Home | Profile Int

derive instance Generic Page _

pageView :: Accessor Page -> JSX
pageView page =
  Control.caseOn Control.constructorName page \current _ -> pure case current of
    Home -> text "Home"
    Profile id -> text ("Profile " <> show id)
-- endregion
