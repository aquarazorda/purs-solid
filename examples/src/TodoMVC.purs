module Examples.TodoMVC where

import Prelude

import DOM.HTML.Indexed.InputType (InputType(..))
import Data.Array as Array
import Data.Foldable (all)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM (targetChecked)
import Solid.DOM.HTML as H
import Solid.JSX (text)
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, get, set)
import Solid.Store (focusKey, value)
import Solid.Store as Store
import Solid.Web (mount)
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
        { class: { "filter-btn": true, selected: (_ == which) <$> visibility }
        , onClick: \_ -> set setVisibility which
        }
        label

    renderTodo row _ = do
      let
        todo = value row
        completed = value (focusKey @"completed" row)
        visible = visibleIn <$> visibility <*> todo
      pure $ Control.when visible $
        H.li { class: { todo: true, completed } }
          [ H.input
              { class: "todo-toggle"
              , type: InputCheckbox
              , checked: completed
              , onChange: \event -> do
                  id <- _.id <$> get todo
                  targetChecked event >>= setCompleted id
              }
          , H.span { class: "todo-title" } (value (focusKey @"title" row))
          , H.button { class: "destroy", onClick: \_ -> get todo >>= removeTodo <<< _.id } "Delete"
          ]

  pure $ H.div { class: "todomvc-shell" }
    [ H.section { class: "todoapp" }
        [ H.header { class: "header" }
            [ H.h1 {} "todos"
            , H.input
                { class: "new-todo"
                , placeholder: "What needs to be done?"
                , bindValue: draft /\ setDraft
                , autofocus: true
                , onKeyDown: \event -> case KeyboardEvent.key event of
                    "Enter" -> addDraftTodo
                    "Escape" -> set setDraft ""
                    _ -> pure unit
                }
            ]
        , Control.when hasTodos $
            H.section { class: "main" }
              [ H.input
                  { id: "toggle-all"
                  , class: "toggle-all"
                  , type: InputCheckbox
                  , checked: allCompleted
                  , onChange: \event -> targetChecked event >>= setAllCompleted
                  }
              , H.label { for: "toggle-all", class: "toggle-all-label" } "Mark all as complete"
              , H.ul { class: "todo-list" } (Control.forEach rows renderTodo)
              ]
        , Control.whenElse hasTodos
            ( H.footer { class: "footer" }
                [ H.span { class: "todo-count" }
                    [ H.strong {} (show <$> activeCount)
                    , text (activeCount <#> \n -> if n == 1 then " item left" else " items left")
                    ]
                , H.div { class: "filters" }
                    [ filterButton "All" ShowAll
                    , filterButton "Active" ShowActive
                    , filterButton "Completed" ShowCompleted
                    ]
                , Control.when hasCompleted $
                    H.button { class: "clear-completed", onClick: \_ -> clearCompleted } "Clear completed"
                ]
            )
            (H.div { class: "empty-state" } "Add your first task to get started.")
        ]
    , H.footer { class: "info" } "PureScript TodoMVC powered by purs-solid"
    ]

main :: Effect Unit
main = mount (Component.element todoApp {})
