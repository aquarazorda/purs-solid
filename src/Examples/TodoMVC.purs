module Examples.TodoMVC where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (all)
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Solid.Component as Component
import Solid.Control as Control
import Solid.DOM as DOM
import Solid.DOM.EventAdapters as EventAdapters
import Solid.DOM.Events as Events
import Solid.DOM.HTML as HTML
import Solid.JSX (JSX)
import Solid.Reactivity (createMemo)
import Solid.Signal (createSignal, get, modify, set)
import Solid.Web (render, requireBody)

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

countActive :: Array Todo -> Int
countActive todos = Array.length (Array.filter (not <<< _.completed) todos)

countCompleted :: Array Todo -> Int
countCompleted todos = Array.length (Array.filter _.completed todos)

filterTodos :: Visibility -> Array Todo -> Array Todo
filterTodos visibility todos =
  case visibility of
    ShowAll -> todos
    ShowActive -> Array.filter (not <<< _.completed) todos
    ShowCompleted -> Array.filter _.completed todos

todoApp :: Component.Component {}
todoApp = Component.component \_ -> do
  todos /\ setTodos <- createSignal ([] :: Array Todo)
  nextId /\ setNextId <- createSignal 1
  draft /\ setDraft <- createSignal ""
  visibility /\ setVisibility <- createSignal ShowAll

  activeCount <- createMemo do
    current <- get todos
    pure (countActive current)

  completedCount <- createMemo do
    current <- get todos
    pure (countCompleted current)

  allCompleted <- createMemo do
    current <- get todos
    pure (not (Array.null current) && all _.completed current)

  hasTodos <- createMemo do
    current <- get todos
    pure (not (Array.null current))

  hasCompleted <- createMemo do
    completed <- get completedCount
    pure (completed > 0)

  filteredTodos <- createMemo do
    currentVisibility <- get visibility
    currentTodos <- get todos
    pure (filterTodos currentVisibility currentTodos)

  itemsLeftLabel <- createMemo do
    active <- get activeCount
    pure if active == 1 then "item left" else "items left"

  allFilterClass <- createMemo do
    currentVisibility <- get visibility
    pure if currentVisibility == ShowAll then "filter-btn selected" else "filter-btn"

  activeFilterClass <- createMemo do
    currentVisibility <- get visibility
    pure if currentVisibility == ShowActive then "filter-btn selected" else "filter-btn"

  completedFilterClass <- createMemo do
    currentVisibility <- get visibility
    pure if currentVisibility == ShowCompleted then "filter-btn selected" else "filter-btn"

  let
    addDraftTodo :: Effect Unit
    addDraftTodo = do
      title <- get draft
      if title == "" then
        pure unit
      else do
        id <- get nextId
        _ <- modify setTodos (_ <> [ { id, title, completed: false } ])
        _ <- set setNextId (id + 1)
        _ <- set setDraft ""
        pure unit

    removeTodoById :: Int -> Effect Unit
    removeTodoById id = do
      _ <- modify setTodos (Array.filter (\todo -> todo.id /= id))
      pure unit

    setTodoCompletion :: Int -> Boolean -> Effect Unit
    setTodoCompletion id checked = do
      _ <- modify setTodos (map \todo -> if todo.id == id then todo { completed = checked } else todo)
      pure unit

    onDraftInput = Events.handler \event -> do
      value <- EventAdapters.targetInputValue event
      case value of
        Just nextValue -> do
          _ <- set setDraft nextValue
          pure unit
        Nothing ->
          pure unit

    onDraftKeyDown = Events.handler \event ->
      case EventAdapters.keyboardKey event of
        Just "Enter" -> addDraftTodo
        Just "Escape" -> do
          _ <- set setDraft ""
          pure unit
        _ ->
          pure unit

    onToggleAll = Events.handler \event -> do
      maybeChecked <- EventAdapters.targetInputChecked event
      case maybeChecked of
        Just checked -> do
          _ <- modify setTodos (map (_ { completed = checked }))
          pure unit
        Nothing ->
          pure unit

    clearCompletedTodos :: Effect Unit
    clearCompletedTodos = do
      _ <- modify setTodos (Array.filter (not <<< _.completed))
      pure unit

    renderTodo :: Todo -> Effect JSX
    renderTodo todo =
      pure $ HTML.li
        { className: if todo.completed then "todo completed" else "todo" }
        [ HTML.input
            { className: "todo-toggle"
            , type: "checkbox"
            , checked: todo.completed
            , onChange: Events.handler \event -> do
                maybeChecked <- EventAdapters.targetInputChecked event
                case maybeChecked of
                  Just checked -> setTodoCompletion todo.id checked
                  Nothing -> pure unit
            }
            []
        , HTML.span { className: "todo-title" } [ DOM.text todo.title ]
        , HTML.button
            { className: "destroy"
            , onClick: Events.handler_ (removeTodoById todo.id)
            }
            [ DOM.text "Delete" ]
        ]

  pure $ HTML.div { className: "todomvc-shell" }
    [ HTML.section { className: "todoapp" }
        [ HTML.header { className: "header" }
            [ HTML.h1_ [ DOM.text "todos" ]
            , HTML.input
                { className: "new-todo"
                , placeholder: "What needs to be done?"
                , value: draft
                , onInput: onDraftInput
                , onKeyDown: onDraftKeyDown
                , autofocus: true
                }
                []
            ]
        , Control.when hasTodos
            (HTML.section { className: "main" }
              [ HTML.input
                  { id: "toggle-all"
                  , className: "toggle-all"
                  , type: "checkbox"
                  , checked: allCompleted
                  , onChange: onToggleAll
                  }
                  []
              , HTML.label { className: "toggle-all-label" } [ DOM.text "Mark all as complete" ]
              , HTML.ul { className: "todo-list" }
                  [ Control.forEach filteredTodos renderTodo
                  ]
              ])
        , Control.whenElse hasTodos
            (HTML.div { className: "empty-state" } [ DOM.text "Add your first task to get started." ])
            (HTML.footer { className: "footer" }
              [ HTML.span { className: "todo-count" }
                  [ Control.dynamicTag "strong" { children: activeCount }
                  , DOM.text " "
                  , Control.dynamicTag "span" { children: itemsLeftLabel }
                  ]
              , HTML.div { className: "filters" }
                  [ HTML.button
                      { className: allFilterClass
                      , onClick: Events.handler_ do
                          _ <- set setVisibility ShowAll
                          pure unit
                      }
                      [ DOM.text "All" ]
                  , HTML.button
                      { className: activeFilterClass
                      , onClick: Events.handler_ do
                          _ <- set setVisibility ShowActive
                          pure unit
                      }
                      [ DOM.text "Active" ]
                  , HTML.button
                      { className: completedFilterClass
                      , onClick: Events.handler_ do
                          _ <- set setVisibility ShowCompleted
                          pure unit
                      }
                      [ DOM.text "Completed" ]
                  ]
              , Control.when hasCompleted
                  (HTML.button
                    { className: "clear-completed"
                    , onClick: Events.handler_ clearCompletedTodos
                    }
                    [ DOM.text "Clear completed" ])
              ])
        ]
    , HTML.footer { className: "info" }
        [ DOM.text "PureScript TodoMVC powered by purs-solid" ]
    ]

main :: Effect Unit
main = do
  mountResult <- requireBody
  case mountResult of
    Left webError ->
      log ("Mount error: " <> show webError)

    Right mountNode -> do
      renderResult <- render (pure (Component.element todoApp {})) mountNode
      case renderResult of
        Left webError ->
          log ("Render error: " <> show webError)
        Right _dispose ->
          pure unit
