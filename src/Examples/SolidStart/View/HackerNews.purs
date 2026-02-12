module Examples.SolidStart.View.HackerNews
  ( HnStoriesState
  , HnStoryState
  , HnUserState
  , initialHnStoriesState
  , initialHnStoryState
  , initialHnUserState
  , hackerNewsContent
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Data.String.CodeUnits as StringCodeUnits
import Data.Tuple.Nested ((/\))

import Examples.SolidStart.Config (basePath, routeHref)
import Examples.SolidStart.HackerNews.Api as HackerNews
import Examples.SolidStart.Navigation (navigateToRoute)
import Examples.SolidStart.RouteView (HnRoute(..))
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Reactivity (createMemo)
import Solid.Signal (Accessor, Setter, createSignal, get, set)
import Solid.Start.Client.Navigation as ClientNavigation

type HnStoriesState =
  { loading :: Boolean
  , error :: Maybe String
  , items :: Array HackerNews.Story
  , feed :: HackerNews.FeedType
  , page :: Int
  }

type HnStoryState =
  { loading :: Boolean
  , error :: Maybe String
  , item :: Maybe HackerNews.StoryDetail
  , storyId :: Maybe String
  }

type HnUserState =
  { loading :: Boolean
  , error :: Maybe String
  , user :: Maybe HackerNews.User
  , userId :: Maybe String
  }

initialHnStoriesState :: HnStoriesState
initialHnStoriesState =
  { loading: false
  , error: Nothing
  , items: []
  , feed: HackerNews.TopFeed
  , page: 1
  }

initialHnStoryState :: HnStoryState
initialHnStoryState =
  { loading: false
  , error: Nothing
  , item: Nothing
  , storyId: Nothing
  }

initialHnUserState :: HnUserState
initialHnUserState =
  { loading: false
  , error: Nothing
  , user: Nothing
  , userId: Nothing
  }

storyRoutePath :: Int -> String
storyRoutePath storyId =
  "/stories/" <> show storyId

userRoutePath :: String -> String
userRoutePath userId =
  "/users/" <> userId

commentsLabel :: Int -> String
commentsLabel count =
  if count == 0 then
    "discuss"
  else
    show count <> " comments"

startsWith :: String -> String -> Boolean
startsWith prefix value =
  StringCodeUnits.take (StringCodeUnits.length prefix) value == prefix

isExternalStoryUrl :: String -> Boolean
isExternalStoryUrl url =
  startsWith "http://" url || startsWith "https://" url

renderStoryListItem :: Setter String -> HackerNews.Story -> JSX
renderStoryListItem setCurrentRoute story =
  HTML.li { className: "news-item" }
    ( [ HTML.span { className: "score" } [ DOM.text (maybe "-" show story.points) ]
      , HTML.span { className: "title" }
          ( [ titleNode ] <> hostNode
          )
      , HTML.br_ []
      , HTML.span { className: "meta" }
          (if story.storyType == "job" then jobMeta else linkMeta)
      ]
        <> storyTypeNode
    )
  where
  path = storyRoutePath story.id

  titleNode =
    case story.url of
      Just url
        | isExternalStoryUrl url ->
            HTML.a
              { href: url
              , target: "_blank"
              , rel: "noreferrer"
              }
              [ DOM.text story.title ]
      _ ->
        HTML.a
          { href: routeHref path
          , onClick: Events.handler \event ->
              navigateToRoute path setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
          }
          [ DOM.text story.title ]

  hostNode =
    case story.domain of
      Just domainName ->
        [ HTML.span { className: "host" } [ DOM.text (" (" <> domainName <> ")") ] ]
      Nothing ->
        []

  linkMeta =
    [ DOM.text "by "
    , storyUserNode
    , DOM.text (" " <> story.timeAgo <> " | ")
    , HTML.a
        { href: routeHref path
        , onClick: Events.handler \event ->
            navigateToRoute path setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
        }
        [ DOM.text (commentsLabel story.commentsCount) ]
    ]

  jobMeta =
    [ HTML.a
        { href: routeHref path
        , onClick: Events.handler \event ->
            navigateToRoute path setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
        }
        [ DOM.text story.timeAgo ]
    ]

  storyUserNode =
    case story.user of
      Just userId ->
        HTML.a
          { href: routeHref (userRoutePath userId)
          , onClick: Events.handler \event ->
              navigateToRoute (userRoutePath userId) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
          }
          [ DOM.text userId ]
      Nothing ->
        HTML.span_ [ DOM.text "anonymous" ]

  storyTypeNode =
    if story.storyType == "link" then
      []
    else
      [ DOM.text " "
      , HTML.span { className: "label" } [ DOM.text story.storyType ]
      ]

hackerNewsFeedContent :: Setter String -> Setter Int -> HnStoriesState -> HackerNews.FeedType -> JSX
hackerNewsFeedContent setCurrentRoute setHnPage storiesState activeFeed =
  HTML.div { className: "news-view" }
    [ HTML.div { className: "news-list-nav" }
        [ prevNode
        , HTML.span_ [ DOM.text ("page " <> show storiesState.page) ]
        , nextNode
        ]
    , HTML.main { className: "news-list" }
        [ HTML.ul_ listItems
        ]
    ]
  where
  prevNode =
    if storiesState.page > 1 then
      HTML.a
        { className: "page-link"
        , href: routeHref (HackerNews.feedRoutePath activeFeed)
        , onClick: Events.handler_ do
            _ <- set setHnPage (storiesState.page - 1)
            pure unit
        }
        [ DOM.text "< prev" ]
    else
      HTML.span { className: "page-link disabled" } [ DOM.text "< prev" ]

  nextNode =
    if Array.length storiesState.items >= 29 then
      HTML.a
        { className: "page-link"
        , href: routeHref (HackerNews.feedRoutePath activeFeed)
        , onClick: Events.handler_ do
            _ <- set setHnPage (storiesState.page + 1)
            pure unit
        }
        [ DOM.text "more >" ]
    else
      HTML.span { className: "page-link disabled" } [ DOM.text "more >" ]

  listItems =
    case storiesState.error of
      Just message ->
        [ HTML.li { className: "news-item" } [ DOM.text ("Could not load stories: " <> message) ] ]
      Nothing ->
        if storiesState.loading && Array.null storiesState.items then
          [ HTML.li { className: "news-item" } [ DOM.text "Loading stories..." ] ]
        else if Array.null storiesState.items then
          [ HTML.li { className: "news-item" } [ DOM.text "No stories found." ] ]
        else
          map (renderStoryListItem setCurrentRoute) storiesState.items

type CommentProps =
  { setCurrentRoute :: Setter String
  , comment :: HackerNews.Comment
  }

commentComponent :: Component.Component CommentProps
commentComponent = Component.component \props -> do
  isOpen /\ setIsOpen <- createSignal true

  toggleLabel <- createMemo do
    open <- get isOpen
    pure (if open then "[-]" else "[+] comments collapsed")

  toggleClass <- createMemo do
    open <- get isOpen
    pure (if open then "toggle open" else "toggle")

  pure $ renderCommentNode props.setCurrentRoute props.comment isOpen setIsOpen toggleLabel toggleClass

renderCommentNode
  :: Setter String
  -> HackerNews.Comment
  -> Accessor Boolean
  -> Setter Boolean
  -> Accessor String
  -> Accessor String
  -> JSX
renderCommentNode setCurrentRoute (HackerNews.Comment comment) isOpen setIsOpen toggleLabel toggleClass =
  HTML.li { className: "comment" }
    ( [ HTML.div { className: "by" }
          [ userNode
          , DOM.text (" " <> comment.timeAgo <> " ago")
          ]
      , HTML.div
          { className: "text"
          , innerHTML: comment.content
          }
          []
      ]
        <> childNodes
    )
  where
  userNode =
    case comment.user of
      Just userId ->
        HTML.a
          { href: routeHref (userRoutePath userId)
          , onClick: Events.handler \event ->
              navigateToRoute (userRoutePath userId) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
          }
          [ DOM.text userId ]
      Nothing ->
        HTML.span_ [ DOM.text "anonymous" ]

  childNodes =
    if Array.null comment.comments then
      []
    else
      [ HTML.div { className: toggleClass }
          [ HTML.a
              { onClick: Events.handler_ do
                  current <- get isOpen
                  _ <- set setIsOpen (not current)
                  pure unit
              }
              [ Control.dynamicTag "span" { children: toggleLabel } ]
          ]
      , Control.when isOpen
          (HTML.ul { className: "comment-children" } (map (\child -> Component.element commentComponent { setCurrentRoute, comment: child }) comment.comments))
      ]

hackerNewsStoryContent :: Setter String -> HnStoryState -> String -> JSX
hackerNewsStoryContent setCurrentRoute storyState _storyId =
  case storyState.error of
    Just message ->
      HTML.div { className: "item-view" }
        [ HTML.div { className: "item-view-header" }
            [ HTML.h1_ [ DOM.text ("Could not load story: " <> message) ] ]
        ]

    Nothing ->
      case storyState.item of
        Nothing ->
          HTML.div { className: "item-view" }
            [ HTML.div { className: "item-view-header" }
                [ HTML.h1_ [ DOM.text (if storyState.loading then "Loading story..." else "Story not found.") ] ]
            ]

        Just story ->
          HTML.div { className: "item-view" }
            [ HTML.div { className: "item-view-header" }
                ( [ titleNode ]
                    <> hostNode
                    <> [ HTML.p { className: "meta" }
                           [ DOM.text (maybe "-" show story.points)
                           , DOM.text " points | by "
                           , userNode
                           , DOM.text (" " <> story.timeAgo <> " ago")
                           ]
                       ]
                )
            , HTML.div { className: "item-view-comments" }
                [ HTML.p { className: "item-view-comments-header" }
                    [ DOM.text
                        ( if story.commentsCount == 0 then
                            "No comments yet."
                          else
                            show story.commentsCount <> " comments"
                        )
                    ]
                , if Array.null story.comments then
                    HTML.p_ []
                  else
                    HTML.ul { className: "comment-children" }
                      (map (\comment -> Component.element commentComponent { setCurrentRoute, comment }) story.comments)
                ]
            ]
          where
          titleNode =
            case story.url of
              Just url
                | isExternalStoryUrl url ->
                    HTML.a
                      { href: url
                      , target: "_blank"
                      , rel: "noreferrer"
                      }
                      [ HTML.h1_ [ DOM.text story.title ] ]
              _ ->
                HTML.h1_ [ DOM.text story.title ]

          hostNode =
            case story.domain of
              Just domainName ->
                [ HTML.span { className: "host" } [ DOM.text ("(" <> domainName <> ")") ] ]
              Nothing ->
                []

          userNode =
            case story.user of
              Just userId ->
                HTML.a
                  { href: routeHref (userRoutePath userId)
                  , onClick: Events.handler \event ->
                      navigateToRoute (userRoutePath userId) setCurrentRoute (ClientNavigation.navigateFromClick event basePath)
                  }
                  [ DOM.text userId ]
              Nothing ->
                HTML.span_ [ DOM.text "anonymous" ]

hackerNewsUserContent :: HnUserState -> String -> JSX
hackerNewsUserContent userState requestedUserId =
  case userState.error of
    Just message ->
      HTML.section { className: "user-view" }
        [ HTML.h1_ [ DOM.text ("Could not load user " <> requestedUserId <> ": " <> message) ] ]

    Nothing ->
      case userState.user of
        Nothing ->
          HTML.section { className: "user-view" }
            [ HTML.h1_ [ DOM.text (if userState.loading then "Loading user..." else "User not found.") ] ]

        Just user ->
          HTML.section { className: "user-view" }
            [ HTML.h1_ [ DOM.text ("User : " <> user.id) ]
            , HTML.ul { className: "meta" }
                ( [ HTML.li_
                      [ HTML.span { className: "label" } [ DOM.text "Created:" ]
                      , DOM.text (" " <> user.createdLabel)
                      ]
                  , HTML.li_
                      [ HTML.span { className: "label" } [ DOM.text "Karma:" ]
                      , DOM.text (" " <> show user.karma)
                      ]
                  ]
                    <> aboutNode
                )
            , HTML.p { className: "links" }
                [ HTML.a
                    { href: "https://news.ycombinator.com/submitted?id=" <> user.id
                    , target: "_blank"
                    , rel: "noreferrer"
                    }
                    [ DOM.text "submissions" ]
                , DOM.text " | "
                , HTML.a
                    { href: "https://news.ycombinator.com/threads?id=" <> user.id
                    , target: "_blank"
                    , rel: "noreferrer"
                    }
                    [ DOM.text "comments" ]
                ]
            ]
          where
          aboutNode =
            case user.about of
              Just aboutHtml ->
                [ HTML.li
                    { className: "about"
                    , innerHTML: aboutHtml
                    }
                    []
                ]
              Nothing ->
                []

hackerNewsContent
  :: Setter String
  -> Setter Int
  -> HnStoriesState
  -> HnStoryState
  -> HnUserState
  -> HnRoute
  -> JSX
hackerNewsContent setCurrentRoute setHnPage storiesState storyState userState hnRoute =
  case hnRoute of
    HnFeedRoute feed ->
      hackerNewsFeedContent setCurrentRoute setHnPage storiesState feed

    HnStoryRoute storyId ->
      hackerNewsStoryContent setCurrentRoute storyState storyId

    HnUserRoute userId ->
      hackerNewsUserContent userState userId
