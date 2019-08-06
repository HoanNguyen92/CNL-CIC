{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-
Author(s): Jesse Michael Han (2019)

Managing the parser state.
-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module CNLean.Basic.ParserState where

import Prelude
import Control.Monad.Trans.State
import qualified Prelude
import Text.Megaparsec hiding (Token, Label, option, Tokens)
import Text.Megaparsec.Char
import Data.Text (Text, pack, unpack, toLower)
import Data.Void
import qualified Data.Map as M
import Control.Monad.Trans.State.Lazy (modify, gets)
import qualified Data.Char as C
import qualified Text.Megaparsec.Char.Lexer as L

import Control.Lens
import Control.Lens.TH

import Language.Haskell.TH

import CNLean.Basic.Core
import CNLean.Basic.State
import CNLean.Basic.Token

$(makeLenses ''FState)

$(makeLenses ''Stack)

data LocalGlobalFlag =
    Globally
  | Locally
  | AtLevel Int
  deriving (Show, Eq)

updateGlobal :: (FState -> FState) -> Parser ()
updateGlobal f =
  (rest %= \fs -> (fs & _last %~ f)) <||> -- if the first branch fails, then rest is empty, so modify top instead
  (top %= f)

updateLocal :: (FState -> FState) -> Parser ()
updateLocal f =
  (top %= f)

updateAtLevel :: Int -> (FState -> FState) -> Parser ()
updateAtLevel k f = do
  d <- depthStack <$> get -- stack always contains d + 1 states
  if k > d
    then fail "stack index out of bounds"
    else if k == d
            then updateLocal f
            else (rest . element k %= f)    

updateGlobalPrimPrecTable :: Pattern -> Int -> AssociativeParity -> Parser ()
updateGlobalPrimPrecTable ptts level parity = updateGlobal $ primPrecTable %~ M.insert ptts (level, parity)

updateGlobalClsList :: [Text] -> Parser ()
updateGlobalClsList txts = updateGlobal $ clsList %~ (:) txts

updateGlobalClsList2 :: [[Text]] -> Parser ()
updateGlobalClsList2 txtss = updateGlobal $ clsList %~ (<>) txtss

updateLocalClsList :: [Text] -> Parser ()
updateLocalClsList txts = updateLocal $ clsList %~ (:) txts

updateAtLevelClsList :: Int -> [Text] -> Parser ()
updateAtLevelClsList k txts = updateAtLevel k $ clsList %~ (:) txts

updateLocalClsList2 :: [[Text]] -> Parser ()
updateLocalClsList2 txts = updateLocal $ clsList %~ (<>) txts

updateAtLevelClsList2 :: Int -> [[Text]] -> Parser ()
updateAtLevelClsList2 k txts = updateAtLevel k $ clsList %~ (<>) txts

updateClsList :: LocalGlobalFlag -> [Text] -> Parser ()
updateClsList b args =
  case b of
    Globally -> updateGlobalClsList args
    Locally -> updateLocalClsList args
    AtLevel k -> updateAtLevelClsList k args

updateClsList2 :: LocalGlobalFlag -> [[Text]] -> Parser ()
updateClsList2 b argss =
  case b of
    Globally -> updateGlobalClsList2 argss
    Locally -> updateLocalClsList2 argss
    AtLevel k -> updateAtLevelClsList2 k argss

updateGlobalStrSyms :: [Text] -> Parser ()
updateGlobalStrSyms txts = updateGlobal $ strSyms %~ (:) txts

updateGlobalStrSyms2 :: [[Text]] -> Parser ()
updateGlobalStrSyms2 txtss = updateGlobal $ strSyms %~ (<>) txtss

updateLocalStrSyms :: [Text] -> Parser ()
updateLocalStrSyms txts = updateLocal $ strSyms %~ (:) txts

updateAtLevelStrSyms :: Int -> [Text] -> Parser ()
updateAtLevelStrSyms k txts = updateAtLevel k $ strSyms %~ (:) txts

updateLocalStrSyms2 :: [[Text]] -> Parser ()
updateLocalStrSyms2 txts = updateLocal $ strSyms %~ (<>) txts

updateAtLevelStrSyms2 :: Int -> [[Text]] -> Parser ()
updateAtLevelStrSyms2 k txts = updateAtLevel k $ strSyms %~ (<>) txts

updateStrSyms :: LocalGlobalFlag -> [Text] -> Parser ()
updateStrSyms b args =
  case b of
    Globally -> updateGlobalStrSyms args
    Locally -> updateLocalStrSyms args
    AtLevel k -> updateAtLevelStrSyms k args

updateStrSyms2 :: LocalGlobalFlag -> [[Text]] -> Parser ()
updateStrSyms2 b argss =
  case b of
    Globally -> updateGlobalStrSyms2 argss
    Locally -> updateLocalStrSyms2 argss
    AtLevel k -> updateAtLevelStrSyms2 k argss  

updateGlobalPrimDefiniteNoun :: Pattern -> Parser ()
updateGlobalPrimDefiniteNoun txts = updateGlobal $ primDefiniteNoun %~ (:) txts

updateGlobalPrimDefiniteNoun2 :: [Pattern] -> Parser ()
updateGlobalPrimDefiniteNoun2 txtss = updateGlobal $ primDefiniteNoun %~ (<>) txtss

updateLocalPrimDefiniteNoun :: Pattern -> Parser ()
updateLocalPrimDefiniteNoun txts = updateLocal $ primDefiniteNoun %~ (:) txts

updateAtLevelPrimDefiniteNoun :: Int -> Pattern -> Parser ()
updateAtLevelPrimDefiniteNoun k txts = updateAtLevel k $ primDefiniteNoun %~ (:) txts

updateLocalPrimDefiniteNoun2 :: [Pattern] -> Parser ()
updateLocalPrimDefiniteNoun2 txts = updateLocal $ primDefiniteNoun %~ (<>) txts

updateAtLevelPrimDefiniteNoun2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimDefiniteNoun2 k txts = updateAtLevel k $ primDefiniteNoun %~ (<>) txts

updatePrimDefiniteNoun :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimDefiniteNoun b args =
  case b of
    Globally -> updateGlobalPrimDefiniteNoun args
    Locally -> updateLocalPrimDefiniteNoun args
    AtLevel k -> updateAtLevelPrimDefiniteNoun k args

updatePrimDefiniteNoun2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimDefiniteNoun2 b argss =
  case b of
    Globally -> updateGlobalPrimDefiniteNoun2 argss
    Locally -> updateLocalPrimDefiniteNoun2 argss
    AtLevel k -> updateAtLevelPrimDefiniteNoun2 k argss  

updateGlobalPrimIdentifierTerm :: Pattern -> Parser ()
updateGlobalPrimIdentifierTerm txts = updateGlobal $ primIdentifierTerm %~ (:) txts

updateGlobalPrimIdentifierTerm2 :: [Pattern] -> Parser ()
updateGlobalPrimIdentifierTerm2 txtss = updateGlobal $ primIdentifierTerm %~ (<>) txtss

updateLocalPrimIdentifierTerm :: Pattern -> Parser ()
updateLocalPrimIdentifierTerm txts = updateLocal $ primIdentifierTerm %~ (:) txts

updateAtLevelPrimIdentifierTerm :: Int -> Pattern -> Parser ()
updateAtLevelPrimIdentifierTerm k txts = updateAtLevel k $ primIdentifierTerm %~ (:) txts

updateLocalPrimIdentifierTerm2 :: [Pattern] -> Parser ()
updateLocalPrimIdentifierTerm2 txts = updateLocal $ primIdentifierTerm %~ (<>) txts

updateAtLevelPrimIdentifierTerm2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimIdentifierTerm2 k txts = updateAtLevel k $ primIdentifierTerm %~ (<>) txts

updatePrimIdentifierTerm :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimIdentifierTerm b args =
  case b of
    Globally -> updateGlobalPrimIdentifierTerm args
    Locally -> updateLocalPrimIdentifierTerm args
    AtLevel k -> updateAtLevelPrimIdentifierTerm k args

updatePrimIdentifierTerm2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimIdentifierTerm2 b argss =
  case b of
    Globally -> updateGlobalPrimIdentifierTerm2 argss
    Locally -> updateLocalPrimIdentifierTerm2 argss
    AtLevel k -> updateAtLevelPrimIdentifierTerm2 k argss  

updateGlobalPrimTermControlSeq :: Pattern -> Parser ()
updateGlobalPrimTermControlSeq txts = updateGlobal $ primTermControlSeq %~ (:) txts

updateGlobalPrimTermControlSeq2 :: [Pattern] -> Parser ()
updateGlobalPrimTermControlSeq2 txtss = updateGlobal $ primTermControlSeq %~ (<>) txtss

updateLocalPrimTermControlSeq :: Pattern -> Parser ()
updateLocalPrimTermControlSeq txts = updateLocal $ primTermControlSeq %~ (:) txts

updateAtLevelPrimTermControlSeq :: Int -> Pattern -> Parser ()
updateAtLevelPrimTermControlSeq k txts = updateAtLevel k $ primTermControlSeq %~ (:) txts

updateLocalPrimTermControlSeq2 :: [Pattern] -> Parser ()
updateLocalPrimTermControlSeq2 txts = updateLocal $ primTermControlSeq %~ (<>) txts

updateAtLevelPrimTermControlSeq2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimTermControlSeq2 k txts = updateAtLevel k $ primTermControlSeq %~ (<>) txts

updatePrimTermControlSeq :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimTermControlSeq b args =
  case b of
    Globally -> updateGlobalPrimTermControlSeq args
    Locally -> updateLocalPrimTermControlSeq args
    AtLevel k -> updateAtLevelPrimTermControlSeq k args

updatePrimTermControlSeq2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimTermControlSeq2 b argss =
  case b of
    Globally -> updateGlobalPrimTermControlSeq2 argss
    Locally -> updateLocalPrimTermControlSeq2 argss
    AtLevel k -> updateAtLevelPrimTermControlSeq2 k argss  

updateGlobalPrimTermOpControlSeq :: Pattern -> Parser ()
updateGlobalPrimTermOpControlSeq txts = updateGlobal $ primTermOpControlSeq %~ (:) txts

updateGlobalPrimTermOpControlSeq2 :: [Pattern] -> Parser ()
updateGlobalPrimTermOpControlSeq2 txtss = updateGlobal $ primTermOpControlSeq %~ (<>) txtss

updateLocalPrimTermOpControlSeq :: Pattern -> Parser ()
updateLocalPrimTermOpControlSeq txts = updateLocal $ primTermOpControlSeq %~ (:) txts

updateAtLevelPrimTermOpControlSeq :: Int -> Pattern -> Parser ()
updateAtLevelPrimTermOpControlSeq k txts = updateAtLevel k $ primTermOpControlSeq %~ (:) txts

updateLocalPrimTermOpControlSeq2 :: [Pattern] -> Parser ()
updateLocalPrimTermOpControlSeq2 txts = updateLocal $ primTermOpControlSeq %~ (<>) txts

updateAtLevelPrimTermOpControlSeq2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimTermOpControlSeq2 k txts = updateAtLevel k $ primTermOpControlSeq %~ (<>) txts

updatePrimTermOpControlSeq :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimTermOpControlSeq b args =
  case b of
    Globally -> updateGlobalPrimTermOpControlSeq args
    Locally -> updateLocalPrimTermOpControlSeq args
    AtLevel k -> updateAtLevelPrimTermOpControlSeq k args

updatePrimTermOpControlSeq2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimTermOpControlSeq2 b argss =
  case b of
    Globally -> updateGlobalPrimTermOpControlSeq2 argss
    Locally -> updateLocalPrimTermOpControlSeq2 argss
    AtLevel k -> updateAtLevelPrimTermOpControlSeq2 k argss  

-- updateGlobalPrimPrefixFunction :: Pattern -> Parser ()
-- updGlobalatePrimPrefixFunction txts = updateLocal $ primPrefixFunction %= (:) txts
-- updateGlobalPrimPrefixFunction2 :: [Pattern] -> Parser ()
-- updGlobalatePrimPrefixFunction2 txtss = updateGlobal $ primPrefixFunction %= (<>) txtss

-- updateLocalPrimPrefixFunction :: Pattern -> Parser ()
-- updateLocalPrimPrefixFunction txts = updateLocal $ primPrefixFunction %~ (:) txts

-- updateGlobalPrimPrefixFunction2 :: [Pattern] -> Parser ()
-- updGlobalatePrimPrefixFunction2 txts = updateLocal $ primPrefixFunction %= (<>) txts
-- updateGlobalPrimPrefixFunction22 :: [Pattern] -> [Parser ()
-- updGlobalatePrimPrefixFunction22 txtss = updateGlobal $ primPrefixFunction %= (<>) txtss

-- updateLocalPrimPrefixFunction <>: Pattern] -> Parser ()
-- updateLocalPrimPrefixFunction txts = updateLocal $ primPrefixFunction %~ (:) txts

updateGlobalPrimAdjective :: Pattern -> Parser ()
updateGlobalPrimAdjective txts = updateGlobal $ primAdjective %~ (:) txts

updateGlobalPrimAdjective2 :: [Pattern] -> Parser ()
updateGlobalPrimAdjective2 txtss = updateGlobal $ primAdjective %~ (<>) txtss

updateLocalPrimAdjective :: Pattern -> Parser ()
updateLocalPrimAdjective txts = updateLocal $ primAdjective %~ (:) txts

updateAtLevelPrimAdjective :: Int -> Pattern -> Parser ()
updateAtLevelPrimAdjective k txts = updateAtLevel k $ primAdjective %~ (:) txts

updateLocalPrimAdjective2 :: [Pattern] -> Parser ()
updateLocalPrimAdjective2 txts = updateLocal $ primAdjective %~ (<>) txts

updateAtLevelPrimAdjective2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimAdjective2 k txts = updateAtLevel k $ primAdjective %~ (<>) txts

updatePrimAdjective :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimAdjective b args =
  case b of
    Globally -> updateGlobalPrimAdjective args
    Locally -> updateLocalPrimAdjective args
    AtLevel k -> updateAtLevelPrimAdjective k args

updatePrimAdjective2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimAdjective2 b argss =
  case b of
    Globally -> updateGlobalPrimAdjective2 argss
    Locally -> updateLocalPrimAdjective2 argss
    AtLevel k -> updateAtLevelPrimAdjective2 k argss  

updateGlobalPrimAdjectiveMultiSubject :: Pattern -> Parser ()
updateGlobalPrimAdjectiveMultiSubject txts = updateGlobal $ primAdjectiveMultiSubject %~ (:) txts

updateGlobalPrimAdjectiveMultiSubject2 :: [Pattern] -> Parser ()
updateGlobalPrimAdjectiveMultiSubject2 txtss = updateGlobal $ primAdjectiveMultiSubject %~ (<>) txtss

updateLocalPrimAdjectiveMultiSubject :: Pattern -> Parser ()
updateLocalPrimAdjectiveMultiSubject txts = updateLocal $ primAdjectiveMultiSubject %~ (:) txts

updateAtLevelPrimAdjectiveMultiSubject :: Int -> Pattern -> Parser ()
updateAtLevelPrimAdjectiveMultiSubject k txts = updateAtLevel k $ primAdjectiveMultiSubject %~ (:) txts

updateLocalPrimAdjectiveMultiSubject2 :: [Pattern] -> Parser ()
updateLocalPrimAdjectiveMultiSubject2 txts = updateLocal $ primAdjectiveMultiSubject %~ (<>) txts

updateAtLevelPrimAdjectiveMultiSubject2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimAdjectiveMultiSubject2 k txts = updateAtLevel k $ primAdjectiveMultiSubject %~ (<>) txts

updatePrimAdjectiveMultiSubject :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimAdjectiveMultiSubject b args =
  case b of
    Globally -> updateGlobalPrimAdjectiveMultiSubject args
    Locally -> updateLocalPrimAdjectiveMultiSubject args
    AtLevel k -> updateAtLevelPrimAdjectiveMultiSubject k args

updatePrimAdjectiveMultiSubject2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimAdjectiveMultiSubject2 b argss =
  case b of
    Globally -> updateGlobalPrimAdjectiveMultiSubject2 argss
    Locally -> updateLocalPrimAdjectiveMultiSubject2 argss
    AtLevel k -> updateAtLevelPrimAdjectiveMultiSubject2 k argss  

updateGlobalPrimVerb :: Pattern -> Parser ()
updateGlobalPrimVerb txts = updateGlobal $ primVerb %~ (:) txts

updateGlobalPrimVerb2 :: [Pattern] -> Parser ()
updateGlobalPrimVerb2 txtss = updateGlobal $ primVerb %~ (<>) txtss

updateLocalPrimVerb :: Pattern -> Parser ()
updateLocalPrimVerb txts = updateLocal $ primVerb %~ (:) txts

updateAtLevelPrimVerb :: Int -> Pattern -> Parser ()
updateAtLevelPrimVerb k txts = updateAtLevel k $ primVerb %~ (:) txts

updateLocalPrimVerb2 :: [Pattern] -> Parser ()
updateLocalPrimVerb2 txts = updateLocal $ primVerb %~ (<>) txts

updateAtLevelPrimVerb2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimVerb2 k txts = updateAtLevel k $ primVerb %~ (<>) txts

updatePrimVerb :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimVerb b args =
  case b of
    Globally -> updateGlobalPrimVerb args
    Locally -> updateLocalPrimVerb args
    AtLevel k -> updateAtLevelPrimVerb k args

updatePrimVerb2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimVerb2 b argss =
  case b of
    Globally -> updateGlobalPrimVerb2 argss
    Locally -> updateLocalPrimVerb2 argss
    AtLevel k -> updateAtLevelPrimVerb2 k argss  

updateGlobalPrimVerbMultiSubject :: Pattern -> Parser ()
updateGlobalPrimVerbMultiSubject txts = updateGlobal $ primVerbMultiSubject %~ (:) txts

updateGlobalPrimVerbMultiSubject2 :: [Pattern] -> Parser ()
updateGlobalPrimVerbMultiSubject2 txtss = updateGlobal $ primVerbMultiSubject %~ (<>) txtss

updateLocalPrimVerbMultiSubject :: Pattern -> Parser ()
updateLocalPrimVerbMultiSubject txts = updateLocal $ primVerbMultiSubject %~ (:) txts

updateAtLevelPrimVerbMultiSubject :: Int -> Pattern -> Parser ()
updateAtLevelPrimVerbMultiSubject k txts = updateAtLevel k $ primVerbMultiSubject %~ (:) txts

updateLocalPrimVerbMultiSubject2 :: [Pattern] -> Parser ()
updateLocalPrimVerbMultiSubject2 txts = updateLocal $ primVerbMultiSubject %~ (<>) txts

updateAtLevelPrimVerbMultiSubject2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimVerbMultiSubject2 k txts = updateAtLevel k $ primVerbMultiSubject %~ (<>) txts

updatePrimVerbMultiSubject :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimVerbMultiSubject b args =
  case b of
    Globally -> updateGlobalPrimVerbMultiSubject args
    Locally -> updateLocalPrimVerbMultiSubject args
    AtLevel k -> updateAtLevelPrimVerbMultiSubject k args

updatePrimVerbMultiSubject2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimVerbMultiSubject2 b argss =
  case b of
    Globally -> updateGlobalPrimVerbMultiSubject2 argss
    Locally -> updateLocalPrimVerbMultiSubject2 argss
    AtLevel k -> updateAtLevelPrimVerbMultiSubject2 k argss  

updateGlobalPrimRelation :: Pattern -> Parser ()
updateGlobalPrimRelation txts = updateGlobal $ primRelation %~ (:) txts

updateGlobalPrimRelation2 :: [Pattern] -> Parser ()
updateGlobalPrimRelation2 txtss = updateGlobal $ primRelation %~ (<>) txtss

updateLocalPrimRelation :: Pattern -> Parser ()
updateLocalPrimRelation txts = updateLocal $ primRelation %~ (:) txts

updateAtLevelPrimRelation :: Int -> Pattern -> Parser ()
updateAtLevelPrimRelation k txts = updateAtLevel k $ primRelation %~ (:) txts

updateLocalPrimRelation2 :: [Pattern] -> Parser ()
updateLocalPrimRelation2 txts = updateLocal $ primRelation %~ (<>) txts

updateAtLevelPrimRelation2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimRelation2 k txts = updateAtLevel k $ primRelation %~ (<>) txts

updatePrimRelation :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimRelation b args =
  case b of
    Globally -> updateGlobalPrimRelation args
    Locally -> updateLocalPrimRelation args
    AtLevel k -> updateAtLevelPrimRelation k args

updatePrimRelation2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimRelation2 b argss =
  case b of
    Globally -> updateGlobalPrimRelation2 argss
    Locally -> updateLocalPrimRelation2 argss
    AtLevel k -> updateAtLevelPrimRelation2 k argss  

updateGlobalPrimPropositionalOp :: Pattern -> Parser ()
updateGlobalPrimPropositionalOp txts = updateGlobal $ primPropositionalOp %~ (:) txts

updateGlobalPrimPropositionalOp2 :: [Pattern] -> Parser ()
updateGlobalPrimPropositionalOp2 txtss = updateGlobal $ primPropositionalOp %~ (<>) txtss

updateLocalPrimPropositionalOp :: Pattern -> Parser ()
updateLocalPrimPropositionalOp txts = updateLocal $ primPropositionalOp %~ (:) txts

updateAtLevelPrimPropositionalOp :: Int -> Pattern -> Parser ()
updateAtLevelPrimPropositionalOp k txts = updateAtLevel k $ primPropositionalOp %~ (:) txts

updateLocalPrimPropositionalOp2 :: [Pattern] -> Parser ()
updateLocalPrimPropositionalOp2 txts = updateLocal $ primPropositionalOp %~ (<>) txts

updateAtLevelPrimPropositionalOp2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimPropositionalOp2 k txts = updateAtLevel k $ primPropositionalOp %~ (<>) txts

updatePrimPropositionalOp :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimPropositionalOp b args =
  case b of
    Globally -> updateGlobalPrimPropositionalOp args
    Locally -> updateLocalPrimPropositionalOp args
    AtLevel k -> updateAtLevelPrimPropositionalOp k args

updatePrimPropositionalOp2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimPropositionalOp2 b argss =
  case b of
    Globally -> updateGlobalPrimPropositionalOp2 argss
    Locally -> updateLocalPrimPropositionalOp2 argss
    AtLevel k -> updateAtLevelPrimPropositionalOp2 k argss  

updateGlobalPrimBinaryRelationOp :: Pattern -> Parser ()
updateGlobalPrimBinaryRelationOp txts = updateGlobal $ primBinaryRelationOp %~ (:) txts

updateGlobalPrimBinaryRelationOp2 :: [Pattern] -> Parser ()
updateGlobalPrimBinaryRelationOp2 txtss = updateGlobal $ primBinaryRelationOp %~ (<>) txtss

updateLocalPrimBinaryRelationOp :: Pattern -> Parser ()
updateLocalPrimBinaryRelationOp txts = updateLocal $ primBinaryRelationOp %~ (:) txts

updateAtLevelPrimBinaryRelationOp :: Int -> Pattern -> Parser ()
updateAtLevelPrimBinaryRelationOp k txts = updateAtLevel k $ primBinaryRelationOp %~ (:) txts

updateLocalPrimBinaryRelationOp2 :: [Pattern] -> Parser ()
updateLocalPrimBinaryRelationOp2 txts = updateLocal $ primBinaryRelationOp %~ (<>) txts

updateAtLevelPrimBinaryRelationOp2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimBinaryRelationOp2 k txts = updateAtLevel k $ primBinaryRelationOp %~ (<>) txts

updatePrimBinaryRelationOp :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimBinaryRelationOp b args =
  case b of
    Globally -> updateGlobalPrimBinaryRelationOp args
    Locally -> updateLocalPrimBinaryRelationOp args
    AtLevel k -> updateAtLevelPrimBinaryRelationOp k args

updatePrimBinaryRelationOp2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimBinaryRelationOp2 b argss =
  case b of
    Globally -> updateGlobalPrimBinaryRelationOp2 argss
    Locally -> updateLocalPrimBinaryRelationOp2 argss
    AtLevel k -> updateAtLevelPrimBinaryRelationOp2 k argss  

updateGlobalPrimBinaryRelationControlSeq :: Pattern -> Parser ()
updateGlobalPrimBinaryRelationControlSeq txts = updateGlobal $ primBinaryRelationControlSeq %~ (:) txts

updateGlobalPrimBinaryRelationControlSeq2 :: [Pattern] -> Parser ()
updateGlobalPrimBinaryRelationControlSeq2 txtss = updateGlobal $ primBinaryRelationControlSeq %~ (<>) txtss

updateLocalPrimBinaryRelationControlSeq :: Pattern -> Parser ()
updateLocalPrimBinaryRelationControlSeq txts = updateLocal $ primBinaryRelationControlSeq %~ (:) txts

updateAtLevelPrimBinaryRelationControlSeq :: Int -> Pattern -> Parser ()
updateAtLevelPrimBinaryRelationControlSeq k txts = updateAtLevel k $ primBinaryRelationControlSeq %~ (:) txts

updateLocalPrimBinaryRelationControlSeq2 :: [Pattern] -> Parser ()
updateLocalPrimBinaryRelationControlSeq2 txts = updateLocal $ primBinaryRelationControlSeq %~ (<>) txts

updateAtLevelPrimBinaryRelationControlSeq2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimBinaryRelationControlSeq2 k txts = updateAtLevel k $ primBinaryRelationControlSeq %~ (<>) txts

updatePrimBinaryRelationControlSeq :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimBinaryRelationControlSeq b args =
  case b of
    Globally -> updateGlobalPrimBinaryRelationControlSeq args
    Locally -> updateLocalPrimBinaryRelationControlSeq args
    AtLevel k -> updateAtLevelPrimBinaryRelationControlSeq k args

updatePrimBinaryRelationControlSeq2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimBinaryRelationControlSeq2 b argss =
  case b of
    Globally -> updateGlobalPrimBinaryRelationControlSeq2 argss
    Locally -> updateLocalPrimBinaryRelationControlSeq2 argss
    AtLevel k -> updateAtLevelPrimBinaryRelationControlSeq2 k argss  

updateGlobalPrimPropositionalOpControlSeq :: Pattern -> Parser ()
updateGlobalPrimPropositionalOpControlSeq txts = updateGlobal $ primPropositionalOpControlSeq %~ (:) txts

updateGlobalPrimPropositionalOpControlSeq2 :: [Pattern] -> Parser ()
updateGlobalPrimPropositionalOpControlSeq2 txtss = updateGlobal $ primPropositionalOpControlSeq %~ (<>) txtss

updateLocalPrimPropositionalOpControlSeq :: Pattern -> Parser ()
updateLocalPrimPropositionalOpControlSeq txts = updateLocal $ primPropositionalOpControlSeq %~ (:) txts

updateAtLevelPrimPropositionalOpControlSeq :: Int -> Pattern -> Parser ()
updateAtLevelPrimPropositionalOpControlSeq k txts = updateAtLevel k $ primPropositionalOpControlSeq %~ (:) txts

updateLocalPrimPropositionalOpControlSeq2 :: [Pattern] -> Parser ()
updateLocalPrimPropositionalOpControlSeq2 txts = updateLocal $ primPropositionalOpControlSeq %~ (<>) txts

updateAtLevelPrimPropositionalOpControlSeq2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimPropositionalOpControlSeq2 k txts = updateAtLevel k $ primPropositionalOpControlSeq %~ (<>) txts

updatePrimPropositionalOpControlSeq :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimPropositionalOpControlSeq b args =
  case b of
    Globally -> updateGlobalPrimPropositionalOpControlSeq args
    Locally -> updateLocalPrimPropositionalOpControlSeq args
    AtLevel k -> updateAtLevelPrimPropositionalOpControlSeq k args

updatePrimPropositionalOpControlSeq2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimPropositionalOpControlSeq2 b argss =
  case b of
    Globally -> updateGlobalPrimPropositionalOpControlSeq2 argss
    Locally -> updateLocalPrimPropositionalOpControlSeq2 argss
    AtLevel k -> updateAtLevelPrimPropositionalOpControlSeq2 k argss  

updateGlobalPrimIdentifierType :: Pattern -> Parser ()
updateGlobalPrimIdentifierType txts = updateGlobal $ primPropositionalOpControlSeq %~ (:) txts

updateGlobalPrimIdentifierType2 :: [Pattern] -> Parser ()
updateGlobalPrimIdentifierType2 txtss = updateGlobal $ primPropositionalOpControlSeq %~ (<>) txtss

updateLocalPrimIdentifierType :: Pattern -> Parser ()
updateLocalPrimIdentifierType txts = updateLocal $ primPropositionalOpControlSeq %~ (:) txts

updateAtLevelPrimIdentifierType :: Int -> Pattern -> Parser ()
updateAtLevelPrimIdentifierType k txts = updateAtLevel k $ primIdentifierType %~ (:) txts

updateLocalPrimIdentifierType2 :: [Pattern] -> Parser ()
updateLocalPrimIdentifierType2 txts = updateLocal $ primPropositionalOpControlSeq %~ (<>) txts

updateAtLevelPrimIdentifierType2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimIdentifierType2 k txts = updateAtLevel k $ primIdentifierType %~ (<>) txts

updatePrimIdentifierType :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimIdentifierType b args =
  case b of
    Globally -> updateGlobalPrimIdentifierType args
    Locally -> updateLocalPrimIdentifierType args
    AtLevel k -> updateAtLevelPrimIdentifierType k args

updatePrimIdentifierType2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimIdentifierType2 b argss =
  case b of
    Globally -> updateGlobalPrimIdentifierType2 argss
    Locally -> updateLocalPrimIdentifierType2 argss
    AtLevel k -> updateAtLevelPrimIdentifierType2 k argss  

updateGlobalPrimTypeOp :: Pattern -> Parser ()
updateGlobalPrimTypeOp txts = updateGlobal $ primPropositionalOpControlSeq %~ (:) txts

updateGlobalPrimTypeOp2 :: [Pattern] -> Parser ()
updateGlobalPrimTypeOp2 txtss = updateGlobal $ primPropositionalOpControlSeq %~ (<>) txtss

updateLocalPrimTypeOp :: Pattern -> Parser ()
updateLocalPrimTypeOp txts = updateLocal $ primPropositionalOpControlSeq %~ (:) txts

updateAtLevelPrimTypeOp :: Int -> Pattern -> Parser ()
updateAtLevelPrimTypeOp k txts = updateAtLevel k $ primTypeOp %~ (:) txts

updateLocalPrimTypeOp2 :: [Pattern] -> Parser ()
updateLocalPrimTypeOp2 txts = updateLocal $ primPropositionalOpControlSeq %~ (<>) txts

updateAtLevelPrimTypeOp2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimTypeOp2 k txts = updateAtLevel k $ primTypeOp %~ (<>) txts

updatePrimTypeOp :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimTypeOp b args =
  case b of
    Globally -> updateGlobalPrimTypeOp args
    Locally -> updateLocalPrimTypeOp args
    AtLevel k -> updateAtLevelPrimTypeOp k args

updatePrimTypeOp2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimTypeOp2 b argss =
  case b of
    Globally -> updateGlobalPrimTypeOp2 argss
    Locally -> updateLocalPrimTypeOp2 argss
    AtLevel k -> updateAtLevelPrimTypeOp2 k argss  

updateGlobalPrimTypeOpControlSeq :: Pattern -> Parser ()
updateGlobalPrimTypeOpControlSeq txts = updateGlobal $ primPropositionalOpControlSeq %~ (:) txts

updateGlobalPrimTypeOpControlSeq2 :: [Pattern] -> Parser ()
updateGlobalPrimTypeOpControlSeq2 txtss = updateGlobal $ primPropositionalOpControlSeq %~ (<>) txtss

updateLocalPrimTypeOpControlSeq :: Pattern -> Parser ()
updateLocalPrimTypeOpControlSeq txts = updateLocal $ primPropositionalOpControlSeq %~ (:) txts

updateAtLevelPrimTypeOpControlSeq :: Int -> Pattern -> Parser ()
updateAtLevelPrimTypeOpControlSeq k txts = updateAtLevel k $ primTypeOpControlSeq %~ (:) txts

updateLocalPrimTypeOpControlSeq2 :: [Pattern] -> Parser ()
updateLocalPrimTypeOpControlSeq2 txts = updateLocal $ primPropositionalOpControlSeq %~ (<>) txts

updateAtLevelPrimTypeOpControlSeq2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimTypeOpControlSeq2 k txts = updateAtLevel k $ primTypeOpControlSeq %~ (<>) txts

updatePrimTypeOpControlSeq :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimTypeOpControlSeq b args =
  case b of
    Globally -> updateGlobalPrimTypeOpControlSeq args
    Locally -> updateLocalPrimTypeOpControlSeq args
    AtLevel k -> updateAtLevelPrimTypeOpControlSeq k args

updatePrimTypeOpControlSeq2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimTypeOpControlSeq2 b argss =
  case b of
    Globally -> updateGlobalPrimTypeOpControlSeq2 argss
    Locally -> updateLocalPrimTypeOpControlSeq2 argss
    AtLevel k -> updateAtLevelPrimTypeOpControlSeq2 k argss  

updateGlobalPrimTypeControlSeq :: Pattern -> Parser ()
updateGlobalPrimTypeControlSeq txts = updateGlobal $ primPropositionalOpControlSeq %~ (:) txts

updateGlobalPrimTypeControlSeq2 :: [Pattern] -> Parser ()
updateGlobalPrimTypeControlSeq2 txtss = updateGlobal $ primPropositionalOpControlSeq %~ (<>) txtss

updateLocalPrimTypeControlSeq :: Pattern -> Parser ()
updateLocalPrimTypeControlSeq txts = updateLocal $ primPropositionalOpControlSeq %~ (:) txts

updateAtLevelPrimTypeControlSeq :: Int -> Pattern -> Parser ()
updateAtLevelPrimTypeControlSeq k txts = updateAtLevel k $ primTypeControlSeq %~ (:) txts

updateLocalPrimTypeControlSeq2 :: [Pattern] -> Parser ()
updateLocalPrimTypeControlSeq2 txts = updateLocal $ primPropositionalOpControlSeq %~ (<>) txts

updateAtLevelPrimTypeControlSeq2 :: Int -> [Pattern] -> Parser ()
updateAtLevelPrimTypeControlSeq2 k txts = updateAtLevel k $ primTypeControlSeq %~ (<>) txts

updatePrimTypeControlSeq :: LocalGlobalFlag -> Pattern -> Parser ()
updatePrimTypeControlSeq b args =
  case b of
    Globally -> updateGlobalPrimTypeControlSeq args
    Locally -> updateLocalPrimTypeControlSeq args
    AtLevel k -> updateAtLevelPrimTypeControlSeq k args

updatePrimTypeControlSeq2 :: LocalGlobalFlag -> [Pattern] -> Parser ()
updatePrimTypeControlSeq2 b argss =
  case b of
    Globally -> updateGlobalPrimTypeControlSeq2 argss
    Locally -> updateLocalPrimTypeControlSeq2 argss
    AtLevel k -> updateAtLevelPrimTypeControlSeq2 k argss  

updateGlobalIdCount :: Int -> Parser ()
updateGlobalIdCount k = updateGlobal $ idCount %~ (const k)

allStates :: Getter FState a -> Getter (Stack FState) [a]
allStates g = to $ \stk -> stk^..(top . g) <> (stk^..(rest . traverse . g))

---- returns the current document level of the parser
parserDocumentLevel :: Parser Int
parserDocumentLevel = depthStack <$> get

tokenToText'_aux :: [[Text]] -> Token -> [Text]
tokenToText'_aux strsyms tk = case tk of
  Token txt -> case (filter (elem txt) strsyms) of
    [] -> [txt]
    (x:xs) -> ((<>) x $ concat xs)

-- tokenToText' extracts the underlying Text of a token and adds all available synonyms from the state.
tokenToText' :: Token -> Parser [Text]
tokenToText' tk = tokenToText'_aux <$> (concat <$> (use (allStates strSyms))) <*> return tk

