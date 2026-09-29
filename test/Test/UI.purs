module Test.UI
  ( run
  ) where

import Prelude

import Effect (Effect)
import Solid.DOM as DOM
import Solid.DOM.HTML as HTML
import Solid.DOM.SVG as SVG
import Solid.JSX as JSX

run :: Effect Unit
run = do
  let _ = JSX.keyed
  let _ = JSX.fragment
  let _ = JSX.empty
  let _ = DOM.div
  let _ = DOM.text
  let _ = HTML.article
  let _ = HTML.h2_
  let _ = HTML.dataTag
  let _ = SVG.svg
  let _ = SVG.circle
  pure unit
