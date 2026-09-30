-- | Internal view runtime. `JSX` is a lazy description: each place it's
-- | rendered creates fresh DOM.
module Solid.Internal.View
  ( JSX
  , Prop
  , Binding(..)
  , class ToBinding
  , binding
  , textJsx
  , reactiveJsx
  , fragment
  , empty
  , Namespace(..)
  , elementWith
  , staticProp
  , bindingProp
  , eventProp
  , refProp
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
  , showMaybeKeyedImpl
  , forImpl
  , forUnkeyedImpl
  , forByImpl
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
  , LazyModule
  , lazyImpl
  , preloadImpl
  ) where

import Prelude

import Control.Promise (Promise)
import Data.Function.Uncurried (Fn2, Fn3, Fn4, runFn2, runFn4)
import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn1)
import Solid.Signal (Accessor)
import Web.DOM.Element (Element)

foreign import data JSX :: Type

-- | A property for an element whose supported properties are `r`.
foreign import data Prop :: Row Type -> Type

data Binding a
  = Static a
  | Dynamic (Accessor a)

-- | `v` is either `a` or `Accessor a`, so `class_ "btn"` and
-- | `class_ activeClass` both type-check.
class ToBinding :: Type -> Type -> Constraint
class ToBinding v a | v -> a where
  binding :: v -> Binding a

instance ToBinding (Accessor a) a where
  binding = Dynamic
else instance ToBinding a a where
  binding = Static

foreign import textJsx :: String -> JSX

foreign import reactiveJsx :: Accessor JSX -> JSX

foreign import fragment :: Array JSX -> JSX

foreign import empty :: JSX

data Namespace = HtmlNamespace | SvgNamespace | MathMLNamespace

elementWith :: forall r. Namespace -> String -> Array (Prop r) -> Array JSX -> JSX
elementWith namespace tag props children = runFn4 elementImpl code tag props children
  where
  code = case namespace of
    HtmlNamespace -> 0
    SvgNamespace -> 1
    MathMLNamespace -> 2

foreign import elementImpl :: forall r. Fn4 Int String (Array (Prop r)) (Array JSX) JSX

foreign import staticPropImpl :: forall r a. Fn2 String a (Prop r)
foreign import reactivePropImpl :: forall r a. Fn2 String (Accessor a) (Prop r)

staticProp :: forall r a. String -> a -> Prop r
staticProp = runFn2 staticPropImpl

reactiveProp :: forall r a. String -> Accessor a -> Prop r
reactiveProp = runFn2 reactivePropImpl

bindingProp :: forall r a b. String -> (a -> b) -> Binding a -> Prop r
bindingProp name convert = case _ of
  Static value -> staticProp name (convert value)
  Dynamic accessor -> reactiveProp name (convert <$> accessor)

foreign import eventPropImpl :: forall r e. Fn2 String (e -> Effect Unit) (Prop r)

eventProp :: forall r e. String -> (e -> Effect Unit) -> Prop r
eventProp = runFn2 eventPropImpl

-- | Runs with the element before it's attached, without an owner, so it
-- | can't create reactive primitives.
foreign import refProp :: forall r. (Element -> Effect Unit) -> Prop r

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

foreign import showMaybeImpl
  :: forall a. Fn3 (Accessor (Nullable (WhenValue a))) JSX (Accessor a -> Effect JSX) JSX

foreign import showMaybeKeyedImpl
  :: forall a. Fn3 (Accessor (Nullable (WhenValue a))) JSX (a -> Effect JSX) JSX

foreign import forImpl :: forall a. Fn3 (Accessor (Array a)) JSX (a -> Accessor Int -> Effect JSX) JSX

foreign import forUnkeyedImpl :: forall a. Fn3 (Accessor (Array a)) JSX (Accessor a -> Int -> Effect JSX) JSX

foreign import forByImpl
  :: forall a k. Fn4 (a -> k) (Accessor (Array a)) JSX (Accessor a -> Accessor Int -> Effect JSX) JSX

foreign import repeatImpl :: Fn3 (Accessor Int) JSX (Int -> Effect JSX) JSX

foreign import switchImpl :: Fn2 (Array JSX) JSX JSX

foreign import matchImpl :: Fn2 (Accessor Boolean) JSX JSX

foreign import matchMaybeImpl :: forall a. Fn2 (Accessor (Nullable (WhenValue a))) (a -> Effect JSX) JSX

foreign import loadingImpl :: Fn2 JSX JSX JSX

foreign import erroredImpl :: Fn2 (Accessor Error -> Effect Unit -> Effect JSX) JSX JSX

foreign import revealImpl :: Fn3 String Boolean (Array JSX) JSX

foreign import portalImpl :: Fn2 (Nullable Element) JSX JSX

foreign import dynamicImpl :: forall props. Fn2 (Accessor (ComponentRep props)) props JSX

foreign import noHydrationImpl :: JSX -> JSX

foreign import hydrationImpl :: JSX -> JSX

foreign import provideImpl :: forall context a. Fn3 context a (Effect JSX) JSX

foreign import childrenImpl :: EffectFn1 (Effect JSX) (Accessor JSX)

-- | A module namespace from a dynamic `import()`.
foreign import data LazyModule :: Type

foreign import lazyImpl :: forall props. Fn2 String (Effect (Promise LazyModule)) (ComponentRep props)

foreign import preloadImpl :: forall props. EffectFn1 (ComponentRep props) Unit
