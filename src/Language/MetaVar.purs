module Sky.Language.MetaVar
  ( META_CONTEXT
  , freshMeta
  , getMetaContext
  , lookupMeta
  , solveMeta
  ) where

import Prelude

import Data.HashMap as HM
import Data.Maybe (Maybe(..))
import Data.Newtype as Newtype
import Record as Record
import Run (Run)
import Run.State (State)
import Run.State as State
import Run.Supply (SUPPLY)
import Run.Supply as Supply
import Sky.Language.Error (MetaError(..), SKY_ERROR, throwMetaError)
import Sky.Language.Term (MetaContext(..), MetaVar(..), Value)
import Type.Proxy (Proxy(..))
import Type.Row (type (+))

---------- Effect related stuff
type META_CONTEXT a r =
  ( metaContext :: State (MetaContext a)
  | r
  )

getMetaContext :: forall a r. Run (META_CONTEXT a r) (MetaContext a)
getMetaContext = State.getAt _metaContext

---------- Helpers
lookupMeta
  :: forall a r
   . a
  -> MetaVar
  -> Run (SKY_ERROR a + META_CONTEXT a + r) (Maybe (Value a))
lookupMeta source var = getMetaContext >>= \(MetaContext context) ->
  case HM.lookup var context.metas of
    Just metaEntry -> pure metaEntry
    Nothing -> throwMetaError $ MetaNotInContext
      { meta: var
      , source
      }

-- | Generate an unique meta variable, and set it's status as unsolved
freshMeta :: forall a r. Run (SUPPLY Int + META_CONTEXT a r) MetaVar
freshMeta = do
  id <- Supply.generate <#> MetaVar
  let update = Record.modify _metas $ HM.insert id Nothing
  State.modifyAt _metaContext $ Newtype.over MetaContext update
  pure id

solveMeta :: forall a r. MetaVar -> Value a -> Run (META_CONTEXT a r) Unit
solveMeta meta solution = State.modifyAt _metaContext
  $ Newtype.over MetaContext
  $ Record.modify _metas
  $ HM.insert meta
  $ Just solution

---------- Proxies
_metaContext :: Proxy "metaContext"
_metaContext = Proxy

_metas :: Proxy "metas"
_metas = Proxy