module Site.Samples.Features where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff)
import Solid.Async (createAsync)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.Aria as Aria
import Solid.DOM.HTML as H
import Solid.JSX (JSX)
import Solid.Reactivity (createMemo)
import Solid.Router as Router
import Solid.Router.Path (href)
import Solid.Signal (Accessor, createSignal, modify_)

-- region feature-props
link :: Accessor Boolean -> Accessor String -> JSX
link isActive label =
  -- no: a div has no href
  --   H.div { href: "/docs" } []
  -- no: disabled is a Boolean
  --   H.button { disabled: "yes" } []
  H.a { href: "/docs", class: { active: isActive } } label

-- endregion

-- region feature-setup
counter :: Component.Component {}
counter = Component.component \_ -> do
  count /\ setCount <- createSignal 0
  doubled <- createMemo ((_ * 2) <$> count)
  -- no: setup can't write signals
  --   set setCount 1
  pure $ H.button
    { onClick: \_ -> modify_ setCount (_ + 1) }
    (show <$> doubled)

-- endregion

fetchUser :: Int -> Aff { name :: String }
fetchUser id = pure { name: show id }

-- region feature-async
user :: Component.Component { id :: Accessor Int }
user = Component.component \{ id } -> do
  found /\ _ <- createAsync (fetchUser <$> id)
  -- no: it may not have loaded
  --   name <- get found
  pure $ Control.loading (H.p {} "Loading…")
    (H.h1 {} (_.name <$> found))

-- endregion

-- region feature-routes
routes :: Array Router.Route
routes =
  -- no: id is an Int
  --   href @"/users/:id<int>" { id: "7" }
  [ Router.route @"/users/:id<int>" \{ params } ->
      pure (H.h1 {} (show <<< _.id <$> params))
  , Router.route @"/" \_ -> pure $
      H.a { href: href @"/users/:id<int>" { id: 7 } } "7"
  ]

-- endregion

-- region feature-aria
menu :: Accessor Boolean -> JSX
menu isOpen =
  -- no: it's a Boolean
  --   "aria-expanded": "true"
  -- no: it's a HasPopup, with no "menus"
  --   "aria-haspopup": "menus"
  H.div { role: "toolbar" }
    [ H.button { "aria-expanded": isOpen } "Details"
    , H.button { "aria-haspopup": Aria.Menu } "Menu"
    , H.p { "aria-live": Aria.Polite } "Saved"
    ]
-- endregion
