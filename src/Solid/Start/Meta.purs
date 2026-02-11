module Solid.Start.Meta
  ( HeadTag(..)
  , MetaDoc
  , empty
  , fromTitle
  , merge
  , withTag
  , tags
  , renderTag
  , renderHeadHtml
  ) where

import Prelude

import Data.String as String

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

fromTitle :: String -> MetaDoc
fromTitle title =
  withTag (TitleTag title) empty

merge :: MetaDoc -> MetaDoc -> MetaDoc
merge (MetaDoc left) (MetaDoc right) =
  MetaDoc (left <> right)

withTag :: HeadTag -> MetaDoc -> MetaDoc
withTag tag (MetaDoc values) =
  MetaDoc (values <> [ tag ])

tags :: MetaDoc -> Array HeadTag
tags (MetaDoc values) = values

renderTag :: HeadTag -> String
renderTag = case _ of
  TitleTag value -> "<title>" <> escapeHtml value <> "</title>"
  MetaNameTag name content ->
    "<meta name=\"" <> escapeHtmlAttribute name <> "\" content=\"" <> escapeHtmlAttribute content <> "\" />"
  LinkTag rel href ->
    "<link rel=\"" <> escapeHtmlAttribute rel <> "\" href=\"" <> escapeHtmlAttribute href <> "\" />"
  ScriptSrcTag src ->
    "<script src=\"" <> escapeHtmlAttribute src <> "\"></script>"

renderHeadHtml :: MetaDoc -> String
renderHeadHtml (MetaDoc values) =
  String.joinWith "" (map renderTag values)

escapeHtml :: String -> String
escapeHtml value =
  value
    # replaceAll "&" "&amp;"
    # replaceAll "<" "&lt;"
    # replaceAll ">" "&gt;"

escapeHtmlAttribute :: String -> String
escapeHtmlAttribute value =
  escapeHtml value
    # replaceAll "\"" "&quot;"
    # replaceAll "'" "&#39;"

replaceAll :: String -> String -> String -> String
replaceAll needle replacement value =
  String.joinWith replacement (String.split (String.Pattern needle) value)
