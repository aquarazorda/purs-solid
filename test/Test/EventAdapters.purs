module Test.EventAdapters
  ( run
  ) where

import Prelude

import Effect (Effect)
import Solid.DOM.EventAdapters as EventAdapters
import Web.Event.Event (Event)

run :: Effect Unit
run = do
  let _ = _samples
  pure unit

_samples :: Event -> Effect Unit
_samples event = do
  _ <- pure (EventAdapters.targetElement event)
  _ <- pure (EventAdapters.currentTargetElement event)
  _ <- pure (EventAdapters.targetTagName event)
  _ <- pure (EventAdapters.currentTargetTagName event)
  _ <- EventAdapters.targetId event
  _ <- EventAdapters.currentTargetId event
  _ <- pure (EventAdapters.targetInputElement event)
  _ <- EventAdapters.targetInputValue event
  _ <- EventAdapters.targetInputChecked event
  _ <- EventAdapters.targetInputName event
  _ <- EventAdapters.targetInputFilesCount event
  _ <- EventAdapters.targetInputFirstFileName event
  _ <- pure (EventAdapters.asKeyboardEvent event)
  _ <- pure (EventAdapters.keyboardKey event)
  _ <- pure (EventAdapters.keyboardCode event)
  _ <- pure (EventAdapters.keyboardRepeat event)
  _ <- pure (EventAdapters.keyboardCtrlKey event)
  _ <- pure (EventAdapters.keyboardShiftKey event)
  _ <- pure (EventAdapters.keyboardAltKey event)
  _ <- pure (EventAdapters.keyboardMetaKey event)
  _ <- pure (EventAdapters.keyboardIsComposing event)
  _ <- pure (EventAdapters.asMouseEvent event)
  _ <- pure (EventAdapters.mouseClient event)
  _ <- pure (EventAdapters.mouseScreen event)
  _ <- pure (EventAdapters.mouseButton event)
  _ <- pure (EventAdapters.mouseButtons event)
  _ <- pure (EventAdapters.mouseDetail event)
  _ <- pure (EventAdapters.asInputEvent event)
  _ <- pure (EventAdapters.inputEventData event)
  _ <- pure (EventAdapters.inputEventIsComposing event)
  _ <- pure (EventAdapters.asCompositionEvent event)
  _ <- pure (EventAdapters.compositionEventData event)
  _ <- pure (EventAdapters.asDragEvent event)
  _ <- pure (EventAdapters.dragDataTransferTypes event)
  _ <- pure (EventAdapters.dragFilesCount event)
  _ <- pure (EventAdapters.dragFirstFileName event)
  pure unit
