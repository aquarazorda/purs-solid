module Examples.HackerNews.App
  ( app
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (toMaybe)
import Data.Tuple.Nested ((/\))
import Effect.Exception (message)
import Examples.HackerNews.Api (Comment, Feed(..), Story, feedLabel, feedPath, parseFeed)
import Examples.HackerNews.Api as Api
import Solid.Async (class Serializable, AsyncSsr, createAsyncWith, serialized)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.JSX (JSX, text)
import Solid.JSX as JSX
import Solid.Meta as Meta
import Solid.Router (href)
import Solid.Router as Router
import Solid.Router.Search (searchParams, useSearch)
import Solid.Setup (Setup)
import Solid.Signal (Accessor, createSignal, modify_)
import Solid.Start.Response (httpStatus)

app :: Component.Component {}
app = Component.component \_ -> do
  router <- Router.createRouter
    { routes:
        [ Router.route @"/" \_ -> feedPage Top
        , Router.route @"/stories/:id<int>" \props -> storyPage props.params
        , Router.route @"/users/:id" \props -> userPage props.params
        , Router.route @"/:feed" \props -> pure $
            JSX.reactive
              ( props.params <#> \{ feed } -> case parseFeed feed of
                  Just parsed -> Component.element feedComponent { feed: parsed }
                  Nothing -> Component.element notFound {}
              )
        ]
    }
  pure $ Router.routerView router \content -> pure $
    H.div {}
      [ H.header { class: "header" }
          [ H.nav { class: "inner" } (navLink <$> [ Top, New, ShowHN, Ask, Jobs ]) ]
      , H.main { class: "view" }
          [ Control.errored (\err _ -> pure (H.p {} (("Something went wrong: " <> _) <<< message <$> err)))
              (Control.loading (H.p { class: "loading" } "Loading…") content)
          ]
      ]
  where
  navLink feed = H.a { href: feedPath feed } [ H.strong {} (feedLabel feed) ]

serverData :: forall a. Serializable a => { ssr :: AsyncSsr a }
serverData = { ssr: serialized }

feedComponent :: Component.Component { feed :: Feed }
feedComponent = Component.component \props -> feedPage props.feed

feedPage :: Feed -> Setup JSX
feedPage feed = do
  search <- useSearch @(page :: Maybe Int)
  let page = fromMaybe 1 <<< _.page <$> searchParams search
  items /\ _ <- createAsyncWith serverData (Api.stories feed <$> page)
  pure $ H.div { class: "news-view" }
    [ Meta.title ("Hacker News | " <> feedLabel feed)
    , H.div { class: "news-list-nav" }
        [ Control.whenElse ((_ > 1) <$> page)
            (H.a { href: (\p -> feedPath feed <> "?page=" <> show (p - 1)) <$> page } "< prev")
            (H.span { class: "disabled" } "< prev")
        , H.span {} (("page " <> _) <<< show <$> page)
        , H.a { href: (\p -> feedPath feed <> "?page=" <> show (p + 1)) <$> page } "more >"
        ]
    , H.ul { class: "news-list" } [ Control.forEachBy _.id items \row _ -> pure (storyRow row) ]
    ]

storyRow :: Accessor Story -> JSX
storyRow row = H.li { class: "news-item" }
  [ H.span { class: "score" } (show <<< _.points <$> row)
  , H.span { class: "title" }
      [ H.a { href: row <#> \s -> fromMaybe (href @"/stories/:id<int>" { id: s.id }) (toMaybe s.url) } (_.title <$> row) ]
  , H.br {}
  , H.span { class: "meta" }
      [ text (row <#> \s -> "by " <> fromMaybe "anonymous" (toMaybe s.by) <> " | ")
      , H.a { href: row <#> \s -> href @"/stories/:id<int>" { id: s.id } } (row <#> \s -> show s.comments <> " comments")
      ]
  ]

storyPage :: Accessor { id :: Int } -> Setup JSX
storyPage params = do
  page /\ _ <- createAsyncWith serverData (Api.story <<< _.id <$> params)
  pure $ Control.showMaybeElse (toMaybe <$> page)
    ( \found -> pure $ H.div { class: "item-view" }
        [ Meta.title (("Hacker News | " <> _) <<< _.story.title <$> found)
        , H.h1 {} (_.story.title <$> found)
        , H.p { class: "meta" } (found <#> \p -> show p.story.points <> " points | by " <> fromMaybe "anonymous" (toMaybe p.story.by))
        , JSX.reactive (found <#> \p -> commentTree (childrenOf p.comments) p.story.id)
        ]
    )
    (Component.element notFound {})

childrenOf :: Array Comment -> Map.Map Int (Array Comment)
childrenOf = Array.foldl (\acc c -> Map.insertWith (<>) c.parent [ c ] acc) Map.empty

commentTree :: Map.Map Int (Array Comment) -> Int -> JSX
commentTree tree parent = case Map.lookup parent tree of
  Nothing -> H.ul {} []
  Just replies -> H.ul { class: "comment-children" } (replies <#> \c -> Component.element commentView { comment: c, tree })

commentView :: Component.Component { comment :: Comment, tree :: Map.Map Int (Array Comment) }
commentView = Component.component \{ comment, tree } -> do
  open /\ setOpen <- createSignal true
  pure $ H.li { class: "comment" }
    [ H.div { class: "by" }
        [ H.a { href: href @"/users/:id" { id: fromMaybe "" (toMaybe comment.by) } } (fromMaybe "anonymous" (toMaybe comment.by)) ]
    , H.div { class: "text", innerHTML: comment.html } []
    , if Map.member comment.id tree then
        H.div {}
          [ H.button { type: ButtonButton, class: "toggle", onClick: \_ -> modify_ setOpen not }
              [ text (open <#> \o -> if o then "[-]" else "[+] comments collapsed") ]
          , Control.when open (commentTree tree comment.id)
          ]
      else JSX.empty
    ]

userPage :: Accessor { id :: String } -> Setup JSX
userPage params = do
  found /\ _ <- createAsyncWith serverData (Api.user <<< _.id <$> params)
  pure $ Control.showMaybeElse (toMaybe <$> found)
    ( \u -> pure $ H.section { class: "user-view" }
        [ Meta.title (("Hacker News | " <> _) <<< _.id <$> u)
        , H.h1 {} (("User: " <> _) <<< _.id <$> u)
        , H.p {} (u <#> \x -> "Karma: " <> show x.karma)
        , H.div { innerHTML: fromMaybe "" <<< toMaybe <<< _.about <$> u } []
        ]
    )
    (Component.element notFound {})

notFound :: Component.Component {}
notFound = Component.component \_ -> do
  httpStatus 404
  pure (H.h1 {} "Not found")
