module Test.Core.View
  ( spec
  ) where

import Prelude

import DOM.HTML.Indexed.InputType (InputType(..))

import Data.Generic.Rep (class Generic)
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
import Solid.DOM (element, targetChecked, targetValue)
import Solid.DOM.Aria as Aria
import Solid.DOM.HTML as H
import Solid.DOM.SVG as S
import Solid.JSX (text)
import Solid.Meta as Meta
import Solid.JSX as JSX
import Solid.Setup (liftSetup)
import Solid.Signal (Accessor, Setter, createSignal, set)
import Solid.Signal as Signal
import Solid.Errors (isSafeError, markSafeError)
import Solid.Web as Web
import Test.Solid (Mounted, click, html, inputText, mount, mountUsing, query, settle, solidIt)
import Unsafe.Reference (unsafeRefEq)
import Web.DOM.Element (Element, getAttribute, namespaceURI)
import Web.HTML.HTMLInputElement as HTMLInputElement
import Web.HTML.HTMLElement as HTMLElement
import Data.Traversable (traverse)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Effect (Effect)

data Page = Home | Profile Int

derive instance Generic Page _

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
      mounted <- mount $ H.div { id: "greeting", class: "box" } [ H.span {} "hello", text " world" ]
      html mounted >>= shouldEqual """<div id="greeting" class="box"><span>hello</span> world</div>"""
      liftEffect mounted.dispose

    solidIt "reactive attributes and text update in place" do
      label <- signal "one"
      active <- signal false
      mounted <- mount $ H.p { title: label.get, class: { item: true, active: active.get } } label.get
      html mounted >>= shouldEqual """<p title="one" class="item">one</p>"""
      before <- expectElement "p" mounted
      write label "two"
      write active true
      after <- expectElement "p" mounted
      html mounted >>= shouldEqual """<p title="two" class="item active">two</p>"""
      unsafeRefEq before after `shouldEqual` true
      liftEffect mounted.dispose

    solidIt "boolean attributes are present or absent" do
      disabled <- signal true
      mounted <- mount $ H.button { disabled: disabled.get } "go"
      button <- expectElement "button" mounted
      liftEffect (getAttribute "disabled" button) >>= shouldEqual (Just "")
      write disabled false
      liftEffect (getAttribute "disabled" button) >>= shouldEqual Nothing
      liftEffect mounted.dispose

    solidIt "form state is set as a DOM property" do
      draft <- signal "abc"
      mounted <- mount $ H.input { value: draft.get, "data-role": "draft" }
      input <- expectElement "input" mounted
      liftEffect (inputValue input) >>= shouldEqual "abc"
      write draft "xyz"
      liftEffect (inputValue input) >>= shouldEqual "xyz"
      liftEffect (getAttribute "data-role" input) >>= shouldEqual (Just "draft")
      liftEffect mounted.dispose

    solidIt "delegated events reach their handlers" do
      count <- signal 0
      mounted <- mount $ H.button { onClick: \_ -> Signal.modify_ count.set (_ + 1) } (show <$> count.get)
      button <- expectElement "button" mounted
      liftEffect (click button *> click button)
      html mounted >>= shouldEqual "<button>2</button>"
      liftEffect mounted.dispose

    solidIt "input events deliver the new value" do
      typed <- signal ""
      mounted <- mount $ H.div {}
        [ H.input { onInput: \event -> targetValue event >>= set typed.set }
        , text typed.get
        ]
      input <- expectElement "input" mounted
      liftEffect (inputText "hi" input)
      html mounted >>= shouldEqual "<div><input>hi</div>"
      liftEffect mounted.dispose

    solidIt "targetChecked reads the checkbox the handler is on" do
      checked <- signal false
      mounted <- mount $ H.div {}
        [ H.input { type: InputCheckbox, onChange: \event -> targetChecked event >>= set checked.set }
        , text (show <$> checked.get)
        ]
      input <- expectElement "input" mounted
      liftEffect (click input)
      html mounted >>= shouldEqual """<div><input type="checkbox">true</div>"""
      liftEffect mounted.dispose

    solidIt "bindValue and bindChecked bind both ways" do
      name <- signal "ada"
      done <- signal false
      mounted <- mount $ H.div {}
        [ H.input { id: "name", bindValue: name.get /\ name.set }
        , H.input { id: "done", type: InputCheckbox, bindChecked: done.get /\ done.set }
        , text name.get
        , text (show <$> done.get)
        ]
      nameInput <- expectElement "#name" mounted
      doneInput <- expectElement "#done" mounted
      let
        inputState element = liftEffect $ traverse
          (\input -> { value: _, checked: _ } <$> HTMLInputElement.value input <*> HTMLInputElement.checked input)
          (HTMLInputElement.fromElement element)
      inputState nameInput >>= shouldEqual (Just { value: "ada", checked: false })
      liftEffect (inputText "grace" nameInput *> click doneInput)
      settle
      html mounted >>= shouldEqual """<div><input id="name"><input id="done" type="checkbox">gracetrue</div>"""
      write name "lin"
      write done false
      inputState nameInput >>= shouldEqual (Just { value: "lin", checked: false })
      inputState doneInput >>= shouldEqual (Just { value: "on", checked: false })
      liftEffect mounted.dispose

    solidIt "style takes CSS text or a record of properties" do
      colour <- signal "red"
      mounted <- mount $ H.div {}
        [ H.p { style: { color: colour.get, margin: "0" } } "a"
        , H.p { style: "padding: 1px" } "b"
        , H.p { textContent: "replaced" } []
        , H.p { innerHTML: "<b>bold</b>" } []
        ]
      html mounted >>= shouldEqual """<div><p style="color: red; margin: 0px;">a</p><p style="padding: 1px;">b</p><p>replaced</p><p><b>bold</b></p></div>"""
      write colour "green"
      html mounted >>= shouldEqual """<div><p style="color: green; margin: 0px;">a</p><p style="padding: 1px;">b</p><p>replaced</p><p><b>bold</b></p></div>"""
      liftEffect mounted.dispose

    solidIt "class toggles follow their accessors" do
      done <- signal false
      mounted <- mount $ H.li { class: { todo: true, done: done.get, editing: false } } "a"
      html mounted >>= shouldEqual """<li class="todo">a</li>"""
      write done true
      html mounted >>= shouldEqual """<li class="todo done">a</li>"""
      liftEffect mounted.dispose

    solidIt "role, typed aria attributes and custom events" do
      expanded <- signal false
      seen <- liftEffect (Ref.new 0)
      mounted <- mount $ H.button
        { role: "switch", "aria-expanded": expanded.get, "aria-level": 2, "aria-checked": Aria.Mixed, "aria-relevant": Aria.additions <> Aria.text, "on:ping": \_ -> Ref.modify_ (_ + 1) seen }
        "menu"
      button <- expectElement "button" mounted
      liftEffect (dispatch "ping" button)
      liftEffect (Ref.read seen) >>= shouldEqual 1
      html mounted >>= shouldEqual """<button aria-checked="mixed" aria-expanded="false" aria-level="2" aria-relevant="additions text" role="switch">menu</button>"""
      write expanded true
      liftEffect (getAttribute "aria-expanded" button) >>= shouldEqual (Just "true")
      liftEffect mounted.dispose

    solidIt "element takes any tag and any fields" do
      clicks <- signal 0
      mounted <- mount $ element "my-widget"
        { "label-text": "hi", count: 2, onClick: \_ -> Signal.modify_ clicks.set (_ + 1) }
        (show <$> clicks.get)
      widget <- expectElement "my-widget" mounted
      liftEffect (click widget)
      html mounted >>= shouldEqual """<my-widget count="2" label-text="hi">1</my-widget>"""
      liftEffect mounted.dispose

    solidIt "refs receive the element" do
      seen <- liftEffect (Ref.new "")
      mounted <- mount $ H.section { id: "target", ref: \section -> tagName (HTMLElement.toElement section) >>= flip Ref.write seen } []
      liftEffect (Ref.read seen) >>= shouldEqual "SECTION"
      liftEffect mounted.dispose

    solidIt "SVG elements use the SVG namespace" do
      mounted <- mount $ S.svg { viewBox: "0 0 10 10" } (S.circle { cx: "5", cy: "5", r: "4" } [])
      circle <- expectElement "circle" mounted
      namespaceURI circle `shouldEqual` Just "http://www.w3.org/2000/svg"
      svg <- expectElement "svg" mounted
      liftEffect (getAttribute "viewBox" svg) >>= shouldEqual (Just "0 0 10 10")
      liftEffect mounted.dispose

    solidIt "dispose removes the view" do
      mounted <- mount (H.p {} "bye")
      liftEffect mounted.dispose
      html mounted >>= shouldEqual ""

  describe "JSX is a description" do
    solidIt "the same value renders independent copies" do
      let badge = H.b {} "x"
      mounted <- mount (H.div {} [ badge, badge ])
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
      mounted <- mount $ H.ul {} (Control.forEach items.get \item _ -> pure (H.li { id: item } item))
      firstA <- expectElement "#a" mounted
      write items [ "c", "a" ]
      html mounted >>= shouldEqual """<ul><li id="c">c</li><li id="a">a</li></ul>"""
      laterA <- expectElement "#a" mounted
      unsafeRefEq firstA laterA `shouldEqual` true
      liftEffect mounted.dispose

    solidIt "forEachUnkeyed and repeat" do
      items <- signal [ 1, 2 ]
      count <- signal 2
      mounted <- mount $ H.div {}
        [ Control.forEachUnkeyed items.get \item _ -> pure (text (show <$> item))
        , text "|"
        , Control.repeat count.get \i -> pure (text (show i))
        ]
      write items [ 7, 8 ]
      write count 3
      html mounted >>= shouldEqual "<div>78|012</div>"
      liftEffect mounted.dispose

    solidIt "forEachBy updates a view in place when its key stays" do
      items <- signal [ { id: 1, label: "a" }, { id: 2, label: "b" } ]
      mounted <- mount $ H.ul {}
        (Control.forEachByElse _.id items.get (\item _ -> pure (H.li { id: show <<< _.id <$> item } (_.label <$> item))) (text "empty"))
      first <- expectElement "[id='1']" mounted
      write items [ { id: 2, label: "b" }, { id: 1, label: "A" } ]
      html mounted >>= shouldEqual """<ul><li id="2">b</li><li id="1">A</li></ul>"""
      later <- expectElement "[id='1']" mounted
      unsafeRefEq first later `shouldEqual` true
      write items []
      html mounted >>= shouldEqual "<ul>empty</ul>"
      liftEffect mounted.dispose

    solidIt "list fallbacks show while there is nothing to render" do
      items <- signal ([] :: Array Int)
      count <- signal 0
      mounted <- mount $ H.div {}
        [ Control.forEachUnkeyedElse items.get (\item _ -> pure (text (show <$> item))) (text "no items")
        , text "|"
        , Control.repeatElse count.get (\i -> pure (text (show i))) (text "zero")
        ]
      html mounted >>= shouldEqual "<div>no items|zero</div>"
      write items [ 4 ]
      write count 2
      html mounted >>= shouldEqual "<div>4|01</div>"
      liftEffect mounted.dispose

    solidIt "reveal takes any subset of its options" do
      mounted <- mount $ H.div {}
        [ Control.reveal {} [ text "a" ]
        , Control.reveal { order: Control.together, collapsed: true } [ text "b" ]
        ]
      html mounted >>= shouldEqual "<div>ab</div>"
      liftEffect mounted.dispose

    solidIt "caseOn rebuilds a branch only when its key changes" do
      page <- signal (Profile 1)
      built <- liftEffect (Ref.new 0)
      mounted <- mount $ Control.caseOn Control.constructorName page.get \current latest -> do
        liftSetup (Ref.modify_ (_ + 1) built)
        pure case current of
          Home -> text "home"
          Profile _ -> text
            ( latest <#> case _ of
                Profile id -> "profile " <> show id
                Home -> ""
            )
      html mounted >>= shouldEqual "profile 1"
      write page (Profile 2)
      html mounted >>= shouldEqual "profile 2"
      write page Home
      html mounted >>= shouldEqual "home"
      liftEffect (Ref.read built) >>= shouldEqual 2
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

    solidIt "renderWith's onError sees what an errored boundary catches" do
      seen <- liftEffect (Ref.new [])
      let broken = Component.component \_ -> unsafeCrashWith "boom"
      mounted <- mountUsing (Web.renderWith { onError: \e -> Ref.modify_ (_ <> [ message e ]) seen })
        (Control.errored (\_ _ -> pure (text "fallback")) (Component.element broken {}))
      html mounted >>= shouldEqual "fallback"
      liftEffect (Ref.read seen) >>= shouldEqual [ "boom" ]
      liftEffect mounted.dispose

    solidIt "markSafeError brands an error" do
      plain <- liftEffect (isSafeError (error "plain"))
      marked <- liftEffect (markSafeError (error "safe") >>= isSafeError)
      { plain, marked } `shouldEqual` { plain: false, marked: true }

    solidIt "loadingOn shows the fallback again when its key changes" do
      id <- signal 1
      mounted <- mount $ Component.element
        ( Component.component \_ -> do
            item /\ _ <- createAsync (id.get <#> \n -> delay (Milliseconds 20.0) $> ("item " <> show n))
            pure (Control.loadingOn id.get (text "loading") (text item))
        )
        {}
      delay (Milliseconds 40.0)
      html mounted >>= shouldEqual "item 1"
      write id 2
      html mounted >>= shouldEqual "loading"
      delay (Milliseconds 40.0)
      html mounted >>= shouldEqual "item 2"
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
        region = Component.component \_ -> pure
          $ JSX.reactive
          $ broken.get <#> \isBroken ->
              if isBroken then unsafeCrashWith "later" else text "fine"
        initiallyBroken = Component.component \_ -> pure $
          JSX.reactive ((pure unit :: Accessor Unit) <#> \_ -> unsafeCrashWith "boom")
        boundary content = Control.errored (\err _ -> pure (text (message <$> err))) content
      first <- mount (boundary (Component.element initiallyBroken {}))
      html first >>= shouldEqual "boom"
      liftEffect first.dispose
      second <- mount (boundary (Component.element region {}))
      html second >>= shouldEqual "fine"
      write broken true
      html second >>= shouldEqual "later"
      liftEffect second.dispose

  describe "head tags" do
    solidIt "a reactive title updates document.title" do
      unread <- signal 2
      mounted <- mount (Meta.title (unread.get <#> \n -> "Inbox (" <> show n <> ")"))
      settle
      liftEffect documentTitle >>= shouldEqual "Inbox (2)"
      write unread 3
      liftEffect documentTitle >>= shouldEqual "Inbox (3)"
      liftEffect mounted.dispose

  describe "components and context" do
    solidIt "components receive plain record props" do
      count <- signal 1
      let
        counter = Component.component \props -> pure $
          H.span {} [ text props.label, text ": ", text (show <$> props.count) ]
      mounted <- mount (Component.element counter { label: "clicks", count: count.get })
      html mounted >>= shouldEqual "<span>clicks: 1</span>"
      write count 2
      html mounted >>= shouldEqual "<span>clicks: 2</span>"
      liftEffect mounted.dispose

    solidIt "provided context reaches nested components" do
      let theme = createContext "test.theme" "light"
      let
        label = Component.component \_ -> do
          current <- useContext theme
          pure (H.em {} current)
      mounted <- mount $ H.div {}
        [ Component.element label {}
        , provide theme "dark" (pure (Component.element label {}))
        ]
      html mounted >>= shouldEqual "<div><em>light</em><em>dark</em></div>"
      liftEffect mounted.dispose

foreign import inputValue :: Element -> Effect String
foreign import tagName :: Element -> Effect String
foreign import documentTitle :: Effect String
foreign import dispatch :: String -> Element -> Effect Unit
