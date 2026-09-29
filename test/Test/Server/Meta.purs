module Test.Server.Meta
  ( spec
  ) where

import Prelude

import Data.Either (Either(..))
import Data.String (Pattern(..), contains)
import Data.String.Regex (match)
import Data.String.Regex.Flags (global)
import Data.String.Regex.Unsafe (unsafeRegex)
import Data.Array.NonEmpty as NEA
import Data.Maybe (maybe)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (JSX, text)
import Solid.Meta as Meta
import Solid.Web.SSR as SSR
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)

renderHead :: JSX -> Aff { html :: String, head :: String }
renderHead view = liftEffect (SSR.renderToStringWithHead SSR.defaultRenderOptions view) >>= case _ of
  Left error -> liftEffect (throw (show error))
  Right result -> pure result

count :: String -> String -> Int
count pattern = maybe 0 NEA.length <<< match (unsafeRegex pattern global)

spec :: Spec Unit
spec = describe "Solid.Meta (server)" do
  solidIt "head tags are collected into the head markup, not the body" do
    result <- renderHead $ H.div_
      [ Meta.title "Inbox"
      , Meta.meta [ P.name "description", P.content "mail" ]
      , Meta.link [ P.rel "canonical", P.href "https://example.test/inbox" ]
      , text "body"
      ]
    -- When the host owns the document, Solid delivers the title as a script
    -- that sets `document.title`.
    result.head `shouldSatisfy` contains (Pattern "(\"Inbox\")")
    result.head `shouldSatisfy` contains (Pattern "content=\"mail\"")
    result.head `shouldSatisfy` contains (Pattern "href=\"https://example.test/inbox\"")
    result.html `shouldSatisfy` (not <<< contains (Pattern "Inbox"))

  solidIt "the last tag with the same identity wins; key makes identities distinct" do
    result <- renderHead $ H.div_
      [ Meta.title "first"
      , Meta.title "second"
      , Meta.meta [ Meta.key "img-1", P.name "og:image", P.content "a.png" ]
      , Meta.meta [ Meta.key "img-2", P.name "og:image", P.content "b.png" ]
      ]
    result.head `shouldSatisfy` contains (Pattern "(\"second\")")
    result.head `shouldSatisfy` (not <<< contains (Pattern "(\"first\")"))
    count "og:image" result.head `shouldEqual` 2
