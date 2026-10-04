module Test.Server.Meta
  ( spec
  ) where

import Prelude

import Data.Either (either)
import Data.String (Pattern(..), contains)
import Data.String.Regex (match)
import Data.String.Regex.Flags (global)
import Data.String.Regex.Unsafe (unsafeRegex)
import Data.Array.NonEmpty as NEA
import Data.Maybe (maybe)
import Effect.Aff (Aff, throwError)
import Effect.Class (liftEffect)
import Solid.DOM.HTML as H
import Solid.JSX (JSX, text)
import Solid.Meta as Meta
import Solid.Web.SSR as SSR
import Test.Solid (solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)

renderHead :: JSX -> Aff { html :: String, head :: String }
renderHead view = liftEffect (SSR.renderToStringWithHead {} view) >>= either throwError pure

count :: String -> String -> Int
count pattern = maybe 0 NEA.length <<< match (unsafeRegex pattern global)

spec :: Spec Unit
spec = describe "Solid.Meta (server)" do
  solidIt "head tags are collected into the head markup, not the body" do
    result <- renderHead $ H.div {}
      [ Meta.title "Inbox"
      , Meta.meta { name: "description", content: "mail" }
      , Meta.link { rel: "canonical", href: "https://example.test/inbox" }
      , text "body"
      ]
    -- The host owns the document, so the title arrives as a `document.title` script.
    result.head `shouldSatisfy` contains (Pattern "(\"Inbox\")")
    result.head `shouldSatisfy` contains (Pattern "content=\"mail\"")
    result.head `shouldSatisfy` contains (Pattern "href=\"https://example.test/inbox\"")
    result.html `shouldSatisfy` (not <<< contains (Pattern "Inbox"))

  solidIt "the last tag with the same identity wins; key makes identities distinct" do
    result <- renderHead $ H.div {}
      [ Meta.title "first"
      , Meta.title "second"
      , Meta.meta { key: "img-1", name: "og:image", content: "a.png" }
      , Meta.meta { key: "img-2", name: "og:image", content: "b.png" }
      ]
    result.head `shouldSatisfy` contains (Pattern "(\"second\")")
    result.head `shouldSatisfy` (not <<< contains (Pattern "(\"first\")"))
    count "og:image" result.head `shouldEqual` 2
