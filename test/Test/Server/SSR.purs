module Test.Server.SSR
  ( spec
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Argonaut.Core (Json, fromString, toString)
import Data.Either (Either(..), note)
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), contains, stripPrefix)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.Async (createAsync, createAsyncWith, defaultAsyncOptions, serialized, withCodec)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM (classWhen, ref)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.DOM.SVG as S
import Solid.DOM.SVG.Props as SP
import Solid.JSX (JSX, text)
import Solid.Signal (createSignal)
import Solid.Web.SSR as SSR
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)
import Web.Streams.ReadableStream (ReadableStream)
import Data.ArrayBuffer.Types (Uint8Array)

render :: JSX -> Aff String
render view = liftEffect (SSR.renderToString view) >>= orFail

renderAsync :: JSX -> Aff String
renderAsync view = SSR.renderToStringAsync view >>= orFail

orFail :: forall a. Either SSR.SsrError a -> Aff a
orFail = case _ of
  Left error -> liftEffect (throw (show error))
  Right value -> pure value

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
    html <- render $ H.div [ P.id "root", P.class_ "box" ] [ H.span_ [ text "<b>&</b>" ] ]
    html `shouldSatisfy` has """id="root""""
    html `shouldSatisfy` has """class="box""""
    html `shouldSatisfy` has "&lt;b>&amp;&lt;/b>"
    html `shouldSatisfy` has "_hk="

  solidIt "reactive props and text render their current value; events and refs are omitted" do
    html <- render $ Component.element (Component.component \_ -> do
      label /\ _ <- createSignal "now"
      active /\ _ <- createSignal true
      pure $ H.button
        [ P.title label, P.class_ "btn", classWhen "active" active, P.onClick \_ -> pure unit, ref \_ -> pure unit ]
        [ text label ]) {}
    html `shouldSatisfy` has """title="now""""
    html `shouldSatisfy` has "btn active"
    html `shouldSatisfy` has ">now<"
    html `shouldSatisfy` (not <<< has "onclick")

  solidIt "renders SVG elements" do
    html <- render $ S.svg [ SP.viewBox "0 0 1 1" ] [ S.circle [ SP.r "1" ] [] ]
    html `shouldSatisfy` has """viewBox="0 0 1 1""""
    html `shouldSatisfy` has "<circle"

  describe "async values" do
    let
      page ssrOptions = Component.element (Component.component \_ -> do
        greeting /\ _ <- createAsyncWith ssrOptions (pure (later "hello from the server"))
        pure (H.p_ [ text greeting ])) {}
      withLoading view = Control.loading (text "loading…") view

    solidIt "load on the client by default: the server renders the fallback" do
      html <- renderAsync $ withLoading $ Component.element (Component.component \_ -> do
        greeting /\ _ <- createAsync (pure (later "never on the server"))
        pure (text greeting)) {}
      html `shouldSatisfy` has "loading…"
      html `shouldSatisfy` (not <<< has "never on the server")

    solidIt "serialized values load on the server and are sent with the page" do
      html <- renderAsync $ withLoading $ page (defaultAsyncOptions { ssr = serialized })
      html `shouldSatisfy` has "<p"
      html `shouldSatisfy` has "hello from the server"

    solidIt "renderToString renders fallbacks without waiting" do
      html <- render $ withLoading $ page (defaultAsyncOptions { ssr = serialized })
      html `shouldSatisfy` has "loading…"

    solidIt "ADTs load on the server through a codec" do
      html <- renderAsync $ withLoading $ Component.element (Component.component \_ -> do
        status /\ _ <- createAsyncWith (defaultAsyncOptions { ssr = withCodec encodeStatus decodeStatus })
          (pure (later (Offline "maintenance")))
        pure (text (renderStatus <$> status))) {}
      html `shouldSatisfy` has "offline: maintenance"

    solidIt "renderToReadableStream streams the settled HTML" do
      stream <- liftEffect (SSR.renderToReadableStream SSR.defaultRenderOptions (withLoading (page (defaultAsyncOptions { ssr = serialized })))) >>= orFail
      html <- readAll stream
      html `shouldSatisfy` has "hello from the server"

  solidIt "hydration script honours the nonce, and noScripts omits scripts" do
    script <- liftEffect (SSR.hydrationScriptWith (Just "abc123")) >>= orFail
    script `shouldSatisfy` has "abc123"
    html <- liftEffect (SSR.renderToStringWith (SSR.defaultRenderOptions { noScripts = true }) (H.p_ [ text "static" ])) >>= orFail
    (has "<script" html) `shouldEqual` false
