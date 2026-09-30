-- | Router actions: mutations the router tracks. When one finishes the router
-- | applies its `Reply` (redirect, revalidation) and, unless the reply says
-- | otherwise, revalidates every query on screen. Forms can post to one
-- | (`P.action (formAction save)` with method `POST`), which works before
-- | hydration too. For transactional steps and optimistic values, see
-- | `Solid.Action`.
module Solid.Router.Action
  ( RouterAction
  , routerAction
  , serverAction
  , formAction
  , useAction
  , Submission
  , useSubmissions
  , Submitting
  , onSubmit
  , onSettled
  ) where

import Prelude

import Control.Promise (Promise, fromAff, toAffE)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Exception (Error)
import Solid.Internal.Optimistic (class MonadOptimistic)
import Solid.Internal.Serializable (class Serializable)
import Solid.Internal.ServerFunction (ServerFunction, checked)
import Solid.Internal.Setup (Setup(..))
import Solid.Signal (Accessor)
import Solid.Start.Response (Reply)
import Web.XHR.FormData (FormData)

foreign import data RouterAction :: Type -> Type -> Type

-- | `name` identifies the action (and its form URL); make it unique.
routerAction :: forall a b. String -> (a -> Aff (Reply b)) -> RouterAction a b
routerAction name run = runFn2 routerActionImpl name (fromAff <<< run)

-- | A server function as a router action; its `Reply` travels in the response.
serverAction :: forall a b. Serializable a => Serializable b => String -> ServerFunction a (Reply b) -> RouterAction a b
serverAction name fn = runFn2 serverActionImpl name (checked fn)

-- | The URL a `<form method="post">` posts to. The router submits the form's
-- | `FormData`.
foreign import formAction :: forall b. RouterAction FormData b -> String

-- | Runs the action. `Nothing` when it replied with a redirect or a reload.
useAction :: forall a b. RouterAction a b -> Setup (a -> Aff (Maybe b))
useAction act = Setup do
  run <- useActionImpl act
  pure \input -> toMaybe <$> toAffE (run input)

-- | A finished run worth showing: one with a result or an error.
type Submission a b =
  { input :: a
  , result :: Maybe b
  , error :: Maybe Error
  -- | Removes it from the list.
  , clear :: Effect Unit
  -- | Clears it and runs the action again with the same input.
  , retry :: Aff (Maybe b)
  }

useSubmissions :: forall a b. RouterAction a b -> Setup (Accessor (Array (Submission a b)))
useSubmissions act = Setup (map (map toSubmission) <$> useSubmissionsImpl act)

toSubmission :: forall a b. SubmissionRep a b -> Submission a b
toSubmission rep =
  { input: rep.input
  , result: toMaybe rep.result
  , error: toMaybe rep.error
  , clear: rep.clear
  , retry: toMaybe <$> toAffE rep.retry
  }

-- | Runs as a submission starts, inside its transaction: make optimistic writes
-- | here (`Solid.Action.setOptimistic`, `Solid.Store.updateOptimistic`).
newtype Submitting a = Submitting (Effect a)

derive newtype instance Functor Submitting
derive newtype instance Apply Submitting
derive newtype instance Applicative Submitting
derive newtype instance Bind Submitting
derive newtype instance Monad Submitting

instance MonadOptimistic Submitting where
  liftOptimistic = Submitting

onSubmit :: forall a b. (a -> Submitting Unit) -> RouterAction a b -> RouterAction a b
onSubmit hook act = runFn2 onSubmitImpl act \input -> case hook input of Submitting effect -> effect

-- | Runs after every submission, including redirects and ones with no result.
onSettled :: forall a b. (Submission a b -> Effect Unit) -> RouterAction a b -> RouterAction a b
onSettled hook act = runFn2 onSettledImpl act (hook <<< toSubmission)

type SubmissionRep a b =
  { input :: a
  , result :: Nullable b
  , error :: Nullable Error
  , clear :: Effect Unit
  , retry :: Effect (Promise (Nullable b))
  }

foreign import routerActionImpl :: forall a b. Fn2 String (a -> Effect (Promise (Reply b))) (RouterAction a b)

foreign import serverActionImpl :: forall a b. Fn2 String (ServerFunction a (Reply b)) (RouterAction a b)

foreign import useActionImpl :: forall a b. RouterAction a b -> Effect (a -> Effect (Promise (Nullable b)))

foreign import onSubmitImpl :: forall a b. Fn2 (RouterAction a b) (a -> Effect Unit) (RouterAction a b)

foreign import onSettledImpl :: forall a b. Fn2 (RouterAction a b) (SubmissionRep a b -> Effect Unit) (RouterAction a b)

foreign import useSubmissionsImpl :: forall a b. RouterAction a b -> Effect (Accessor (Array (SubmissionRep a b)))
