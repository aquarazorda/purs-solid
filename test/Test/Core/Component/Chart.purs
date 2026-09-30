module Test.Core.Component.Chart
  ( chart
  ) where

import Prelude

import Solid.Component as Component
import Solid.JSX as JSX

chart :: Component.Component { name :: String }
chart = Component.component \props -> pure (JSX.text ("hello " <> props.name))
