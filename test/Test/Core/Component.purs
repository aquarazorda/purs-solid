module Test.Core.Component
  ( spec
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import Effect.Ref as Ref
import Solid.Component as Component
import Solid.Component.JS (JsComponent, jsElement)
import Solid.Control as Control
import Solid.JSX as JSX
import Solid.Root (createRoot)
import Solid.DOM.HTML as H
import Solid.JSX (JSX)
import Solid.Signal (Accessor, createSignal, set)
import Test.Solid (html, jsxValue, mount, solidIt)
import Web.DOM.Element (Element)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

greeting :: Component.Component { name :: String }
greeting = Component.component \props -> pure (JSX.text ("hello " <> props.name))

foreign import badge
  :: JsComponent
       ( label :: Accessor String
       , suffix :: Maybe String
       , onPick :: String -> Effect Unit
       , renderItem :: Int -> JSX
       , children :: Array JSX
       )

foreign import clickFirstSpan :: Element -> Effect Unit

spec :: Spec Unit
spec = describe "Solid.Component" do
  describe "JS components" do
    solidIt "props arrive as getters, callbacks, render callbacks and children" do
      picked <- liftEffect (Ref.new "")
      label /\ setLabel <- liftEffect (createSignal "ada")
      let
        use suffix = jsElement badge
          { label
          , suffix
          , onPick: \l -> Ref.write l picked
          , renderItem: \n -> H.em_ [ JSX.text (show n) ]
          , children: [ JSX.text "a", H.u_ [ JSX.text "b" ] ]
          }
      mounted <- mount (H.div_ [ use Nothing, use (Just "?") ])
      html mounted >>= shouldEqual
        "<div><span>ada!</span><i><em>3</em></i><b>a<u>b</u></b><span>ada?</span><i><em>3</em></i><b>a<u>b</u></b></div>"
      liftEffect (set setLabel "grace")
      html mounted >>= shouldEqual
        "<div><span>grace!</span><i><em>5</em></i><b>a<u>b</u></b><span>grace?</span><i><em>5</em></i><b>a<u>b</u></b></div>"
      liftEffect (clickFirstSpan mounted.root)
      liftEffect (Ref.read picked) >>= shouldEqual "grace"
      liftEffect mounted.dispose

    solidIt "props can be left out" do
      label /\ _ <- liftEffect (createSignal "ada")
      mounted <- mount (jsElement badge { label, onPick: \_ -> pure unit, renderItem: \_ -> JSX.empty, children: [] })
      html mounted >>= shouldEqual "<span>ada!</span><i></i><b></b>"
      liftEffect mounted.dispose

  solidIt "element renders a component with its props" do
    rendered <- liftEffect do
      view <- createRoot \_ -> pure (Component.element greeting { name: "ada" })
      jsxValue view
    rendered `shouldEqual` "hello ada"

  solidIt "children resolves once and can be placed in the view" do
    let
      wrapper = Component.component \props -> do
        resolved <- Component.children (pure props.child)
        pure (H.section_ [ JSX.reactive resolved ])
    mounted <- mount (Component.element wrapper { child: JSX.text "child" })
    html mounted >>= shouldEqual "<section>child</section>"
    liftEffect mounted.dispose

  solidIt "lazy loads the definition on first use, under loading" do
    let lazyGreeting = Component.lazy @"Test.Core.Component.Greeting.greeting" :: Component.Component { name :: String }
    mounted <- mount (Control.loading (JSX.text "loading") (Component.element lazyGreeting { name: "lin" }))
    html mounted >>= shouldEqual "loading"
    delay (Milliseconds 20.0)
    html mounted >>= shouldEqual "hello lin"
    liftEffect mounted.dispose

  solidIt "lazy fails clearly when the export isn't a component" do
    let notComponent = Component.lazy @"Test.Core.Component.Greeting.answer" :: Component.Component {}
    mounted <- mount $ Control.errored (\err _ -> pure (JSX.text (message <$> err)))
      (Control.loading (JSX.text "loading") (Component.element notComponent {}))
    delay (Milliseconds 20.0)
    html mounted >>= shouldEqual "purs-solid: Test.Core.Component.Greeting.answer is loaded lazily, but it isn't a component"
    liftEffect mounted.dispose

  solidIt "preload starts loading before first use" do
    let lazyGreeting = Component.lazy @"Test.Core.Component.Greeting.greeting" :: Component.Component { name :: String }
    liftEffect (Component.preload lazyGreeting)
    delay (Milliseconds 20.0)
    mounted <- mount (Control.loading (JSX.text "loading") (Component.element lazyGreeting { name: "lin" }))
    html mounted >>= shouldEqual "hello lin"
    liftEffect mounted.dispose

  solidIt "childrenArray lists the resolved children" do
    let
      counter = Component.component \props -> do
        list <- Component.childrenArray (pure props.child)
        pure (JSX.text (show <<< Array.length <$> list))
    mounted <- mount (Component.element counter { child: JSX.fragment [ JSX.text "a", JSX.text "b", JSX.text "c" ] })
    html mounted >>= shouldEqual "3"
    liftEffect mounted.dispose

  solidIt "createUniqueId returns distinct ids" do
    ids <- liftEffect $ createRoot \_ -> do
      a <- Component.createUniqueId
      b <- Component.createUniqueId
      pure { a, b }
    (ids.a /= ids.b && String.length ids.a > 0) `shouldEqual` true

  solidIt "clientOnly shows the fallback until the component has loaded" do
    chart <- liftEffect (Ref.new unit) <#> \_ -> Component.clientOnly @"Test.Core.Component.Chart.chart"
    mounted <- mount (Component.element chart { fallback: JSX.text "…", name: "lin" })
    html mounted >>= shouldEqual "…"
    delay (Milliseconds 20.0)
    html mounted >>= shouldEqual "hello lin"
    liftEffect mounted.dispose
