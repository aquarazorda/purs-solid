module Test.Core.Store
  ( spec
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Traversable (sequence, traverse)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (Milliseconds(..), delay)
import Effect.Class (liftEffect)
import Solid.Async (refreshAff, resolve)
import Effect.Ref as Ref
import Solid.Reactivity (createEffect_, flush, withFlush)
import Solid.Root (createRoot)
import Solid.Setup (liftSetup)
import Solid.Signal (createSignal, get, sample)
import Solid.Signal as Signal
import Solid.Store (createStore, focus, key, value)
import Solid.Store as Store
import Solid.Utility (mapArray)
import Test.Solid (settle, solidIt)
import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

data Status = Active | Archived { reason :: String }

derive instance Eq Status

instance Show Status where
  show = case _ of
    Active -> "Active"
    Archived r -> "(Archived " <> show r <> ")"

type Todo = { id :: Int, title :: String, done :: Boolean }

todo :: Int -> String -> Todo
todo id title = { id, title, done: false }

logTo :: Ref.Ref (Array String) -> String -> Effect Unit
logTo ref entry = Ref.modify_ (_ <> [ entry ]) ref

spec :: Spec Unit
spec = describe "Solid.Store" do
  solidIt "reads and writes through typed paths" do
    result <- liftEffect do
      state /\ setState <- createStore { user: { name: "ada", age: 36 } }
      let name = value (focus (key @"user" >>> key @"name") state)
      before <- get name
      withFlush $ Store.update setState $ Store.at (key @"user" >>> key @"name") (Store.set "grace")
      after <- get name
      pure { before, after }
    result `shouldEqual` { before: "ada", after: "grace" }

  solidIt "only readers of the changed part are notified" do
    log <- liftEffect (Ref.new [])
    setState <- liftEffect $ createRoot \_ -> do
      state /\ setState <- createStore { a: 1, b: 1 }
      createEffect_ (value (focus (key @"a") state)) \a -> logTo log ("a=" <> show a)
      pure setState
    settle
    liftEffect $ Store.update setState $ Store.at (key @"b") (Store.modify (_ + 1))
    settle
    liftEffect $ Store.update setState $ Store.at (key @"a") (Store.modify (_ + 1))
    settle
    liftEffect (Ref.read log) >>= shouldEqual [ "a=1", "a=2" ]

  solidIt "array updates: push, eachWhere, atIndex, filter" do
    result <- liftEffect do
      state /\ setState <- createStore { todos: [ todo 1 "a", todo 2 "b" ] }
      let
        todos = Store.at (key @"todos")
        toggle id = todos $ Store.eachWhere (\t -> t.id == id) $ Store.at (key @"done") (Store.modify not)
      withFlush $ Store.update setState $
        todos (Store.push (todo 3 "c"))
          <> toggle 2
          <> todos (Store.atIndex 0 (Store.at (key @"title") (Store.set "A")))
          <> todos (Store.atIndex 99 (Store.at (key @"title") (Store.set "ignored")))
      afterEdits <- get (value (focus (key @"todos") state))
      withFlush $ Store.update setState $ todos (Store.filter (not <<< _.done))
      afterFilter <- get (value (focus (key @"todos") state))
      pure { afterEdits, afterFilter }
    result.afterEdits `shouldEqual` [ { id: 1, title: "A", done: false }, { id: 2, title: "b", done: true }, todo 3 "c" ]
    result.afterFilter `shouldEqual` [ { id: 1, title: "A", done: false }, todo 3 "c" ]

  solidIt "ADTs stay atomic: pattern matching works after a round trip" do
    result <- liftEffect do
      state /\ setState <- createStore
        { selected: Nothing :: Maybe Todo
        , statuses: [ Active ]
        }
      withFlush $ Store.update setState $
        Store.at (key @"selected") (Store.set (Just (todo 1 "a")))
          <> Store.at (key @"statuses") (Store.push (Archived { reason: "old" }))
      selected <- get (value (focus (key @"selected") state))
      statuses <- get (value (focus (key @"statuses") state))
      let
        selectedTitle = case selected of
          Just t -> t.title
          Nothing -> "none"
        archivedReasons = statuses # Array.mapMaybe case _ of
          Archived r -> Just r.reason
          Active -> Nothing
      pure { selectedTitle, archivedReasons, firstIsActive: Array.head statuses == Just Active }
    result `shouldEqual` { selectedTitle: "a", archivedReasons: [ "old" ], firstIsActive: true }

  solidIt "item cursors keep identity, so keyed mapping reuses rows" do
    calls <- liftEffect (Ref.new 0)
    result <- liftEffect do
      parts <- createRoot \_ -> do
        state /\ setState <- createStore { todos: [ todo 1 "a", todo 2 "b" ] }
        rows <- mapArray (Store.items (focus (key @"todos") state)) \row _ -> do
          liftSetup (Ref.modify_ (_ + 1) calls)
          pure (value (focus (key @"title") row))
        pure { rows, setState }
      _ <- get parts.rows
      withFlush $ Store.update parts.setState $ Store.at (key @"todos") (Store.push (todo 3 "c"))
      rows <- get parts.rows
      traverseGet rows
    result `shouldEqual` [ "a", "b", "c" ]
    liftEffect (Ref.read calls) >>= shouldEqual 3

  solidIt "a row's readers ignore changes to other rows" do
    log <- liftEffect (Ref.new [])
    setState <- liftEffect $ createRoot \_ -> do
      state /\ setState <- createStore { todos: [ todo 1 "a", todo 2 "b" ] }
      rows <- sample (Store.items (focus (key @"todos") state))
      case Array.head rows of
        Just first -> createEffect_ (value (focus (key @"title") first)) (logTo log)
        Nothing -> pure unit
      pure setState
    settle
    liftEffect $ Store.update setState $ Store.at (key @"todos") $ Store.atIndex 1 $ Store.at (key @"title") (Store.set "B")
    settle
    liftEffect $ Store.update setState $ Store.at (key @"todos") $ Store.atIndex 0 $ Store.at (key @"title") (Store.set "A")
    settle
    liftEffect (Ref.read log) >>= shouldEqual [ "a", "A" ]

  solidIt "reconcileBy keeps observed rows when elements move or change" do
    calls <- liftEffect (Ref.new 0)
    result <- liftEffect do
      parts <- createRoot \_ -> do
        state /\ setState <- createStore { todos: [ todo 1 "a", todo 2 "b", todo 3 "c" ] }
        rows <- mapArray (Store.items (focus (key @"todos") state)) \row _ -> do
          liftSetup (Ref.modify_ (_ + 1) calls)
          pure (value (focus (key @"title") row))
        -- Solid only keeps element identity across a reconcile while the element is observed.
        createEffect_ (rows >>= sequence) (\_ -> pure unit)
        pure { rows, setState }
      flush
      withFlush $ Store.update parts.setState $ Store.at (key @"todos") $
        Store.reconcileBy _.id [ todo 3 "c", { id: 1, title: "a2", done: true } ]
      traverseGet =<< get parts.rows
    result `shouldEqual` [ "c", "a2" ]
    liftEffect (Ref.read calls) >>= shouldEqual 3

  solidIt "snapshots are immutable and the initial value is never mutated" do
    result <- liftEffect do
      let initial = { count: 1, tags: [ "x" ] }
      state /\ setState <- createStore initial
      before <- Store.snapshot state
      withFlush $ Store.update setState $
        Store.at (key @"count") (Store.set 2) <> Store.at (key @"tags") (Store.push "y")
      after <- Store.snapshot state
      pure { initial, before, after }
    result `shouldEqual`
      { initial: { count: 1, tags: [ "x" ] }
      , before: { count: 1, tags: [ "x" ] }
      , after: { count: 2, tags: [ "x", "y" ] }
      }

  solidIt "set at the root replaces the whole value" do
    result <- liftEffect do
      state /\ setState <- createStore { a: 1, b: "b" }
      withFlush $ Store.update setState (Store.set { a: 2, b: "c" })
      Store.snapshot state
    result `shouldEqual` { a: 2, b: "c" }

  solidIt "createProjection derives a store from signals" do
    result <- liftEffect do
      parts <- createRoot \_ -> do
        prefix /\ setPrefix <- createSignal "x"
        projected <- Store.createProjection
          (prefix <#> \p -> Store.at (key @"label") (Store.set (p <> "!")))
          { label: "" }
        pure { projected, setPrefix }
      flush
      before <- get (value (focus (key @"label") parts.projected))
      withFlush (Signal.set parts.setPrefix "y")
      after <- get (value (focus (key @"label") parts.projected))
      pure { before, after }
    result `shouldEqual` { before: "x!", after: "y!" }

  solidIt "createSelector notifies only the rows whose selection changed" do
    log <- liftEffect (Ref.new [])
    setSelected <- liftEffect $ createRoot \_ -> do
      selected /\ setSelected <- createSignal 1
      isSelected <- Store.createSelector show selected
      for_' [ 1, 2, 3 ] \id ->
        createEffect_ (isSelected id) \on -> logTo log (show id <> "=" <> show on)
      pure setSelected
    settle
    liftEffect (Ref.write [] log)
    liftEffect (Signal.set setSelected 2)
    settle
    entries <- liftEffect (Ref.read log)
    Array.sort entries `shouldEqual` [ "1=false", "2=true" ]

  solidIt "reconcileByPosition keeps each position's element" do
    result <- liftEffect do
      state /\ setState <- createStore { rows: [ { label: "a" }, { label: "b" } ] }
      let rows = focus (key @"rows") state
      before <- get (Store.items rows)
      withFlush (Store.update setState (Store.at (key @"rows") (Store.reconcileByPosition [ { label: "x" }, { label: "b" } ])))
      after <- get (Store.items rows)
      labels <- get (value rows)
      pure { same: map (const true) before == map (const true) after, labels: _.label <$> labels }
    result `shouldEqual` { same: true, labels: [ "x", "b" ] }

  solidIt "createDerivedStore can be updated locally until its source changes" do
    result <- liftEffect do
      parts <- createRoot \_ -> do
        source /\ setSource <- createSignal "a"
        store /\ setStore <- Store.createDerivedStore (source <#> \s -> Store.at (key @"label") (Store.set s)) { label: "" }
        pure { store, setStore, setSource }
      flush
      let label = get (value (focus (key @"label") parts.store))
      derived <- label
      withFlush (Store.update parts.setStore (Store.at (key @"label") (Store.set "local")))
      local <- label
      withFlush (Signal.set parts.setSource "b")
      rederived <- label
      pure { derived, local, rederived }
    result `shouldEqual` { derived: "a", local: "local", rederived: "b" }

  solidIt "createProjectionAsync applies the update when the Aff finishes" do
    loads <- liftEffect (Ref.new 0)
    parts <- liftEffect $ createRoot \_ -> do
      id /\ _ <- createSignal 1
      store /\ refreshStore <- Store.createProjectionAsync
        ( id <#> \n -> do
            liftEffect (Ref.modify_ (_ + 1) loads)
            delay (Milliseconds 5.0)
            pure (Store.at (key @"label") (Store.set ("item " <> show n)))
        )
        { label: "" }
      pure { label: value (focus (key @"label") store), refreshStore }
    resolve parts.label >>= shouldEqual "item 1"
    _ <- refreshAff parts.refreshStore
    liftEffect (Ref.read loads) >>= shouldEqual 2

  where
  traverseGet = traverse get
  for_' xs f = void (traverse f xs)
