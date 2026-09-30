module Examples.HackerNews.App
  ( app
  ) where

import Prelude

import DOM.HTML.Indexed.ButtonType (ButtonType(..))
import Data.Array as Array
import Data.Int as Int
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
import Solid.DOM (innerHTML)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (JSX, text)
import Solid.JSX as JSX
import Solid.Meta as Meta
import Solid.Router (href)
import Solid.Router as Router
import Solid.Setup (Setup, liftSetup)
import Solid.Signal (Accessor, createSignal, modify_)
import Solid.Start.Response (httpStatus)

app :: Component.Component {}
app = Component.component \_ -> do
  router <- liftSetup $ Router.createRouter
    { routes:
        [ Router.route @"/" \_ -> feedPage Top
        , Router.route @"/stories/:id<int>" \props -> storyPage props.params
        , Router.route @"/users/:id" \props -> userPage props.params
        , Router.route @"/:feed" \props -> pure $
            JSX.reactive (props.params <#> \{ feed } -> case parseFeed feed of
              Just parsed -> Component.element feedComponent { feed: parsed }
              Nothing -> Component.element notFound {})
        ]
    }
  pure $ Router.routerView router \content -> pure $
    H.div_
      [ H.header [ P.class_ "header" ]
          [ H.nav [ P.class_ "inner" ] (navLink <$> [ Top, New, ShowHN, Ask, Jobs ]) ]
      , H.main [ P.class_ "view" ]
          [ Control.errored (\err _ -> pure (H.p_ [ text (("Something went wrong: " <> _) <<< message <$> err) ]))
              (Control.loading (H.p [ P.class_ "loading" ] [ text "Loading…" ]) content)
          ]
      ]
  where
  navLink feed = H.a [ P.href (feedPath feed) ] [ H.strong_ [ text (feedLabel feed) ] ]

serverData :: forall a. Serializable a => { ssr :: AsyncSsr a }
serverData = { ssr: serialized }

feedComponent :: Component.Component { feed :: Feed }
feedComponent = Component.component \props -> feedPage props.feed

feedPage :: Feed -> Setup JSX
feedPage feed = do
  location <- Router.useLocation
  let page = fromMaybe 1 <<< (_ >>= Int.fromString) <$> Router.queryParam "page" location
  items /\ _ <- createAsyncWith serverData (Api.stories feed <$> page)
  pure $ H.div [ P.class_ "news-view" ]
    [ Meta.title ("Hacker News | " <> feedLabel feed)
    , H.div [ P.class_ "news-list-nav" ]
        [ Control.whenElse ((_ > 1) <$> page)
            (H.a [ P.href ((\p -> feedPath feed <> "?page=" <> show (p - 1)) <$> page) ] [ text "< prev" ])
            (H.span [ P.class_ "disabled" ] [ text "< prev" ])
        , H.span_ [ text (("page " <> _) <<< show <$> page) ]
        , H.a [ P.href ((\p -> feedPath feed <> "?page=" <> show (p + 1)) <$> page) ] [ text "more >" ]
        ]
    , H.ul [ P.class_ "news-list" ] [ Control.forEachBy _.id items \row _ -> pure (storyRow row) ]
    ]

storyRow :: Accessor Story -> JSX
storyRow row = H.li [ P.class_ "news-item" ]
  [ H.span [ P.class_ "score" ] [ text (show <<< _.points <$> row) ]
  , H.span [ P.class_ "title" ]
      [ H.a [ P.href (row <#> \s -> fromMaybe (href @"/stories/:id<int>" { id: s.id }) (toMaybe s.url)) ] [ text (_.title <$> row) ] ]
  , H.br_
  , H.span [ P.class_ "meta" ]
      [ text (row <#> \s -> "by " <> fromMaybe "anonymous" (toMaybe s.by) <> " | ")
      , H.a [ P.href (row <#> \s -> href @"/stories/:id<int>" { id: s.id }) ] [ text (row <#> \s -> show s.comments <> " comments") ]
      ]
  ]

storyPage :: Accessor { id :: Int } -> Setup JSX
storyPage params = do
  page /\ _ <- createAsyncWith serverData (Api.story <<< _.id <$> params)
  pure $ Control.showMaybeElse (toMaybe <$> page)
    (\found -> pure $ H.div [ P.class_ "item-view" ]
        [ Meta.title (("Hacker News | " <> _) <<< _.story.title <$> found)
        , H.h1_ [ text (_.story.title <$> found) ]
        , H.p [ P.class_ "meta" ] [ text (found <#> \p -> show p.story.points <> " points | by " <> fromMaybe "anonymous" (toMaybe p.story.by)) ]
        , JSX.reactive (found <#> \p -> commentTree (childrenOf p.comments) p.story.id)
        ])
    (Component.element notFound {})

childrenOf :: Array Comment -> Map.Map Int (Array Comment)
childrenOf = Array.foldl (\acc c -> Map.insertWith (<>) c.parent [ c ] acc) Map.empty

commentTree :: Map.Map Int (Array Comment) -> Int -> JSX
commentTree tree parent = case Map.lookup parent tree of
  Nothing -> H.ul_ []
  Just replies -> H.ul [ P.class_ "comment-children" ] (replies <#> \c -> Component.element commentView { comment: c, tree })

commentView :: Component.Component { comment :: Comment, tree :: Map.Map Int (Array Comment) }
commentView = Component.component \{ comment, tree } -> do
  open /\ setOpen <- createSignal true
  pure $ H.li [ P.class_ "comment" ]
    [ H.div [ P.class_ "by" ]
        [ H.a [ P.href (href @"/users/:id" { id: fromMaybe "" (toMaybe comment.by) }) ] [ text (fromMaybe "anonymous" (toMaybe comment.by)) ] ]
    , H.div [ P.class_ "text", innerHTML comment.html ] []
    , Control.when (pure (Map.member comment.id tree)) $
        H.div_
          [ H.button [ P.type_ ButtonButton, P.class_ "toggle", P.onClick \_ -> modify_ setOpen not ]
              [ text (open <#> \o -> if o then "[-]" else "[+] comments collapsed") ]
          , Control.when open (commentTree tree comment.id)
          ]
    ]

userPage :: Accessor { id :: String } -> Setup JSX
userPage params = do
  found /\ _ <- createAsyncWith serverData (Api.user <<< _.id <$> params)
  pure $ Control.showMaybeElse (toMaybe <$> found)
    (\u -> pure $ H.section [ P.class_ "user-view" ]
        [ Meta.title (("Hacker News | " <> _) <<< _.id <$> u)
        , H.h1_ [ text (("User: " <> _) <<< _.id <$> u) ]
        , H.p_ [ text (u <#> \x -> "Karma: " <> show x.karma) ]
        , H.div [ innerHTML (fromMaybe "" <<< toMaybe <<< _.about <$> u) ] []
        ])
    (Component.element notFound {})

notFound :: Component.Component {}
notFound = Component.component \_ -> do
  httpStatus 404
  pure (H.h1_ [ text "Not found" ])
