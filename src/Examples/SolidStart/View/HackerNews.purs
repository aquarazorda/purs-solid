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

import Examples.SolidStart.Config (routeHref)
import Examples.SolidStart.HackerNews.Api as HackerNews
import Examples.SolidStart.Navigation (navigateToRoute)
import Examples.SolidStart.RouteView (HnRoute(..))
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM (innerHTML)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (JSX, text)
import Solid.Reactivity (createMemo)
import Solid.Signal (Accessor, Setter, createSignal, get, set)

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
  H.li [ P.class_ "news-item" ]
    ( [ H.span [ P.class_ "score" ] [ text (maybe "-" show story.points) ]
      , H.span [ P.class_ "title" ]
          ( [ titleNode ] <> hostNode
          )
      , H.br_
      , H.span [ P.class_ "meta" ]
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
            H.a
              [ P.href url
              , P.target "_blank"
              , P.rel "noreferrer"
              ]
              [ text story.title ]
      _ ->
        H.a
          [ P.href (routeHref path)
          , P.onClick \_ -> (navigateToRoute path setCurrentRoute)
          ]
          [ text story.title ]

  hostNode =
    case story.domain of
      Just domainName ->
        [ H.span [ P.class_ "host" ] [ text (" (" <> domainName <> ")") ] ]
      Nothing ->
        []

  linkMeta =
    [ text "by "
    , storyUserNode
    , text (" " <> story.timeAgo <> " | ")
    , H.a
        [ P.href (routeHref path)
        , P.onClick \_ -> (navigateToRoute path setCurrentRoute)
        ]
        [ text (commentsLabel story.commentsCount) ]
    ]

  jobMeta =
    [ H.a
        [ P.href (routeHref path)
        , P.onClick \_ -> (navigateToRoute path setCurrentRoute)
        ]
        [ text story.timeAgo ]
    ]

  storyUserNode =
    case story.user of
      Just userId ->
        H.a
          [ P.href (routeHref (userRoutePath userId))
          , P.onClick \_ -> (navigateToRoute (userRoutePath userId) setCurrentRoute)
          ]
          [ text userId ]
      Nothing ->
        H.span_ [ text "anonymous" ]

  storyTypeNode =
    if story.storyType == "link" then
      []
    else
      [ text " "
      , H.span [ P.class_ "label" ] [ text story.storyType ]
      ]

hackerNewsFeedContent :: Setter String -> Setter Int -> HnStoriesState -> HackerNews.FeedType -> JSX
hackerNewsFeedContent setCurrentRoute setHnPage storiesState activeFeed =
  H.div [ P.class_ "news-view" ]
    [ H.div [ P.class_ "news-list-nav" ]
        [ prevNode
        , H.span_ [ text ("page " <> show storiesState.page) ]
        , nextNode
        ]
    , H.main [ P.class_ "news-list" ]
        [ H.ul_ listItems
        ]
    ]
  where
  prevNode =
    if storiesState.page > 1 then
      H.a
        [ P.class_ "page-link"
        , P.href (routeHref (HackerNews.feedRoutePath activeFeed))
        , P.onClick \_ -> do
            _ <- set setHnPage (storiesState.page - 1)
            pure unit
        ]
        [ text "< prev" ]
    else
      H.span [ P.class_ "page-link disabled" ] [ text "< prev" ]

  nextNode =
    if Array.length storiesState.items >= 29 then
      H.a
        [ P.class_ "page-link"
        , P.href (routeHref (HackerNews.feedRoutePath activeFeed))
        , P.onClick \_ -> do
            _ <- set setHnPage (storiesState.page + 1)
            pure unit
        ]
        [ text "more >" ]
    else
      H.span [ P.class_ "page-link disabled" ] [ text "more >" ]

  listItems =
    case storiesState.error of
      Just message ->
        [ H.li [ P.class_ "news-item" ] [ text ("Could not load stories: " <> message) ] ]
      Nothing ->
        if storiesState.loading && Array.null storiesState.items then
          [ H.li [ P.class_ "news-item" ] [ text "Loading stories..." ] ]
        else if Array.null storiesState.items then
          [ H.li [ P.class_ "news-item" ] [ text "No stories found." ] ]
        else
          map (renderStoryListItem setCurrentRoute) storiesState.items

type CommentProps =
  { setCurrentRoute :: Setter String
  , comment :: HackerNews.Comment
  }

commentComponent :: Component.Component CommentProps
commentComponent = Component.component \props -> do
  isOpen /\ setIsOpen <- createSignal true

  toggleLabel <- createMemo $ isOpen <#> \open ->
    if open then "[-]" else "[+] comments collapsed"

  toggleClass <- createMemo $ isOpen <#> \open ->
    if open then "toggle open" else "toggle"

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
  H.li [ P.class_ "comment" ]
    ( [ H.div [ P.class_ "by" ]
          [ userNode
          , text (" " <> comment.timeAgo <> " ago")
          ]
      , H.div
          [ P.class_ "text"
          , innerHTML comment.content
          ]
          []
      ]
        <> childNodes
    )
  where
  userNode =
    case comment.user of
      Just userId ->
        H.a
          [ P.href (routeHref (userRoutePath userId))
          , P.onClick \_ -> (navigateToRoute (userRoutePath userId) setCurrentRoute)
          ]
          [ text userId ]
      Nothing ->
        H.span_ [ text "anonymous" ]

  childNodes =
    if Array.null comment.comments then
      []
    else
      [ H.div [ P.class_ toggleClass ]
          [ H.a
              [ P.onClick \_ -> do
                  current <- get isOpen
                  _ <- set setIsOpen (not current)
                  pure unit
              ]
              [ H.span_ [ text toggleLabel ] ]
          ]
      , Control.when isOpen
          (H.ul [ P.class_ "comment-children" ] (map (\child -> Component.element commentComponent { setCurrentRoute, comment: child }) comment.comments))
      ]

hackerNewsStoryContent :: Setter String -> HnStoryState -> String -> JSX
hackerNewsStoryContent setCurrentRoute storyState _storyId =
  case storyState.error of
    Just message ->
      H.div [ P.class_ "item-view" ]
        [ H.div [ P.class_ "item-view-header" ]
            [ H.h1_ [ text ("Could not load story: " <> message) ] ]
        ]

    Nothing ->
      case storyState.item of
        Nothing ->
          H.div [ P.class_ "item-view" ]
            [ H.div [ P.class_ "item-view-header" ]
                [ H.h1_ [ text (if storyState.loading then "Loading story..." else "Story not found.") ] ]
            ]

        Just story ->
          H.div [ P.class_ "item-view" ]
            [ H.div [ P.class_ "item-view-header" ]
                ( [ titleNode ]
                    <> hostNode
                    <> [ H.p [ P.class_ "meta" ]
                           [ text (maybe "-" show story.points)
                           , text " points | by "
                           , userNode
                           , text (" " <> story.timeAgo <> " ago")
                           ]
                       ]
                )
            , H.div [ P.class_ "item-view-comments" ]
                [ H.p [ P.class_ "item-view-comments-header" ]
                    [ text
                        ( if story.commentsCount == 0 then
                            "No comments yet."
                          else
                            show story.commentsCount <> " comments"
                        )
                    ]
                , if Array.null story.comments then
                    H.p_ []
                  else
                    H.ul [ P.class_ "comment-children" ]
                      (map (\comment -> Component.element commentComponent { setCurrentRoute, comment }) story.comments)
                ]
            ]
          where
          titleNode =
            case story.url of
              Just url
                | isExternalStoryUrl url ->
                    H.a
                      [ P.href url
                      , P.target "_blank"
                      , P.rel "noreferrer"
                      ]
                      [ H.h1_ [ text story.title ] ]
              _ ->
                H.h1_ [ text story.title ]

          hostNode =
            case story.domain of
              Just domainName ->
                [ H.span [ P.class_ "host" ] [ text ("(" <> domainName <> ")") ] ]
              Nothing ->
                []

          userNode =
            case story.user of
              Just userId ->
                H.a
                  [ P.href (routeHref (userRoutePath userId))
                  , P.onClick \_ -> (navigateToRoute (userRoutePath userId) setCurrentRoute)
                  ]
                  [ text userId ]
              Nothing ->
                H.span_ [ text "anonymous" ]

hackerNewsUserContent :: HnUserState -> String -> JSX
hackerNewsUserContent userState requestedUserId =
  case userState.error of
    Just message ->
      H.section [ P.class_ "user-view" ]
        [ H.h1_ [ text ("Could not load user " <> requestedUserId <> ": " <> message) ] ]

    Nothing ->
      case userState.user of
        Nothing ->
          H.section [ P.class_ "user-view" ]
            [ H.h1_ [ text (if userState.loading then "Loading user..." else "User not found.") ] ]

        Just user ->
          H.section [ P.class_ "user-view" ]
            [ H.h1_ [ text ("User : " <> user.id) ]
            , H.ul [ P.class_ "meta" ]
                ( [ H.li_
                      [ H.span [ P.class_ "label" ] [ text "Created:" ]
                      , text (" " <> user.createdLabel)
                      ]
                  , H.li_
                      [ H.span [ P.class_ "label" ] [ text "Karma:" ]
                      , text (" " <> show user.karma)
                      ]
                  ]
                    <> aboutNode
                )
            , H.p [ P.class_ "links" ]
                [ H.a
                    [ P.href ("https://news.ycombinator.com/submitted?id=" <> user.id)
                    , P.target "_blank"
                    , P.rel "noreferrer"
                    ]
                    [ text "submissions" ]
                , text " | "
                , H.a
                    [ P.href ("https://news.ycombinator.com/threads?id=" <> user.id)
                    , P.target "_blank"
                    , P.rel "noreferrer"
                    ]
                    [ text "comments" ]
                ]
            ]
          where
          aboutNode =
            case user.about of
              Just aboutHtml ->
                [ H.li
                    [ P.class_ "about"
                    , innerHTML aboutHtml
                    ]
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
