module Test.Server.SSR
  ( spec
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Argonaut.Core (Json, fromString, toString)
import Data.Either (Either, either, note)
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), contains, stripPrefix)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (Error, message)
import Effect.Ref as Ref
import Partial.Unsafe (unsafeCrashWith)
import Solid.Async (createAsync, createAsyncWith, serialized, withCodec)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM.HTML as H
import Solid.DOM.SVG as S
import Solid.JSX (JSX, text)
import Solid.Signal (createSignal)
import Solid.Web.SSR as SSR
import Test.Solid (expectDiagnostic, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)
import Web.Streams.ReadableStream (ReadableStream)
import Data.ArrayBuffer.Types (Uint8Array)

render :: JSX -> Aff String
render view = liftEffect (SSR.renderToString view) >>= orFail

renderAsync :: JSX -> Aff String
renderAsync view = SSR.renderToStringAsync view >>= orFail

orFail :: forall a. Either Error a -> Aff a
orFail = either throwError pure

has :: String -> String -> Boolean
has fragment = contains (Pattern fragment)

foreign import readAllImpl :: ReadableStream Uint8Array -> Effect (Promise String)

readAll :: ReadableStream Uint8Array -> Aff String
readAll = toAffE <<< readAllImpl

later :: forall a. a -> Aff a
later value = delay (Milliseconds 10.0) $> value

data Status = Online | Offline String

renderStatus :: Status -> String
renderStatus = case _ of
  Online -> "online"
  Offline reason -> "offline: " <> reason

encodeStatus :: Status -> Json
encodeStatus = case _ of
  Online -> fromString "online"
  Offline reason -> fromString ("offline:" <> reason)

decodeStatus :: Json -> Either String Status
decodeStatus json = do
  raw <- note "expected a string" (toString json)
  pure case stripPrefix (Pattern "offline:") raw of
    Just reason -> Offline reason
    Nothing -> Online

spec :: Spec Unit
spec = describe "Solid.Web.SSR" do
  solidIt "renders elements, attributes and escaped text with hydration keys" do
    html <- render $ H.div { id: "root", class: "box" } (H.span {} "<b>&</b>")
    html `shouldSatisfy` has """id="root""""
    html `shouldSatisfy` has """class="box""""
    html `shouldSatisfy` has "&lt;b>&amp;&lt;/b>"
    html `shouldSatisfy` has "_hk="

  solidIt "reactive props and text render their current value; events and refs are omitted" do
    html <- render $ Component.element
      ( Component.component \_ -> do
          label /\ _ <- createSignal "now"
          active /\ _ <- createSignal true
          pure $ H.button
            { title: label, class: { btn: true, active }, onClick: \_ -> pure unit, ref: \_ -> pure unit }
            label
      )
      {}
    html `shouldSatisfy` has """title="now""""
    html `shouldSatisfy` has "active btn"
    html `shouldSatisfy` has ">now<"
    html `shouldSatisfy` (not <<< has "onclick")

  solidIt "renders SVG elements" do
    html <- render $ S.svg { viewBox: "0 0 1 1" } (S.circle { r: "1" } [])
    html `shouldSatisfy` has """viewBox="0 0 1 1""""
    html `shouldSatisfy` has "<circle"

  describe "async values" do
    let
      page ssrOptions = Component.element
        ( Component.component \_ -> do
            greeting /\ _ <- createAsyncWith ssrOptions (pure (later "hello from the server"))
            pure (H.p {} greeting)
        )
        {}
      withLoading view = Control.loading (text "loading…") view

    solidIt "load on the client by default: the server renders the fallback" do
      html <- renderAsync $ withLoading $ Component.element
        ( Component.component \_ -> do
            greeting /\ _ <- createAsync (pure (later "never on the server"))
            pure (text greeting)
        )
        {}
      html `shouldSatisfy` has "loading…"
      html `shouldSatisfy` (not <<< has "never on the server")

    solidIt "serialized values load on the server and are sent with the page" do
      html <- renderAsync $ withLoading $ page { ssr: serialized }
      html `shouldSatisfy` has "<p"
      html `shouldSatisfy` has "hello from the server"

    solidIt "renderToString renders fallbacks without waiting" do
      html <- render $ withLoading $ page { ssr: serialized }
      html `shouldSatisfy` has "loading…"

    solidIt "ADTs load on the server through a codec" do
      html <- renderAsync $ withLoading $ Component.element
        ( Component.component \_ -> do
            status /\ _ <- createAsyncWith { ssr: withCodec encodeStatus decodeStatus }
              (pure (later (Offline "maintenance")))
            pure (text (renderStatus <$> status))
        )
        {}
      html `shouldSatisfy` has "offline: maintenance"

    solidIt "renderToReadableStream streams the settled HTML" do
      stream <- liftEffect (SSR.renderToReadableStream {} (withLoading (page { ssr: serialized }))) >>= orFail
      html <- readAll stream
      html `shouldSatisfy` has "hello from the server"

  solidIt "hydration script honours the nonce, and noScripts omits scripts" do
    script <- liftEffect (SSR.hydrationScriptWith { nonce: "abc123" }) >>= orFail
    script `shouldSatisfy` has "abc123"
    html <- liftEffect (SSR.renderToStringWith { noScripts: true } (H.p {} "static")) >>= orFail
    (has "<script" html) `shouldEqual` false

  solidIt "onError sees errors the render handles" do
    seen <- liftEffect (Ref.new [])
    let broken = Component.component \_ -> unsafeCrashWith "boom"
    expectDiagnostic "SSR_RENDER_ERROR_CONTAINED" do
      html <-
        liftEffect
          ( SSR.renderToStringWith { onError: \e -> Ref.modify_ (_ <> [ message e ]) seen }
              (Control.errored (\_ _ -> pure (text "fallback")) (Component.element broken {}))
          ) >>= orFail
      html `shouldSatisfy` has "fallback"
    liftEffect (Ref.read seen) >>= shouldEqual [ "boom" ]

  solidIt "clientOnly components render only their fallback on the server" do
    let chart = Component.clientOnly @"Test.Server.SSR.chart" :: Component.Component { fallback :: JSX, points :: Int }
    html <- render (H.div {} (Component.element chart { fallback: text "chart soon", points: 3 }))
    html `shouldSatisfy` has "chart soon"

  solidIt "streamed renders can write after the shell and at the end" do
    html <-
      SSR.renderToStringAsyncWith
        { onCompleteShell: \write -> write "<!--shell-->", onCompleteAll: \write -> write "<!--all-->" }
        (H.p {} "body") >>= orFail
    html `shouldSatisfy` has "<!--shell-->"
    html `shouldSatisfy` has "<!--all-->"

  solidIt "the hydration script captures the given events" do
    script <- liftEffect (SSR.hydrationScriptWith { eventNames: [ "pointerdown" ] }) >>= orFail
    script `shouldSatisfy` has "pointerdown"

