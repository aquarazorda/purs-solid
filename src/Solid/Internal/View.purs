-- | Internal view runtime. `JSX` is a lazy description: each place it's
-- | rendered creates fresh DOM.
module Solid.Internal.View
  ( JSX
  , Prop
  , class ToBinding
  , textJsx
  , textBinding
  , reactiveJsx
  , fragment
  , empty
  , Namespace
  , htmlNamespace
  , svgNamespace
  , mathmlNamespace
  , elementWith
  , staticProp
  , bindingProp
  , eventProp
  , refProp
  , propsProp
  , Realized
  , realize
  , ComponentRep
  , componentRep
  , componentElement
  , propsComponentElement
  , JsPropEntry
  , jsPropsComponentElement
  , WhenValue
  , whenValue
  , showImpl
  , showMaybeImpl
  , Keyed
  , keyedByIdentity
  , keyedByPosition
  , keyedBy
  , forImpl
  , repeatImpl
  , switchImpl
  , matchImpl
  , matchMaybeImpl
  , loadingImpl
  , erroredImpl
  , revealImpl
  , portalImpl
  , dynamicImpl
  , noHydrationImpl
  , hydrationImpl
  , provideImpl
  , childrenImpl
  , childrenArrayImpl
  , LazyModule
  , loadModule
  , class LazyName
  , lazyName
  , lazyImpl
  , clientOnlyImpl
  , preloadImpl
  ) where

import Prelude

import Control.Promise (Promise)
import Data.Function.Uncurried (Fn2, Fn3, Fn4, runFn2, runFn3, runFn4)
import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn1)
import Solid.Signal (Accessor)
import Unsafe.Coerce (unsafeCoerce)
import Data.String as String
import Data.Symbol (class IsSymbol, reflectSymbol)
import Prim.Symbol as Symbol
import Type.Proxy (Proxy(..))
import Web.DOM.Element (Element)

foreign import data JSX :: Type

-- | A property for an element whose supported properties are `r`.
foreign import data Prop :: Row Type -> Type

-- | `v` is either `a` or `Accessor a`, so `class_ "btn"` and
-- | `class_ activeClass` both type-check. The FFI tells them apart with
-- | `typeof`: attribute and text values are never functions.
class ToBinding :: Type -> Type -> Constraint
class ToBinding v a | v -> a

instance ToBinding (Accessor a) a
else instance ToBinding a a

foreign import textJsx :: String -> JSX

-- | Text from a `String` or an `Accessor String`.
foreign import textBindingImpl :: forall v. v -> JSX

textBinding :: forall v. ToBinding v String => v -> JSX
textBinding = textBindingImpl

foreign import reactiveJsx :: Accessor JSX -> JSX

foreign import fragment :: Array JSX -> JSX

foreign import empty :: JSX

newtype Namespace = Namespace Int

htmlNamespace :: Namespace
htmlNamespace = Namespace 0

svgNamespace :: Namespace
svgNamespace = Namespace 1

mathmlNamespace :: Namespace
mathmlNamespace = Namespace 2

elementWith :: forall r. Namespace -> String -> Array (Prop r) -> Array JSX -> JSX
elementWith = runFn4 elementImpl

foreign import elementImpl :: forall r. Fn4 Namespace String (Array (Prop r)) (Array JSX) JSX

foreign import staticPropImpl :: forall r a. Fn2 String a (Prop r)

staticProp :: forall r a. String -> a -> Prop r
staticProp = runFn2 staticPropImpl

foreign import bindingPropImpl :: forall r v a b. Fn3 String (a -> b) v (Prop r)

-- | `convert` is applied to the value, or to each value the accessor yields.
bindingProp :: forall r v a b. ToBinding v a => String -> (a -> b) -> v -> Prop r
bindingProp = runFn3 bindingPropImpl

foreign import eventPropImpl :: forall r e. Fn2 String (e -> Effect Unit) (Prop r)

eventProp :: forall r e. String -> (e -> Effect Unit) -> Prop r
eventProp = runFn2 eventPropImpl

-- | Runs with the element before it's attached, without an owner, so it
-- | can't create reactive primitives.
foreign import refProp :: forall r. (Element -> Effect Unit) -> Prop r

-- | Several props as one.
foreign import propsProp :: forall r. Array (Prop r) -> Prop r

foreign import data Realized :: Type

-- | Call inside an owner.
foreign import realize :: JSX -> Realized

foreign import data ComponentRep :: Type -> Type

foreign import componentRep :: forall props. (props -> Effect JSX) -> ComponentRep props

foreign import componentElement :: forall props. Fn2 (ComponentRep props) props JSX

foreign import propsComponentElement :: forall component r. Fn3 component (Array (Prop r)) (Array JSX) JSX

-- | `{ key, get }` or `{ key, value }`.
foreign import data JsPropEntry :: Type

foreign import jsPropsComponentElement :: forall component. Fn2 component (Array JsPropEntry) JSX

-- | Encoded so falsy values (`Just false`, `Just 0`, `Just ""`) still count
-- | as present in `Show` / `Match`.
foreign import data WhenValue :: Type -> Type

foreign import whenValue :: forall a. a -> WhenValue a

foreign import showImpl :: Fn3 (Accessor Boolean) JSX JSX JSX

-- | `keyed` passes the value itself (re-created per value), otherwise an accessor.
foreign import showMaybeImpl
  :: forall a v. Fn4 Boolean (Accessor (Nullable (WhenValue a))) JSX (v -> Effect JSX) JSX

-- | How `For` matches items to views; `item` and `index` are what the
-- | render callback receives in that mode.
foreign import data Keyed :: Type -> Type -> Type -> Type

foreign import keyedByIdentity :: forall a. Keyed a a (Accessor Int)

foreign import keyedByPosition :: forall a. Keyed a (Accessor a) Int

keyedBy :: forall a k. (a -> k) -> Keyed a (Accessor a) (Accessor Int)
keyedBy = unsafeCoerce

foreign import forImpl
  :: forall a item index. Fn4 (Keyed a item index) (Accessor (Array a)) JSX (item -> index -> Effect JSX) JSX

foreign import repeatImpl :: Fn3 (Accessor Int) JSX (Int -> Effect JSX) JSX

foreign import switchImpl :: Fn2 (Array JSX) JSX JSX

foreign import matchImpl :: Fn2 (Accessor Boolean) JSX JSX

foreign import matchMaybeImpl :: forall a. Fn2 (Accessor (Nullable (WhenValue a))) (a -> Effect JSX) JSX

foreign import loadingImpl :: forall a. Fn3 (Nullable (Accessor a)) JSX JSX JSX

foreign import erroredImpl :: Fn2 (Accessor Error -> Effect Unit -> Effect JSX) JSX JSX

foreign import revealImpl :: forall options. Fn2 { | options } (Array JSX) JSX

foreign import portalImpl :: Fn2 (Nullable Element) JSX JSX

foreign import dynamicImpl :: forall props. Fn2 (Accessor (ComponentRep props)) props JSX

foreign import noHydrationImpl :: JSX -> JSX

foreign import hydrationImpl :: JSX -> JSX

foreign import provideImpl :: forall context a. Fn3 context a (Effect JSX) JSX

foreign import childrenImpl :: EffectFn1 (Effect JSX) (Accessor JSX)

foreign import childrenArrayImpl :: EffectFn1 (Effect JSX) (Accessor (Array JSX))

-- | A module namespace from a dynamic `import()`.
foreign import data LazyModule :: Type

foreign import loadModule :: String -> Effect (Promise LazyModule)

-- | The name of a lazily loaded module or value. It reaches the compiled call
-- | site as a `"purs-solid:lazy:<name>"` literal, which is how
-- | `purs-solid/vite` finds what to split into chunks.
class LazyName :: Symbol -> Constraint
class LazyName name where
  lazyName :: Proxy name -> String

instance (Symbol.Append "purs-solid:lazy:" name tagged, IsSymbol tagged) => LazyName name where
  lazyName _ = String.drop 16 (reflectSymbol (Proxy :: Proxy tagged))

foreign import lazyImpl :: forall props. Fn2 String (Effect (Promise LazyModule)) (ComponentRep props)

foreign import clientOnlyImpl :: forall props. Fn2 String (Effect (Promise LazyModule)) (ComponentRep props)

foreign import preloadImpl :: forall props. EffectFn1 (ComponentRep props) Unit
