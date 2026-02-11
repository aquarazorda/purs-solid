module Solid.Start.StaticAssets
  ( resolveAssetUrl
  , resolvePublicUrl
  ) where

import Data.String.CodeUnits as String
import Prelude

import Solid.Start.App (StartConfig)

resolveAssetUrl :: StartConfig -> String -> String
resolveAssetUrl config assetPath =
  joinPath config.assetPrefix assetPath

resolvePublicUrl :: StartConfig -> String -> String
resolvePublicUrl config publicPath =
  joinPath config.basePath publicPath

joinPath :: String -> String -> String
joinPath prefix rawPath =
  normalizePrefix prefix <> normalizePath rawPath

normalizePrefix :: String -> String
normalizePrefix value
  | value == "" = "/"
  | String.take 1 value /= "/" = "/" <> trimTrailingSlash value <> "/"
  | otherwise = trimTrailingSlash value <> "/"

normalizePath :: String -> String
normalizePath value
  | value == "" = ""
  | String.take 1 value == "/" = String.drop 1 value
  | otherwise = value

trimTrailingSlash :: String -> String
trimTrailingSlash value
  | value == "/" = ""
  | hasTrailingSlash value = trimTrailingSlash (String.take (String.length value - 1) value)
  | otherwise = value

hasTrailingSlash :: String -> Boolean
hasTrailingSlash value =
  String.length value > 0
    && String.drop (String.length value - 1) value == "/"
