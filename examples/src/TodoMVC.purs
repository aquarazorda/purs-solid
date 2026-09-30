module Examples.TodoMVC where

import Prelude

import DOM.HTML.Indexed.InputType (InputType(..))
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (all)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM (classWhen, targetChecked, targetValue)
import Solid.DOM.HTML as H
import Solid.DOM.Props as P
import Solid.JSX (text)
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, get, set)
import Solid.Store (focusKey, value)
import Solid.Store as Store
import Solid.Web (render, requireBody)
import Web.UIEvent.KeyboardEvent as KeyboardEvent

data Visibility
  = ShowAll
  | ShowActive
  | ShowCompleted

derive instance eqVisibility :: Eq Visibility

type Todo =
  { id :: Int
  , title :: String
  , completed :: Boolean
  }

visibleIn :: Visibility -> Todo -> Boolean
visibleIn = case _ of
  ShowAll -> const true
  ShowActive -> not <<< _.completed
  ShowCompleted -> _.completed

todoApp :: Component.Component {}
todoApp = Component.component \_ -> do
  state /\ setState <- Store.createStore { todos: [] :: Array Todo, nextId: 1 }
  draft /\ setDraft <- createSignal ""
  visibility /\ setVisibility <- createSignal ShowAll

  let
    todos = value (focusKey @"todos" state)
    rows = Store.items (focusKey @"todos" state)
    atTodos = Store.atKey @"todos"
    whereId id = atTodos <<< Store.eachWhere (\todo -> todo.id == id)

  activeCount <- createMemo (Array.length <<< Array.filter (not <<< _.completed) <$> todos)
  hasTodos <- createMemo ((not <<< Array.null) <$> todos)
  hasCompleted <- createMemo (Array.any _.completed <$> todos)
  allCompleted <- createMemo $ todos <#> \current ->
    not (Array.null current) && all _.completed current

  let
    addDraftTodo :: Effect Unit
    addDraftTodo = do
      title <- get draft
      nextId <- Store.snapshot (focusKey @"nextId" state)
      when (title /= "") do
        Store.update setState $
          atTodos (Store.push { id: nextId, title, completed: false })
            <> Store.atKey @"nextId" (Store.set (nextId + 1))
        set setDraft ""

    removeTodo id = Store.update setState $ atTodos (Store.filter \todo -> todo.id /= id)

    setCompleted id checked = Store.update setState $
      whereId id (Store.atKey @"completed" (Store.set checked))

    setAllCompleted checked = Store.update setState $
      atTodos (Store.each (Store.atKey @"completed" (Store.set checked)))

    clearCompleted = Store.update setState $ atTodos (Store.filter (not <<< _.completed))

    filterButton label which =
      H.button
        [ P.class_ "filter-btn"
        , classWhen "selected" ((_ == which) <$> visibility)
        , P.onClick \_ -> set setVisibility which
        ]
        [ text label ]

    renderTodo row _ = do
      let
        todo = value row
        completed = value (focusKey @"completed" row)
        visible = visibleIn <$> visibility <*> todo
      pure $ Control.when visible $
        H.li [ P.class_ "todo", classWhen "completed" completed ]
          [ H.input
              [ P.class_ "todo-toggle"
              , P.type_ InputCheckbox
              , P.checked completed
              , P.onChange \event -> do
                  id <- _.id <$> get todo
                  targetChecked event >>= setCompleted id
              ]
          , H.span [ P.class_ "todo-title" ] [ text (value (focusKey @"title" row)) ]
          , H.button
              [ P.class_ "destroy"
              , P.onClick \_ -> get todo >>= removeTodo <<< _.id
              ]
              [ text "Delete" ]
          ]

  pure $ H.div [ P.class_ "todomvc-shell" ]
    [ H.section [ P.class_ "todoapp" ]
        [ H.header [ P.class_ "header" ]
            [ H.h1_ [ text "todos" ]
            , H.input
                [ P.class_ "new-todo"
                , P.placeholder "What needs to be done?"
                , P.value draft
                , P.autofocus true
                , P.onInput \event -> targetValue event >>= set setDraft
                , P.onKeyDown \event -> case KeyboardEvent.key event of
                    "Enter" -> addDraftTodo
                    "Escape" -> set setDraft ""
                    _ -> pure unit
                ]
            ]
        , Control.when hasTodos $
            H.section [ P.class_ "main" ]
              [ H.input
                  [ P.id "toggle-all"
                  , P.class_ "toggle-all"
                  , P.type_ InputCheckbox
                  , P.checked allCompleted
                  , P.onChange \event -> targetChecked event >>= setAllCompleted
                  ]
              , H.label [ P.for "toggle-all", P.class_ "toggle-all-label" ] [ text "Mark all as complete" ]
              , H.ul [ P.class_ "todo-list" ] [ Control.forEach rows renderTodo ]
              ]
        , Control.whenElse hasTodos
            ( H.footer [ P.class_ "footer" ]
                [ H.span [ P.class_ "todo-count" ]
                    [ H.strong_ [ text (show <$> activeCount) ]
                    , text (activeCount <#> \n -> if n == 1 then " item left" else " items left")
                    ]
                , H.div [ P.class_ "filters" ]
                    [ filterButton "All" ShowAll
                    , filterButton "Active" ShowActive
                    , filterButton "Completed" ShowCompleted
                    ]
                , Control.when hasCompleted $
                    H.button [ P.class_ "clear-completed", P.onClick \_ -> clearCompleted ] [ text "Clear completed" ]
                ]
            )
            (H.div [ P.class_ "empty-state" ] [ text "Add your first task to get started." ])
        ]
    , H.footer [ P.class_ "info" ] [ text "PureScript TodoMVC powered by purs-solid" ]
    ]

main :: Effect Unit
main = do
  mountResult <- requireBody
  case mountResult of
    Left webError -> log ("Mount error: " <> show webError)
    Right mountNode -> do
      renderResult <- render (Component.element todoApp {}) mountNode
      case renderResult of
        Left webError -> log ("Render error: " <> show webError)
        Right _dispose -> pure unit
