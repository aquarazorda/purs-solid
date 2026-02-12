module Test.Meta
  ( run
  ) where

import Prelude

import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.JSX as JSX
import Solid.Meta as Meta

run :: Effect Unit
run = do
  let _ = examples
  let _ = Meta.titleFrom
  let _ = useHeadExample
  pure unit

examples :: Array JSX.JSX
examples =
  [ Meta.metaProvider_
      [ Meta.title "purs-solid"
      , Meta.style "body { color: red; }"
      , Meta.meta { name: "description", content: "PureScript wrappers for Solid APIs" }
      , Meta.link { rel: "icon", href: "/favicon.ico" }
      , Meta.base { href: "https://docs.solidjs.com/" }
      , Meta.stylesheet { href: "/app.css" }
      ]
  ]

useHeadExample :: Effect (Either Meta.MetaError Unit)
useHeadExample =
  Meta.useHead
    { tag: "meta"
    , props:
        { name: "robots"
        , content: "index,follow"
        }
    , setting: Nothing
    , id: "robots-default"
    , name: Just "robots"
    }
