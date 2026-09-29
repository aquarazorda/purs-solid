module Test.Meta
  ( run
  ) where

import Prelude

import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Solid.Meta as Meta

run :: Effect Unit
run = do
  let _ = Meta.metaProvider_
  let _ = Meta.title
  let _ = Meta.style
  let _ = Meta.meta
  let _ = Meta.link
  let _ = Meta.base
  let _ = Meta.stylesheet
  let _ = Meta.titleFrom
  let _ = useHeadExample
  pure unit

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
