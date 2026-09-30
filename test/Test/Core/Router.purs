module Test.Core.Router
  ( spec
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff, Milliseconds(..), delay, launchAff_, throwError)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Solid.Async (createAsync)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (JSX, text)
import Solid.Router (href)
import Solid.Router as Router
import Data.Argonaut.Core (fromString, toString)
import Solid.Action (createOptimistic, setOptimistic)
import Solid.Router.Action (onSettled, onSubmit, routerAction, useAction, useSubmissions)
import Solid.Signal (get)
import Solid.Router.Query (Query, revalidate, runQuery)
import Solid.Router.Search (searchParams, setSearch, useSearch)
import Solid.Start.Response (redirect, reply)
import Solid.Router.Query as Query
import Solid.Setup (liftSetup)
import Test.Solid (Mounted, click, html, mount, query, settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Effect.Exception (error)

withRouter :: String -> Array Router.Route -> Aff { mounted :: Mounted, navigate :: Ref.Ref (Maybe Router.Navigate) }
withRouter url routes = do
  navigateRef <- liftEffect (Ref.new Nothing)
  history <- liftEffect (Router.memoryHistory url)
  router <- liftEffect (Router.createRouter { routes, history })
  let
    shell = Component.component \props -> do
      nav <- Router.useNavigate
      liftSetup (Ref.write (Just nav) navigateRef)
      pure (H.main_ [ props.content ])
    view = Router.routerView router \content -> pure (Component.element shell { content })
  mounted <- mount view
  pure { mounted, navigate: navigateRef }

go :: Ref.Ref (Maybe Router.Navigate) -> String -> Aff Unit
go ref to = do
  nav <- liftEffect (Ref.read ref)
  case nav of
    Just n -> liftEffect (Router.navigate n to)
    Nothing -> throwError (error "router not mounted")
  settle
  delay (Milliseconds 5.0)
  settle

user :: Router.RouteProps (id :: String, tab :: Maybe String) -> JSX
user props = H.p_
  [ text "user "
  , text (_.id <$> props.params)
  , text " / "
  , text (fromMaybe "profile" <<< _.tab <$> props.params)
  ]

countingQuery :: String -> Aff { query :: Query String String, loads :: Ref.Ref Int }
countingQuery name = do
  loads <- liftEffect (Ref.new 0)
  let
    load id = do
      liftEffect (Ref.modify_ (_ + 1) loads)
      delay (Milliseconds 2.0)
      pure ("item " <> id)
  pure { query: Query.query name load, loads }

itemRoutes :: Query String String -> Array Router.Route
itemRoutes q =
  [ Router.route @"/" \_ -> pure (text "home")
  , Router.route @"/items/:id" \props -> do
      item /\ _ <- createAsync (runQuery q <<< _.id <$> props.params)
      pure (Control.loading (text "loading") (H.p_ [ text item ]))
  ]

waitLoad :: Aff Unit
waitLoad = settle *> delay (Milliseconds 10.0) *> settle

spec :: Spec Unit
spec = describe "Solid.Router" do
  describe "href" do
    solidIt "builds URLs from typed params" do
      href @"/users/:id/:tab?" { id: "42", tab: Nothing } `shouldEqual` "/users/42"
      href @"/users/:id/:tab?" { id: "a b", tab: Just "posts" } `shouldEqual` "/users/a%20b/posts"
      href @"/files/*rest" { rest: "docs/read me.md" } `shouldEqual` "/files/docs/read%20me.md"
      href @"/" {} `shouldEqual` "/"
      href @"/items/:id<int>/:page<int>?" { id: 42, page: Just 2 } `shouldEqual` "/items/42/2"

  solidIt "renders the matched route with its typed params" do
    r <- withRouter "/users/7"
      [ Router.route @"/" \_ -> pure (text "home")
      , Router.route @"/users/:id/:tab?" \props -> pure (user props)
      ]
    html r.mounted >>= shouldEqual "<main><p>user 7 / profile</p></main>"
    liftEffect r.mounted.dispose

  solidIt "navigation updates the view and params reactively" do
    created <- liftEffect (Ref.new 0)
    r <- withRouter "/"
      [ Router.route @"/" \_ -> pure (text "home")
      , Router.route @"/users/:id/:tab?" \props -> do
          liftSetup (Ref.modify_ (_ + 1) created)
          pure (user props)
      ]
    html r.mounted >>= shouldEqual "<main>home</main>"
    go r.navigate (href @"/users/:id/:tab?" { id: "1", tab: Nothing })
    html r.mounted >>= shouldEqual "<main><p>user 1 / profile</p></main>"
    go r.navigate (href @"/users/:id/:tab?" { id: "2", tab: Just "posts" })
    html r.mounted >>= shouldEqual "<main><p>user 2 / posts</p></main>"
    -- Same route: the component is reused.
    liftEffect (Ref.read created) >>= shouldEqual 1
    liftEffect r.mounted.dispose

  solidIt "layout routes render the matched child" do
    r <- withRouter "/settings/profile"
      [ Router.layout @"/settings"
          (\props -> pure (H.section_ [ text "settings:", props.children ]))
          [ Router.route @"/profile" \_ -> pure (text "profile")
          , Router.route @"/billing" \_ -> pure (text "billing")
          ]
      ]
    html r.mounted >>= shouldEqual "<main><section>settings:profile</section></main>"
    go r.navigate "/settings/billing"
    html r.mounted >>= shouldEqual "<main><section>settings:billing</section></main>"
    liftEffect r.mounted.dispose

  solidIt "plain links navigate and the active link is marked" do
    r <- withRouter "/"
      [ Router.route @"/" \_ -> pure (H.a [ P.href (href @"/users/:id/:tab?" { id: "9", tab: Nothing }) ] [ text "open" ])
      , Router.route @"/users/:id/:tab?" \props -> pure (H.div_ [ user props, H.a [ P.id "self", P.href "/users/9" ] [ text "me" ] ])
      ]
    link <- query "a" r.mounted >>= maybe (throwError (error "no link")) pure
    liftEffect (click link)
    settle
    delay (Milliseconds 5.0)
    html r.mounted >>= shouldEqual """<main><div><p>user 9 / profile</p><a id="self" href="/users/9" data-active="" aria-current="page">me</a></div></main>"""
    liftEffect r.mounted.dispose

  describe "Solid.Router.Query" do
    solidIt "back navigation reuses the cached value" do
      q <- countingQuery "backItem"
      r <- withRouter "/" (itemRoutes q.query)
      go r.navigate "/items/1"
      waitLoad
      html r.mounted >>= shouldEqual "<main><p>item 1</p></main>"
      go r.navigate "/"
      html r.mounted >>= shouldEqual "<main>home</main>"
      nav <- liftEffect (Ref.read r.navigate)
      liftEffect (maybe (pure unit) (\n -> Router.go n (-1)) nav)
      waitLoad
      html r.mounted >>= shouldEqual "<main><p>item 1</p></main>"
      liftEffect (Ref.read q.loads) >>= shouldEqual 1
      liftEffect r.mounted.dispose

    solidIt "each argument is cached separately" do
      q <- countingQuery "argItem"
      r <- withRouter "/items/1" (itemRoutes q.query)
      waitLoad
      go r.navigate "/items/2"
      waitLoad
      html r.mounted >>= shouldEqual "<main><p>item 2</p></main>"
      go r.navigate "/items/1"
      waitLoad
      html r.mounted >>= shouldEqual "<main><p>item 1</p></main>"
      liftEffect (Ref.read q.loads) >>= shouldEqual 2
      liftEffect r.mounted.dispose

    solidIt "revalidate reloads the value on screen" do
      q <- countingQuery "revalidatedItem"
      r <- withRouter "/items/1" (itemRoutes q.query)
      waitLoad
      liftEffect (Ref.read q.loads) >>= shouldEqual 1
      liftEffect (revalidate q.query)
      waitLoad
      liftEffect (Ref.read q.loads) >>= shouldEqual 2
      html r.mounted >>= shouldEqual "<main><p>item 1</p></main>"
      liftEffect r.mounted.dispose

  describe "actions" do
    solidIt "useAction returns the result, redirects navigate, submissions are listed" do
      results <- liftEffect (Ref.new [])
      let
        rename = routerAction "rename" \name -> pure (if name == "" then redirect "/done" else reply ("renamed " <> name))
        page = Component.component \_ -> do
          run <- useAction rename
          submissions <- useSubmissions rename
          let submit name = launchAff_ (run name >>= \result -> liftEffect (Ref.modify_ (_ <> [ result ]) results))
          pure $ H.div_
            [ H.button [ P.id "go", P.onClick \_ -> submit "ada" ] [ text "go" ]
            , H.button [ P.id "leave", P.onClick \_ -> submit "" ] [ text "leave" ]
            , text (submissions <#> \list -> show (Array.length list) <> " " <> show (_.result <$> list))
            ]
      r <- withRouter "/" [ Router.route @"/" \_ -> pure (Component.element page {}), Router.route @"/done" \_ -> pure (text "done") ]
      query "#go" r.mounted >>= traverse_ (liftEffect <<< click)
      waitLoad
      liftEffect (Ref.read results) >>= shouldEqual [ Just "renamed ada" ]
      html r.mounted >>= shouldEqual """<main><div><button id="go">go</button><button id="leave">leave</button>1 [(Just "renamed ada")]</div></main>"""
      query "#leave" r.mounted >>= traverse_ (liftEffect <<< click)
      waitLoad
      liftEffect (Ref.read results) >>= shouldEqual [ Just "renamed ada", Nothing ]
      html r.mounted >>= shouldEqual "<main>done</main>"

  describe "route data and navigation" do
    solidIt "int params match integers only and arrive as Int" do
      r <- withRouter "/items/41"
        [ Router.route @"/items/:id<int>" \props -> pure (text (show <<< (_ + 1) <<< _.id <$> props.params))
        , Router.route @"/items/:slug" \props -> pure (text (("slug " <> _) <<< _.slug <$> props.params))
        ]
      html r.mounted >>= shouldEqual "<main>42</main>"
      go r.navigate "/items/abc"
      html r.mounted >>= shouldEqual "<main>slug abc</main>"
      liftEffect r.mounted.dispose

    solidIt "preload runs with the typed params before the route renders" do
      seen <- liftEffect (Ref.new [])
      r <- withRouter "/"
        [ Router.route @"/" \_ -> pure (text "home")
        , Router.routeWith @"/items/:id<int>" { preload: \{ params } -> Ref.modify_ (_ <> [ params.id ]) seen }
            \_ -> pure (text "item")
        ]
      go r.navigate "/items/3"
      html r.mounted >>= shouldEqual "<main>item</main>"
      liftEffect (Ref.read seen) >>= shouldEqual [ 3 ]
      liftEffect r.mounted.dispose

    solidIt "lazy layouts load their child routes on first match" do
      r <- withRouter "/"
        [ Router.route @"/" \_ -> pure (text "home")
        , Router.layoutLazy @"/admin" @"Test.Core.Router.Admin" \props -> pure (H.section_ [ props.children ])
        ]
      go r.navigate "/admin/users"
      waitLoad
      html r.mounted >>= shouldEqual "<main><section>admin users</section></main>"
      liftEffect r.mounted.dispose

    solidIt "useMatch gives the typed params while the location matches" do
      r <- withRouter "/users/7"
        [ Router.route @"*rest" \_ -> do
            match <- Router.useMatch @"/users/:id<int>"
            pure (text (show <$> match))
        ]
      html r.mounted >>= shouldEqual "<main>(Just { id: 7 })</main>"
      go r.navigate "/about"
      waitLoad
      html r.mounted >>= shouldEqual "<main>Nothing</main>"
      go r.navigate "/users/x"
      waitLoad
      html r.mounted >>= shouldEqual "<main>Nothing</main>"
      liftEffect r.mounted.dispose

    solidIt "navigation state, search params and link state" do
      r <- withRouter "/list?tag=a&tag=b"
        [ Router.route @"/list" \_ -> do
            location <- Router.useLocation
            search <- useSearch @(tag :: Array String, page :: Maybe Int)
            link <- Router.useLinkState (pure "/list")
            pure $ H.div_
              [ text (show <<< _.tag <$> searchParams search)
              , text (show <<< map toString <$> Router.locationState location)
              , text (link.current <#> \c -> if c then " current" else "")
              , H.button [ P.id "page", P.onClick \_ -> setSearch search { page: Just 2 } ] [ text "" ]
              , H.button [ P.id "tags", P.onClick \_ -> setSearch search { tag: [ "x", "y" ], page: Nothing } ] [ text "" ]
              , text (show <<< _.page <$> searchParams search)
              ]
        ]
      let buttons = """<button id="page"></button><button id="tags"></button>"""
      html r.mounted >>= shouldEqual ("""<main><div>["a","b"]Nothing current""" <> buttons <> """Nothing</div></main>""")
      query "#page" r.mounted >>= traverse_ (liftEffect <<< click)
      waitLoad
      html r.mounted >>= shouldEqual ("""<main><div>["a","b"]Nothing current""" <> buttons <> """(Just 2)</div></main>""")
      query "#tags" r.mounted >>= traverse_ (liftEffect <<< click)
      waitLoad
      html r.mounted >>= shouldEqual ("""<main><div>["x","y"]Nothing current""" <> buttons <> """Nothing</div></main>""")
      nav <- liftEffect (Ref.read r.navigate)
      liftEffect (traverse_ (\n -> Router.navigateWith { state: fromString "hi" } n "/list") nav)
      waitLoad
      html r.mounted >>= shouldEqual ("""<main><div>[](Just (Just "hi")) current""" <> buttons <> """Nothing</div></main>""")
      liftEffect r.mounted.dispose

    solidIt "useBeforeLeave can block a navigation and retry it" do
      pending <- liftEffect (Ref.new Nothing)
      r <- withRouter "/edit"
        [ Router.route @"/edit" \_ -> do
            Router.useBeforeLeave \leave -> do
              held <- Ref.read pending
              case held of
                Nothing -> leave.preventDefault *> Ref.write (Just leave.forceRetry) pending
                Just _ -> pure unit
            pure (text "editing")
        , Router.route @"/done" \_ -> pure (text "done")
        ]
      go r.navigate "/done"
      html r.mounted >>= shouldEqual "<main>editing</main>"
      liftEffect (Ref.read pending) >>= traverse_ liftEffect
      waitLoad
      html r.mounted >>= shouldEqual "<main>done</main>"
      liftEffect r.mounted.dispose

  solidIt "onSubmit makes optimistic writes; onSettled sees every run" do
    settled <- liftEffect (Ref.new [])
    saving /\ setSaving <- liftEffect (createOptimistic false)
    let
      save = routerAction "save" (\n -> delay (Milliseconds 10.0) $> reply (n * 2))
        # onSubmit (\_ -> setOptimistic setSaving true)
        # onSettled (\s -> Ref.modify_ (_ <> [ s.result ]) settled)
      page = Component.component \_ -> do
        run <- useAction save
        pure (H.button [ P.id "save", P.onClick \_ -> launchAff_ (void (run 21)) ] [ text (show <$> saving) ])
    r <- withRouter "/" [ Router.route @"/" \_ -> pure (Component.element page {}) ]
    query "#save" r.mounted >>= traverse_ (liftEffect <<< click)
    settle
    during <- liftEffect (get saving)
    delay (Milliseconds 30.0)
    waitLoad
    after <- liftEffect (get saving)
    { during, after } `shouldEqual` { during: true, after: false }
    liftEffect (Ref.read settled) >>= shouldEqual [ Just 42 ]
    liftEffect r.mounted.dispose

