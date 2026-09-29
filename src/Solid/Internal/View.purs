-- | Internal: the view runtime behind `Solid.JSX`, `Solid.DOM`,
-- | `Solid.Component`, `Solid.Control`, `Solid.Context` and `Solid.Web`.
-- | It's one module because FFI files can't share code, and everything here
-- | needs `realize`.
-- |
-- | `JSX` is a lazy description: building it does nothing. Each place it's
-- | rendered creates fresh DOM (a template, not an instance).
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
  , reactiveProp
  , bindingProp
  , eventProp
  , refProp
  , Realized
  , realize
  , ComponentRep
  , componentRep
  , componentElement
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
  , lazyImpl
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

-- | A property for an element whose supported properties are `r`. Helpers
-- | require their label in `r`, so an attribute an element doesn't have is a
-- | type error.
foreign import data Prop :: Row Type -> Type

-- | A value that is either fixed or reactive.
data Binding a
  = Static a
  | Dynamic (Accessor a)

-- | Anything accepted where a value may be static or reactive: `v` is either
-- | `a` itself or `Accessor a`. This is how `class_ "btn"` and
-- | `class_ activeClass` both type-check.
class ToBinding :: Type -> Type -> Constraint
class ToBinding v a | v -> a where
  binding :: v -> Binding a

instance ToBinding (Accessor a) a where
  binding = Dynamic
else instance ToBinding a a where
  binding = Static

foreign import textJsx :: String -> JSX

-- | A reactive region: re-renders its content when the accessor changes.
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

-- | A fixed property (attribute, DOM property, `class` or `style`).
staticProp :: forall r a. String -> a -> Prop r
staticProp = runFn2 staticPropImpl

-- | A reactive property, re-applied when the accessor changes.
reactiveProp :: forall r a. String -> Accessor a -> Prop r
reactiveProp = runFn2 reactivePropImpl

bindingProp :: forall r a b. String -> (a -> b) -> Binding a -> Prop r
bindingProp name convert = case _ of
  Static value -> staticProp name (convert value)
  Dynamic accessor -> reactiveProp name (convert <$> accessor)

foreign import eventPropImpl :: forall r e. Fn2 String (e -> Effect Unit) (Prop r)

-- | An event handler (`onClick`, ...). Delegated when Solid delegates the event.
eventProp :: forall r e. String -> (e -> Effect Unit) -> Prop r
eventProp = runFn2 eventPropImpl

-- | Runs with the element once it's created, before it's attached. Refs run
-- | without an owner (Solid 2), so they can't create reactive primitives.
foreign import refProp :: forall r. (Element -> Effect Unit) -> Prop r

-- | What Solid renders: the output of `realize`.
foreign import data Realized :: Type

-- | Turns a description into what Solid inserts. Call inside an owner.
foreign import realize :: JSX -> Realized

-- | A Solid component function.
foreign import data ComponentRep :: Type -> Type

-- | A component whose render function's result is realized on each call.
foreign import componentRep :: forall props. (props -> Effect JSX) -> ComponentRep props

-- | A lazy use of a component.
foreign import componentElement :: forall props. Fn2 (ComponentRep props) props JSX

-- | The value `Show` / `Match` test, encoded so falsy PureScript values
-- | (`Just false`, `Just 0`, `Just ""`) still count as present.
foreign import data WhenValue :: Type -> Type

foreign import whenValue :: forall a. a -> WhenValue a

-- Control flow. Content arguments are lazy `JSX`; render callbacks are the
-- `Effect` behind `Setup` (the public modules run `runSetup`).

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

-- | `Switch` over `Match` cases (built with `matchImpl` / `matchMaybeImpl`).
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

-- | `provideImpl context value children`: the context object is the provider.
foreign import provideImpl :: forall context a. Fn3 context a (Effect JSX) JSX

-- | Solid's `children` helper over a lazily built subtree.
foreign import childrenImpl :: EffectFn1 (Effect JSX) (Accessor JSX)

foreign import lazyImpl :: forall props. Effect (Promise (ComponentRep props)) -> ComponentRep props
