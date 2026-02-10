module Solid.DOM.EventAdapters
  ( targetElement
  , currentTargetElement
  , targetTagName
  , currentTargetTagName
  , targetId
  , currentTargetId
  , targetInputElement
  , targetInputValue
  , targetInputChecked
  , targetInputName
  , targetInputFilesCount
  , targetInputFirstFileName
  , asKeyboardEvent
  , keyboardKey
  , keyboardCode
  , keyboardRepeat
  , keyboardCtrlKey
  , keyboardShiftKey
  , keyboardAltKey
  , keyboardMetaKey
  , keyboardIsComposing
  , asMouseEvent
  , mouseClient
  , mouseScreen
  , mouseButton
  , mouseButtons
  , mouseDetail
  , asInputEvent
  , inputEventData
  , inputEventIsComposing
  , asCompositionEvent
  , compositionEventData
  , asDragEvent
  , dragDataTransferTypes
  , dragFilesCount
  , dragFirstFileName
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Web.DOM.Element as Element
import Web.Event.Event (Event)
import Web.Event.Event as Event
import Web.File.File as File
import Web.File.FileList as FileList
import Web.HTML.Event.DataTransfer as DataTransfer
import Web.HTML.Event.DragEvent as DragEvent
import Web.HTML.HTMLInputElement as HTMLInputElement
import Web.UIEvent.CompositionEvent as CompositionEvent
import Web.UIEvent.InputEvent as InputEvent
import Web.UIEvent.KeyboardEvent as KeyboardEvent
import Web.UIEvent.MouseEvent as MouseEvent
import Web.UIEvent.UIEvent as UIEvent

targetElement :: Event -> Maybe Element.Element
targetElement event = Event.target event >>= Element.fromEventTarget

currentTargetElement :: Event -> Maybe Element.Element
currentTargetElement event = Event.currentTarget event >>= Element.fromEventTarget

targetTagName :: Event -> Maybe String
targetTagName event = Element.tagName <$> targetElement event

currentTargetTagName :: Event -> Maybe String
currentTargetTagName event = Element.tagName <$> currentTargetElement event

targetId :: Event -> Effect (Maybe String)
targetId event =
  case targetElement event of
    Nothing -> pure Nothing
    Just element -> Just <$> Element.id element

currentTargetId :: Event -> Effect (Maybe String)
currentTargetId event =
  case currentTargetElement event of
    Nothing -> pure Nothing
    Just element -> Just <$> Element.id element

targetInputElement :: Event -> Maybe HTMLInputElement.HTMLInputElement
targetInputElement event = Event.target event >>= HTMLInputElement.fromEventTarget

targetInputValue :: Event -> Effect (Maybe String)
targetInputValue event =
  case targetInputElement event of
    Nothing -> pure Nothing
    Just input -> Just <$> HTMLInputElement.value input

targetInputChecked :: Event -> Effect (Maybe Boolean)
targetInputChecked event =
  case targetInputElement event of
    Nothing -> pure Nothing
    Just input -> Just <$> HTMLInputElement.checked input

targetInputName :: Event -> Effect (Maybe String)
targetInputName event =
  case targetInputElement event of
    Nothing -> pure Nothing
    Just input -> Just <$> HTMLInputElement.name input

targetInputFilesCount :: Event -> Effect (Maybe Int)
targetInputFilesCount event =
  case targetInputElement event of
    Nothing -> pure Nothing
    Just input -> do
      files <- HTMLInputElement.files input
      pure case files of
        Nothing -> Nothing
        Just fileList -> Just (FileList.length fileList)

targetInputFirstFileName :: Event -> Effect (Maybe String)
targetInputFirstFileName event =
  case targetInputElement event of
    Nothing -> pure Nothing
    Just input -> do
      files <- HTMLInputElement.files input
      pure case files of
        Nothing -> Nothing
        Just fileList -> map File.name (FileList.item 0 fileList)

asKeyboardEvent :: Event -> Maybe KeyboardEvent.KeyboardEvent
asKeyboardEvent = KeyboardEvent.fromEvent

keyboardKey :: Event -> Maybe String
keyboardKey event = KeyboardEvent.key <$> asKeyboardEvent event

keyboardCode :: Event -> Maybe String
keyboardCode event = KeyboardEvent.code <$> asKeyboardEvent event

keyboardRepeat :: Event -> Maybe Boolean
keyboardRepeat event = KeyboardEvent.repeat <$> asKeyboardEvent event

keyboardCtrlKey :: Event -> Maybe Boolean
keyboardCtrlKey event = KeyboardEvent.ctrlKey <$> asKeyboardEvent event

keyboardShiftKey :: Event -> Maybe Boolean
keyboardShiftKey event = KeyboardEvent.shiftKey <$> asKeyboardEvent event

keyboardAltKey :: Event -> Maybe Boolean
keyboardAltKey event = KeyboardEvent.altKey <$> asKeyboardEvent event

keyboardMetaKey :: Event -> Maybe Boolean
keyboardMetaKey event = KeyboardEvent.metaKey <$> asKeyboardEvent event

keyboardIsComposing :: Event -> Maybe Boolean
keyboardIsComposing event = KeyboardEvent.isComposing <$> asKeyboardEvent event

asMouseEvent :: Event -> Maybe MouseEvent.MouseEvent
asMouseEvent = MouseEvent.fromEvent

mouseClient :: Event -> Maybe { x :: Int, y :: Int }
mouseClient event = do
  mouseEvent <- asMouseEvent event
  pure
    { x: MouseEvent.clientX mouseEvent
    , y: MouseEvent.clientY mouseEvent
    }

mouseScreen :: Event -> Maybe { x :: Int, y :: Int }
mouseScreen event = do
  mouseEvent <- asMouseEvent event
  pure
    { x: MouseEvent.screenX mouseEvent
    , y: MouseEvent.screenY mouseEvent
    }

mouseButton :: Event -> Maybe Int
mouseButton event = MouseEvent.button <$> asMouseEvent event

mouseButtons :: Event -> Maybe Int
mouseButtons event = MouseEvent.buttons <$> asMouseEvent event

mouseDetail :: Event -> Maybe Int
mouseDetail event = do
  mouseEvent <- asMouseEvent event
  uiEvent <- UIEvent.fromEvent (MouseEvent.toEvent mouseEvent)
  pure (UIEvent.detail uiEvent)

asInputEvent :: Event -> Maybe InputEvent.InputEvent
asInputEvent = InputEvent.fromEvent

inputEventData :: Event -> Maybe String
inputEventData event = do
  inputEvent <- asInputEvent event
  InputEvent.data_ inputEvent

inputEventIsComposing :: Event -> Maybe Boolean
inputEventIsComposing event = InputEvent.isComposing <$> asInputEvent event

asCompositionEvent :: Event -> Maybe CompositionEvent.CompositionEvent
asCompositionEvent = CompositionEvent.fromEvent

compositionEventData :: Event -> Maybe String
compositionEventData event = CompositionEvent.data_ <$> asCompositionEvent event

asDragEvent :: Event -> Maybe DragEvent.DragEvent
asDragEvent = DragEvent.fromEvent

dragDataTransferTypes :: Event -> Maybe (Array String)
dragDataTransferTypes event = do
  dragEvent <- asDragEvent event
  pure (DataTransfer.types (DragEvent.dataTransfer dragEvent))

dragFilesCount :: Event -> Maybe Int
dragFilesCount event = do
  dragEvent <- asDragEvent event
  fileList <- DataTransfer.files (DragEvent.dataTransfer dragEvent)
  pure (FileList.length fileList)

dragFirstFileName :: Event -> Maybe String
dragFirstFileName event = do
  dragEvent <- asDragEvent event
  fileList <- DataTransfer.files (DragEvent.dataTransfer dragEvent)
  file <- FileList.item 0 fileList
  pure (File.name file)
