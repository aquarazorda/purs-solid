-- | Route paths, parsed at compile time: `:name` is a `String`, `:name?` a
-- | `Maybe String`, and `*name` (the rest of the path) a `String`.
-- |
-- | ```purescript
-- | href @"/users/:id/:tab?" { id: "42", tab: Nothing }  -- "/users/42"
-- | ```
module Solid.Router.Path
  ( class PathParams
  , class ParsePath
  , class ParseSegment
  , class ParseName
  , class ParseNameChar
  , class ParamFields
  , paramFields
  , ParamField
  , href
  ) where

import Prelude

import Data.Function.Uncurried (Fn3, runFn3)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toNullable)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Prim.Row as Row
import Prim.RowList (RowList)
import Prim.RowList as RL
import Prim.Symbol as Symbol
import Type.Proxy (Proxy(..))

-- | `params` is the row of params that `path` declares.
class PathParams :: Symbol -> Row Type -> Constraint
class PathParams path params | path -> params

instance ParsePath path params => PathParams path params

class ParsePath :: Symbol -> Row Type -> Constraint
class ParsePath path params | path -> params

instance ParsePath "" ()
else instance (Symbol.Cons head tail path, ParseSegment head tail params) => ParsePath path params

class ParseSegment :: Symbol -> Symbol -> Row Type -> Constraint
class ParseSegment head tail params | head tail -> params

instance ParseName tail "" String params => ParseSegment ":" tail params
else instance ParseName tail "" String params => ParseSegment "*" tail params
else instance ParsePath tail params => ParseSegment head tail params

class ParseName :: Symbol -> Symbol -> Type -> Row Type -> Constraint
class ParseName rest acc value params | rest acc value -> params

instance Row.Cons acc value () params => ParseName "" acc value params
else instance (Symbol.Cons head tail rest, ParseNameChar head tail acc value params) => ParseName rest acc value params

class ParseNameChar :: Symbol -> Symbol -> Symbol -> Type -> Row Type -> Constraint
class ParseNameChar head tail acc value params | head tail acc value -> params

instance (ParsePath tail rest, Row.Cons acc value rest params) => ParseNameChar "/" tail acc value params
else instance (ParsePath tail rest, Row.Cons acc (Maybe value) rest params) => ParseNameChar "?" tail acc value params
else instance (Symbol.Append acc head acc', ParseName tail acc' value params) => ParseNameChar head tail acc value params

type ParamField = { name :: String, optional :: Boolean }

class ParamFields :: RowList Type -> Constraint
class ParamFields rl where
  paramFields :: Proxy rl -> Array ParamField

instance ParamFields RL.Nil where
  paramFields _ = []

instance (IsSymbol name, ParamFields tail) => ParamFields (RL.Cons name (Maybe String) tail) where
  paramFields _ = [ { name: reflectSymbol (Proxy :: Proxy name), optional: true } ] <> paramFields (Proxy :: Proxy tail)
else instance (IsSymbol name, ParamFields tail) => ParamFields (RL.Cons name String tail) where
  paramFields _ = [ { name: reflectSymbol (Proxy :: Proxy name), optional: false } ] <> paramFields (Proxy :: Proxy tail)

-- | `Nothing` optional params are left out; values are URI-encoded.
href :: forall @path params. IsSymbol path => PathParams path params => { | params } -> String
href params = runFn3 hrefImpl toNullable (reflectSymbol (Proxy :: Proxy path)) params

foreign import hrefImpl :: forall params. Fn3 (Maybe String -> Nullable String) String { | params } String
