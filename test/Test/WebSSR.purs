module Test.WebSSR
  ( run
  ) where

import Prelude

import Data.Either (Either(..))
import Data.String.CodeUnits as StringCodeUnits
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Solid.JSX as JSX
import Solid.Web.SSR as SSR
import Test.Assert (assertEqual, expectRight)

run :: Effect Unit
run = do
  rendered <- expectRight
    "renderToString returns HTML"
    =<< SSR.renderToString (pure (JSX.text "hello-ssr"))
  assertEqual "renderToString output is non-empty" true (StringCodeUnits.length rendered > 0)

  script <- expectRight
    "hydrationScript returns script content"
    =<< SSR.hydrationScript
  assertEqual "hydrationScript output is non-empty" true (StringCodeUnits.length script > 0)

  streamResult <- SSR.renderToStream (pure (JSX.text "stream-ssr"))
  case streamResult of
    Left errorValue ->
      throw ("renderToStream should return Right, got " <> show errorValue)
    Right _stream ->
      pure unit

  launchAff_ do
    asyncResult <- SSR.renderToStringAsync (pure (JSX.text "async-ssr"))
    liftEffect do
      asyncHtml <- expectRight "renderToStringAsync returns HTML" asyncResult
      assertEqual
        "renderToStringAsync output is non-empty"
        true
        (StringCodeUnits.length asyncHtml > 0)
