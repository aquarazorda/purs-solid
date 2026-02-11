module Solid.Start.Entry.Client
  ( ClientMode(..)
  , ClientEntryError(..)
  , bootstrapAt
  , bootstrapAtId
  , bootstrapInBody
  ) where

import Data.Either (Either(..))
import Effect (Effect)
import Prelude

import Solid.Start.App (App, runApp)
import Solid.Web (Mountable, WebError)
import Solid.Web as Web

data ClientMode
  = RenderMode
  | HydrateMode

derive instance eqClientMode :: Eq ClientMode

instance showClientMode :: Show ClientMode where
  show = case _ of
    RenderMode -> "RenderMode"
    HydrateMode -> "HydrateMode"

data ClientEntryError
  = MountFailure WebError
  | RenderFailure WebError
  | HydrateFailure WebError

derive instance eqClientEntryError :: Eq ClientEntryError

instance showClientEntryError :: Show ClientEntryError where
  show = case _ of
    MountFailure webError -> "MountFailure " <> show webError
    RenderFailure webError -> "RenderFailure " <> show webError
    HydrateFailure webError -> "HydrateFailure " <> show webError

bootstrapAt :: ClientMode -> App -> Mountable -> Effect (Either ClientEntryError (Effect Unit))
bootstrapAt mode app mount =
  case mode of
    RenderMode -> do
      result <- Web.render (runApp app) mount
      pure case result of
        Left webError -> Left (RenderFailure webError)
        Right disposer -> Right disposer
    HydrateMode -> do
      result <- Web.hydrate (runApp app) mount
      pure case result of
        Left webError -> Left (HydrateFailure webError)
        Right disposer -> Right disposer

bootstrapAtId :: ClientMode -> String -> App -> Effect (Either ClientEntryError (Effect Unit))
bootstrapAtId mode mountId app = do
  mountResult <- Web.requireMountById mountId
  case mountResult of
    Left webError -> pure (Left (MountFailure webError))
    Right mount -> bootstrapAt mode app mount

bootstrapInBody :: ClientMode -> App -> Effect (Either ClientEntryError (Effect Unit))
bootstrapInBody mode app = do
  bodyResult <- Web.requireBody
  case bodyResult of
    Left webError -> pure (Left (MountFailure webError))
    Right mount -> bootstrapAt mode app mount
