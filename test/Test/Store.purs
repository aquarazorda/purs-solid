module Test.Store
  ( run
  ) where

import Prelude

import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Solid.Root (createRoot)
import Solid.Store as Store
import Test.Assert (assertEqual)
import Type.Proxy (Proxy(..))

foreign import sameRef :: forall a. a -> a -> Boolean

foreign import produceIncrementCount :: forall r. { count :: Int | r } -> Effect Unit

foreign import mutateMutableCount :: forall r. { count :: Int | r } -> Effect Unit

run :: Effect Unit
run = do
  storeFixture <- createRoot \dispose -> do
    store /\ setStore <- Store.createStore
      { count: 0
      , user:
          { age: 20
          , name: "Ada"
          }
      , settings:
          { theme: "light"
          }
      }

    pure
      { store
      , setStore
      , dispose
      }

  storeInitialCount <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store initial top-level field" 0 storeInitialCount

  _ <- Store.setField (Proxy :: Proxy "count") storeFixture.setStore 1
  storeCountAfterSet <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store setField updates top-level field" 1 storeCountAfterSet

  _ <- Store.modifyField (Proxy :: Proxy "count") storeFixture.setStore (_ + 2)
  storeCountAfterModify <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store modifyField updates top-level field" 3 storeCountAfterModify

  _ <- Store.produce storeFixture.setStore produceIncrementCount
  storeCountAfterProduce <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store produce applies mutable draft recipe" 13 storeCountAfterProduce

  _ <- Store.modifyField (Proxy :: Proxy "user") storeFixture.setStore \user ->
    user { age = user.age + 1 }

  storeUserAfterModify <- Store.getField (Proxy :: Proxy "user") storeFixture.store
  assertEqual "store nested update via modifyField" 21 storeUserAfterModify.age

  _ <- Store.setPath storeFixture.setStore [ "user", "name" ] "Grace"

  storeUserAfterPathSet <- Store.getField (Proxy :: Proxy "user") storeFixture.store
  assertEqual "store setPath updates nested key" "Grace" storeUserAfterPathSet.name

  settingsBefore <- Store.getField (Proxy :: Proxy "settings") storeFixture.store
  userBefore <- Store.getField (Proxy :: Proxy "user") storeFixture.store

  _ <- Store.modifyPath storeFixture.setStore [ "user", "age" ] (_ + 9)

  settingsAfter <- Store.getField (Proxy :: Proxy "settings") storeFixture.store
  userAfter <- Store.getField (Proxy :: Proxy "user") storeFixture.store

  assertEqual "store modifyPath updates nested value" 30 userAfter.age
  assertEqual "store preserves untouched branch reference" true (sameRef settingsBefore settingsAfter)
  assertEqual "store preserves parent branch reference for leaf path updates" true (sameRef userBefore userAfter)

  _ <- Store.setField (Proxy :: Proxy "user") storeFixture.setStore
    { age: 31
    , name: "Grace"
    }

  userAfterSetFieldObject <- Store.getField (Proxy :: Proxy "user") storeFixture.store
  assertEqual "store setField with object keeps branch reference and merges fields" true (sameRef userAfter userAfterSetFieldObject)
  assertEqual "store setField with object updates merged age" 31 userAfterSetFieldObject.age

  _ <- Store.reconcile storeFixture.setStore
    { count: 99
    , user:
        { age: 31
        , name: "Grace"
        }
    , settings:
        { theme: "light"
        }
    }
  countAfterReconcile <- Store.getField (Proxy :: Proxy "count") storeFixture.store
  assertEqual "store reconcile updates root tree with structural diff" 99 countAfterReconcile

  unwrappedStore <- Store.unwrapStore storeFixture.store
  assertEqual "unwrapStore exposes latest nested state" 31 unwrappedStore.user.age

  storeFixture.dispose

  mutableFixture <- createRoot \dispose -> do
    mutable <- Store.createMutable
      { count: 1
      , nested:
          { value: 2
          }
      }

    pure
      { mutable
      , dispose
      }

  mutableInitialCount <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "mutable initial top-level field" 1 mutableInitialCount

  _ <- Store.setMutableField (Proxy :: Proxy "count") mutableFixture.mutable 5
  mutableCountAfterSet <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "mutable setMutableField updates top-level field" 5 mutableCountAfterSet

  _ <- Store.modifyMutableField (Proxy :: Proxy "count") mutableFixture.mutable (_ + 3)
  mutableCountAfterModify <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "mutable modifyMutableField updates top-level field" 8 mutableCountAfterModify

  _ <- Store.modifyMutable mutableFixture.mutable mutateMutableCount
  mutableCountAfterModifyMutable <- Store.getMutableField (Proxy :: Proxy "count") mutableFixture.mutable
  assertEqual "modifyMutable convenience applies mutable draft recipe" 10 mutableCountAfterModifyMutable

  nestedBefore <- Store.getMutableField (Proxy :: Proxy "nested") mutableFixture.mutable

  _ <- Store.setMutablePath mutableFixture.mutable [ "nested", "value" ] 42
  _ <- Store.modifyMutablePath mutableFixture.mutable [ "nested", "value" ] (_ + 1)

  nestedAfter <- Store.getMutableField (Proxy :: Proxy "nested") mutableFixture.mutable
  assertEqual "mutable nested path updates value" 43 nestedAfter.value
  assertEqual "mutable nested updates keep branch reference" true (sameRef nestedBefore nestedAfter)

  unwrappedMutable <- Store.unwrapMutable mutableFixture.mutable
  assertEqual "unwrapMutable exposes latest nested state" 43 unwrappedMutable.nested.value

  mutableFixture.dispose
