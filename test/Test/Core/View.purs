module Test.Core.View
  ( spec
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect.Aff (Aff, Milliseconds(..), delay, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (error, message)
import Effect.Ref as Ref
import Partial.Unsafe (unsafeCrashWith)
import Solid.Async (createAsync)
import Solid.Component as Component
import Solid.Context (createContext, provide, useContext)
import Solid.Control as Control
import Solid.DOM (classWhen, dataAttr, ref)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.DOM.SVG as S
import Solid.DOM.SVG.Props as SP
import Solid.JSX (text)
import Solid.JSX as JSX
import Solid.Setup (liftSetup)
import Solid.Signal (Accessor, Setter, createSignal, set)
import Solid.Signal as Signal
import Test.Solid (Mounted, attribute, click, html, inputText, mount, namespaceOf, query, refEq, settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Effect (Effect)
import Web.DOM.Element (Element)
import Web.Event.Event (Event)

-- | A signal created outside any view, so tests can drive it.
signal :: forall a. a -> Aff { get :: Accessor a, set :: Setter a }
signal initial = liftEffect do
  value /\ setter <- createSignal initial
  pure { get: value, set: setter }

write :: forall a. { get :: Accessor a, set :: Setter a } -> a -> Aff Unit
write s value = liftEffect (set s.set value) *> settle

expectElement :: String -> Mounted -> Aff Element
expectElement selector mounted = query selector mounted >>= case _ of
  Just element -> pure element
  Nothing -> liftEffect (throwError (error ("no element for " <> selector)))

spec :: Spec Unit
spec = describe "views" do
  describe "elements and props" do
    solidIt "renders static elements, attributes and text" do
      mounted <- mount $ H.div [ P.id "greeting", P.class_ "box" ] [ H.span_ [ text "hello" ], text " world" ]
      html mounted >>= shouldEqual """<div id="greeting" class="box"><span>hello</span> world</div>"""
      liftEffect mounted.dispose

    solidIt "reactive attributes and text update in place" do
      label <- signal "one"
      active <- signal false
      mounted <- mount $ H.p [ P.title label.get, classWhen "active" active.get, P.class_ "item" ] [ text label.get ]
      html mounted >>= shouldEqual """<p title="one" class="item">one</p>"""
      before <- expectElement "p" mounted
      write label "two"
      write active true
      after <- expectElement "p" mounted
      html mounted >>= shouldEqual """<p title="two" class="item active">two</p>"""
      refEq before after `shouldEqual` true
      liftEffect mounted.dispose

    solidIt "boolean attributes are present or absent" do
      disabled <- signal true
      mounted <- mount $ H.button [ P.disabled disabled.get ] [ text "go" ]
      button <- expectElement "button" mounted
      liftEffect (attribute "disabled" button) >>= shouldEqual (Just "")
      write disabled false
      liftEffect (attribute "disabled" button) >>= shouldEqual Nothing
      liftEffect mounted.dispose

    solidIt "form state is set as a DOM property" do
      draft <- signal "abc"
      mounted <- mount $ H.input [ P.value draft.get, dataAttr "role" "draft" ]
      input <- expectElement "input" mounted
      liftEffect (inputValue input) >>= shouldEqual "abc"
      write draft "xyz"
      liftEffect (inputValue input) >>= shouldEqual "xyz"
      liftEffect (attribute "data-role" input) >>= shouldEqual (Just "draft")
      liftEffect mounted.dispose

    solidIt "delegated events reach their handlers" do
      count <- signal 0
      mounted <- mount $ H.button [ P.onClick \_ -> Signal.modify_ count.set (_ + 1) ] [ text (show <$> count.get) ]
      button <- expectElement "button" mounted
      liftEffect (click button *> click button)
      html mounted >>= shouldEqual "<button>2</button>"
      liftEffect mounted.dispose

    solidIt "input events deliver the new value" do
      typed <- signal ""
      mounted <- mount $ H.div_
        [ H.input [ P.onInput \event -> targetValue event >>= set typed.set ]
        , text typed.get
        ]
      input <- expectElement "input" mounted
      liftEffect (inputText "hi" input)
      html mounted >>= shouldEqual "<div><input>hi</div>"
      liftEffect mounted.dispose

    solidIt "refs receive the element" do
      seen <- liftEffect (Ref.new "")
      mounted <- mount $ H.section [ P.id "target", ref \element -> tagName element >>= flip Ref.write seen ] []
      liftEffect (Ref.read seen) >>= shouldEqual "SECTION"
      liftEffect mounted.dispose

    solidIt "SVG elements use the SVG namespace" do
      mounted <- mount $ S.svg [ SP.viewBox "0 0 10 10" ] [ S.circle [ SP.cx "5", SP.cy "5", SP.r "4" ] [] ]
      circle <- expectElement "circle" mounted
      liftEffect (namespaceOf circle) >>= shouldEqual "http://www.w3.org/2000/svg"
      svg <- expectElement "svg" mounted
      liftEffect (attribute "viewBox" svg) >>= shouldEqual (Just "0 0 10 10")
      liftEffect mounted.dispose

    solidIt "dispose removes the view" do
      mounted <- mount (H.p_ [ text "bye" ])
      liftEffect mounted.dispose
      html mounted >>= shouldEqual ""

  describe "JSX is a description" do
    solidIt "the same value renders independent copies" do
      let badge = H.b_ [ text "x" ]
      mounted <- mount (H.div_ [ badge, badge ])
      html mounted >>= shouldEqual "<div><b>x</b><b>x</b></div>"
      liftEffect mounted.dispose

    solidIt "hidden branches are not created" do
      created <- liftEffect (Ref.new 0)
      visible <- signal false
      let
        probe = Component.component \_ -> do
          liftSetup (Ref.modify_ (_ + 1) created)
          pure (text "probe")
      mounted <- mount (Control.whenElse visible.get (Component.element probe {}) (text "hidden"))
      html mounted >>= shouldEqual "hidden"
      liftEffect (Ref.read created) >>= shouldEqual 0
      write visible true
      html mounted >>= shouldEqual "probe"
      liftEffect (Ref.read created) >>= shouldEqual 1
      liftEffect mounted.dispose

  describe "control flow" do
    solidIt "showMaybe renders Just values, including falsy ones" do
      value <- signal (Nothing :: Maybe Int)
      mounted <- mount (Control.showMaybeElse value.get (\n -> pure (text (show <$> n))) (text "none"))
      html mounted >>= shouldEqual "none"
      write value (Just 0)
      html mounted >>= shouldEqual "0"
      write value (Just 5)
      html mounted >>= shouldEqual "5"
      liftEffect mounted.dispose

    solidIt "forEach keeps each item's DOM when the list reorders" do
      items <- signal [ "a", "b", "c" ]
      mounted <- mount $ H.ul_ [ Control.forEach items.get \item _ -> pure (H.li [ P.id item ] [ text item ]) ]
      firstA <- expectElement "#a" mounted
      write items [ "c", "a" ]
      html mounted >>= shouldEqual """<ul><li id="c">c</li><li id="a">a</li></ul>"""
      laterA <- expectElement "#a" mounted
      refEq firstA laterA `shouldEqual` true
      liftEffect mounted.dispose

    solidIt "forEachUnkeyed and repeat" do
      items <- signal [ 1, 2 ]
      count <- signal 2
      mounted <- mount $ H.div_
        [ Control.forEachUnkeyed items.get \item _ -> pure (text (show <$> item))
        , text "|"
        , Control.repeat count.get \i -> pure (text (show i))
        ]
      write items [ 7, 8 ]
      write count 3
      html mounted >>= shouldEqual "<div>78|012</div>"
      liftEffect mounted.dispose

    solidIt "switch renders the first matching case" do
      n <- signal 1
      mounted <- mount $ Control.switch
        [ Control.match ((_ < 0) <$> n.get) (text "negative")
        , Control.matchMaybe ((\x -> if x > 0 then Just x else Nothing) <$> n.get) \x -> pure (text ("positive " <> show x))
        ]
        (text "zero")
      html mounted >>= shouldEqual "positive 1"
      write n 0
      html mounted >>= shouldEqual "zero"
      write n (-3)
      html mounted >>= shouldEqual "negative"
      liftEffect mounted.dispose

    solidIt "errored renders the fallback with the error" do
      let
        broken = Component.component \_ -> unsafeCrashWith "boom"
      mounted <- mount $ Control.errored
        (\err _reset -> pure (text (message <$> err)))
        (Component.element broken {})
      html mounted >>= shouldEqual "boom"
      liftEffect mounted.dispose

    solidIt "loading shows the fallback until async content is ready" do
      let
        slow = Component.component \_ -> do
          greeting /\ _ <- createAsync (pure (delay (Milliseconds 20.0) $> "ready"))
          pure (text greeting)
      mounted <- mount (Control.loading (text "loading") (Component.element slow {}))
      html mounted >>= shouldEqual "loading"
      delay (Milliseconds 40.0)
      html mounted >>= shouldEqual "ready"
      liftEffect mounted.dispose

    solidIt "errored catches errors from a reactive region, initially and after updates" do
      broken <- signal false
      let
        region = Component.component \_ -> pure $
          JSX.reactive $ broken.get <#> \isBroken ->
            if isBroken then unsafeCrashWith "later" else text "fine"
        initiallyBroken = Component.component \_ -> pure $
          JSX.reactive (pure unit <#> \_ -> unsafeCrashWith "boom")
        boundary content = Control.errored (\err _ -> pure (text (message <$> err))) content
      first <- mount (boundary (Component.element initiallyBroken {}))
      html first >>= shouldEqual "boom"
      liftEffect first.dispose
      second <- mount (boundary (Component.element region {}))
      html second >>= shouldEqual "fine"
      write broken true
      html second >>= shouldEqual "later"
      liftEffect second.dispose

  describe "components and context" do
    solidIt "components receive plain record props" do
      count <- signal 1
      let
        counter = Component.component \props -> pure $
          H.span_ [ text props.label, text ": ", text (show <$> props.count) ]
      mounted <- mount (Component.element counter { label: "clicks", count: count.get })
      html mounted >>= shouldEqual "<span>clicks: 1</span>"
      write count 2
      html mounted >>= shouldEqual "<span>clicks: 2</span>"
      liftEffect mounted.dispose

    solidIt "provided context reaches nested components" do
      theme <- liftEffect (createContext "light")
      let
        label = Component.component \_ -> do
          current <- useContext theme
          pure (H.em_ [ text current ])
      mounted <- mount $ H.div_
        [ Component.element label {}
        , provide theme "dark" (pure (Component.element label {}))
        ]
      html mounted >>= shouldEqual "<div><em>light</em><em>dark</em></div>"
      liftEffect mounted.dispose

foreign import inputValue :: Element -> Effect String
foreign import targetValue :: Event -> Effect String
foreign import tagName :: Element -> Effect String
