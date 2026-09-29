module Examples.TodoMVC where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (all, for_)
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
import Solid.Setup (Setup)
import Solid.Signal (createSignal, get, modify_, set)
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

  activeCount <- createMemo (countActive <$> todos)
  completedCount <- createMemo (countCompleted <$> todos)
  hasTodos <- createMemo (not <<< Array.null <$> todos)
  allCompleted <- createMemo $ todos <#> \current ->
    not (Array.null current) && all _.completed current

  let
    hasCompleted = (_ > 0) <$> completedCount
    itemsLeftLabel = activeCount <#> \active -> if active == 1 then "item left" else "items left"
    filterClass which = visibility <#> \current ->
      if current == which then "filter-btn selected" else "filter-btn"

  filteredTodos <- createMemo (filterTodos <$> visibility <*> todos)

  let
    addDraftTodo :: Effect Unit
    addDraftTodo = do
      title <- get draft
      when (title /= "") do
        id <- get nextId
        modify_ setTodos (_ <> [ { id, title, completed: false } ])
        set setNextId (id + 1)
        set setDraft ""

    removeTodoById :: Int -> Effect Unit
    removeTodoById id =
      modify_ setTodos (Array.filter (\todo -> todo.id /= id))

    setTodoCompletion :: Int -> Boolean -> Effect Unit
    setTodoCompletion id checked =
      modify_ setTodos (map \todo -> if todo.id == id then todo { completed = checked } else todo)

    onDraftInput = Events.handler \event -> do
      value <- EventAdapters.targetInputValue event
      for_ value (set setDraft)

    onDraftKeyDown = Events.handler \event ->
      case EventAdapters.keyboardKey event of
        Just "Enter" -> addDraftTodo
        Just "Escape" -> set setDraft ""
        _ -> pure unit

    onToggleAll = Events.handler \event -> do
      maybeChecked <- EventAdapters.targetInputChecked event
      for_ maybeChecked \checked ->
        modify_ setTodos (map (_ { completed = checked }))

    clearCompletedTodos :: Effect Unit
    clearCompletedTodos =
      modify_ setTodos (Array.filter (not <<< _.completed))

    renderTodo :: Todo -> Setup JSX
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
                      { className: filterClass ShowAll
                      , onClick: Events.handler_ (set setVisibility ShowAll)
                      }
                      [ DOM.text "All" ]
                  , HTML.button
                      { className: filterClass ShowActive
                      , onClick: Events.handler_ (set setVisibility ShowActive)
                      }
                      [ DOM.text "Active" ]
                  , HTML.button
                      { className: filterClass ShowCompleted
                      , onClick: Events.handler_ (set setVisibility ShowCompleted)
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
