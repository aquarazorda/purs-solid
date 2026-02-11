module Solid.Start.Meta
  ( HeadTag(..)
  , MetaDoc
  , empty
  , withTag
  , tags
  ) where

import Prelude

data HeadTag
  = TitleTag String
  | MetaNameTag String String
  | LinkTag String String
  | ScriptSrcTag String

derive instance eqHeadTag :: Eq HeadTag

instance showHeadTag :: Show HeadTag where
  show = case _ of
    TitleTag value -> "TitleTag " <> show value
    MetaNameTag name content -> "MetaNameTag " <> show name <> " " <> show content
    LinkTag rel href -> "LinkTag " <> show rel <> " " <> show href
    ScriptSrcTag src -> "ScriptSrcTag " <> show src

newtype MetaDoc = MetaDoc (Array HeadTag)

derive instance eqMetaDoc :: Eq MetaDoc

instance showMetaDoc :: Show MetaDoc where
  show (MetaDoc values) = "MetaDoc " <> show values

empty :: MetaDoc
empty = MetaDoc []

withTag :: HeadTag -> MetaDoc -> MetaDoc
withTag tag (MetaDoc values) =
  MetaDoc (values <> [ tag ])

tags :: MetaDoc -> Array HeadTag
tags (MetaDoc values) = values
