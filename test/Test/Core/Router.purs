module Test.Core.Router
  ( spec
  ) where

import Prelude

import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Effect.Aff (Aff, Milliseconds(..), delay, throwError)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Solid.Component as Component
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (JSX, text)
import Solid.Router (href)
import Solid.Router as Router
import Solid.Setup (liftSetup)
import Test.Solid (Mounted, click, html, mount, query, settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Effect.Exception (error)

-- | Renders a router over memory history and hands back its navigator.
withRouter :: String -> Array Router.Route -> Aff { mounted :: Mounted, navigate :: Ref.Ref (Maybe Router.Navigate) }
withRouter url routes = do
  navigateRef <- liftEffect (Ref.new Nothing)
  history <- liftEffect (Router.memoryHistory url)
  router <- liftEffect (Router.createRouter Router.defaultRouterConfig { routes = routes, history = Just history })
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

spec :: Spec Unit
spec = describe "Solid.Router" do
  describe "href" do
    solidIt "builds URLs from typed params" do
      href @"/users/:id/:tab?" { id: "42", tab: Nothing } `shouldEqual` "/users/42"
      href @"/users/:id/:tab?" { id: "a b", tab: Just "posts" } `shouldEqual` "/users/a%20b/posts"
      href @"/files/*rest" { rest: "docs/read me.md" } `shouldEqual` "/files/docs/read%20me.md"
      href @"/" {} `shouldEqual` "/"

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
    -- Same route: the component is reused and its params accessor updates.
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
