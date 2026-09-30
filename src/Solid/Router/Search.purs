-- | Typed query params. A schema row declares each param as a `Maybe` or an
-- | `Array` of `String`, `Int` or `Boolean`; values that don't parse read as
-- | `Nothing` or are left out.
-- |
-- | ```purescript
-- | search <- useSearch @(page :: Maybe Int, tag :: Array String)
-- | text (show <<< _.page <$> searchParams search)
-- | setSearch search { page: Just 2 }
-- | ```
module Solid.Router.Search
  ( Search
  , useSearch
  , searchParams
  , setSearch
  , setSearchWith
  , class SearchValue
  , parseSearchValue
  , printSearchValue
  , class SearchField
  , readSearchField
  , writeSearchField
  , class SearchFields
  , searchFields
  , SearchFieldCodec
  , SearchFieldValue
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..), maybe)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, runEffectFn1, runEffectFn3)
import Prim.Row as Row
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Prim.TypeError (class Fail, Beside, Quote, Text)
import Solid.Internal.Setup (Setup(..))
import Solid.Router (NavigateOptions)
import Solid.Signal (Accessor)
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)

-- | The current location's query params, read and written with schema `r`.
foreign import data Search :: Row Type -> Type

useSearch :: forall @r rl. RowToList r rl => SearchFields rl => Setup (Search r)
useSearch = Setup (runEffectFn1 useSearchImpl (searchFields (Proxy :: Proxy rl)))

foreign import searchParams :: forall r. Search r -> Accessor { | r }

-- | Sets the given params; `Nothing` or `[]` removes one. Params not given stay.
setSearch :: forall r given missing. Row.Union given missing r => Search r -> { | given } -> Effect Unit
setSearch = setSearchWith {}

-- | Takes any subset of `NavigateOptions`.
setSearchWith
  :: forall r given missing options optionsMissing
   . Row.Union given missing r
  => Row.Union options optionsMissing NavigateOptions
  => { | options }
  -> Search r
  -> { | given }
  -> Effect Unit
setSearchWith options search given = runEffectFn3 setSearchImpl search given options

class SearchValue a where
  parseSearchValue :: String -> Maybe a
  printSearchValue :: a -> String

instance SearchValue String where
  parseSearchValue = Just
  printSearchValue = identity

instance SearchValue Int where
  parseSearchValue = Int.fromString
  printSearchValue = show

instance SearchValue Boolean where
  parseSearchValue = case _ of
    "true" -> Just true
    "false" -> Just false
    _ -> Nothing
  printSearchValue = show

-- | A param can always be missing, so it's a `Maybe` (the first value) or an
-- | `Array` (every value).
class SearchField a where
  readSearchField :: Array String -> a
  writeSearchField :: a -> Array String

instance SearchValue a => SearchField (Maybe a) where
  readSearchField = Array.head >=> parseSearchValue
  writeSearchField = maybe [] (pure <<< printSearchValue)
else instance SearchValue a => SearchField (Array a) where
  readSearchField = Array.mapMaybe parseSearchValue
  writeSearchField = map printSearchValue
else instance
  Fail (Beside (Text "A query param can be missing, so make it a Maybe or an Array, not ") (Quote a)) =>
  SearchField a where
  readSearchField _ = unsafeCoerce unit
  writeSearchField _ = []

foreign import data SearchFieldValue :: Type

type SearchFieldCodec =
  { name :: String
  , read :: Array String -> SearchFieldValue
  , write :: SearchFieldValue -> Array String
  }

class SearchFields :: RowList Type -> Constraint
class SearchFields rl where
  searchFields :: Proxy rl -> Array SearchFieldCodec

instance SearchFields RL.Nil where
  searchFields _ = []

instance (IsSymbol name, SearchField a, SearchFields rest) => SearchFields (RL.Cons name a rest) where
  searchFields _ = Array.cons field (searchFields (Proxy :: Proxy rest))
    where
    field =
      { name: reflectSymbol (Proxy :: Proxy name)
      , read: unsafeCoerce (readSearchField :: Array String -> a)
      , write: unsafeCoerce (writeSearchField :: a -> Array String)
      }

foreign import useSearchImpl :: forall r. EffectFn1 (Array SearchFieldCodec) (Search r)

foreign import setSearchImpl :: forall r given options. EffectFn3 (Search r) { | given } { | options } Unit
