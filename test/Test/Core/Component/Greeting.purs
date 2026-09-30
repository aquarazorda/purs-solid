module Test.Core.Component.Greeting
  ( greeting
  ) where

import Prelude

import Solid.Component as Component
import Solid.JSX as JSX

greeting :: Component.Component { name :: String }
greeting = Component.component \props -> pure (JSX.text ("hello " <> props.name))
