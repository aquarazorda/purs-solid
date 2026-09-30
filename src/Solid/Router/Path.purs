-- | Route paths, parsed at compile time: `:name` is a `String`, `:name?` a
-- | `Maybe String`, and `*name` (the rest of the path) a `String`. A filter
-- | narrows a param: `:id<int>` matches integers only and is an `Int`.
-- |
-- | ```purescript
-- | href @"/users/:id<int>/:tab?" { id: 42, tab: Nothing }  -- "/users/42"
-- | ```
module Solid.Router.Path
  ( class PathParams
  , class ParsePath
  , class ParseSegment
  , class ParseName
  , class ParseNameChar
  , class ParseFilter
  , class ParseFilterChar
  , class ParamFilter
  , RoutePattern
  , routePattern
  , href
  ) where

import Data.Function.Uncurried (Fn3, runFn3)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toNullable)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Prim.Row as Row
import Prim.Symbol as Symbol
import Prim.TypeError (class Fail, Beside, Quote, Text)
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
else instance ParseFilter tail "" acc params => ParseNameChar "<" tail acc value params
else instance (Symbol.Append acc head acc', ParseName tail acc' value params) => ParseNameChar head tail acc value params

class ParseFilter :: Symbol -> Symbol -> Symbol -> Row Type -> Constraint
class ParseFilter rest filter name params | rest filter name -> params

instance (Symbol.Cons head tail rest, ParseFilterChar head tail filter name params) => ParseFilter rest filter name params

class ParseFilterChar :: Symbol -> Symbol -> Symbol -> Symbol -> Row Type -> Constraint
class ParseFilterChar head tail filter name params | head tail filter name -> params

instance (ParamFilter filter value, ParseName tail name value params) => ParseFilterChar ">" tail filter name params
else instance (Symbol.Append filter head filter', ParseFilter tail filter' name params) => ParseFilterChar head tail filter name params

-- | The param filters and the type each gives its param.
class ParamFilter :: Symbol -> Type -> Constraint
class ParamFilter filter value | filter -> value

instance ParamFilter "int" Int
else instance Fail (Beside (Text "Unknown route param filter ") (Beside (Quote filter) (Text "; the supported filter is <int>"))) => ParamFilter filter value

-- | A path parsed at runtime: Solid's path, its match filters, and how to
-- | read and render each param.
foreign import data RoutePattern :: Type

foreign import routePattern :: String -> RoutePattern

-- | `Nothing` optional params are left out; values are URI-encoded.
href :: forall @path params. IsSymbol path => PathParams path params => { | params } -> String
href params = runFn3 hrefImpl toNullable (routePattern (reflectSymbol (Proxy :: Proxy path))) params

foreign import hrefImpl :: forall params. Fn3 (Maybe String -> Nullable String) RoutePattern { | params } String
