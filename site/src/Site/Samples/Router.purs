module Site.Samples.Router where

import Prelude

import Data.Maybe (Maybe, fromMaybe)
import Solid.Component as Component
import Solid.DOM.HTML as H
import Solid.Router as Router
import Solid.Router.Path (href)
import Solid.Router.Search (searchParams, useSearch)

-- region router
app :: Component.Component {}
app = Component.component \_ -> do
  router <- Router.createRouter
    { routes:
        [ Router.route @"/" \_ -> pure $
            H.a { href: href @"/users/:id<int>" { id: 7 } } "User 7"
        , Router.route @"/users/:id<int>" \props -> do
            search <- useSearch @(tab :: Maybe String)
            let
              title { id } { tab } =
                "User " <> show id <> ", " <> fromMaybe "profile" tab
            pure $ H.h1 {} (title <$> props.params <*> searchParams search)
        ]
    }
  pure $ Router.routerView router \content -> pure (H.main {} content)
-- endregion
