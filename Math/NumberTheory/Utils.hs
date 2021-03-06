-- |
-- Module:      Math.NumberTheory.Utils
-- Copyright:   (c) 2011 Daniel Fischer
-- Licence:     MIT
-- Maintainer:  Daniel Fischer <daniel.is.fischer@googlemail.com>
-- Stability:   Provisional
-- Portability: Non-portable (GHC extensions)
--
-- Some utilities for bit twiddling.
--
{-# LANGUAGE CPP, MagicHash, UnboxedTuples, BangPatterns #-}
{-# OPTIONS_HADDOCK hide #-}
module Math.NumberTheory.Utils
    ( shiftToOddCount
    , shiftToOdd
    , shiftToOdd#
    , shiftToOddCount#
    , bitCountWord
    , bitCountInt
    , bitCountWord#
    , uncheckedShiftR
    , splitOff
    , splitOff#
    ) where

#include "MachDeps.h"

import GHC.Base

import GHC.Integer
import GHC.Integer.GMP.Internals
import GHC.Natural

import Data.Bits

uncheckedShiftR :: Word -> Int -> Word
uncheckedShiftR (W# w#) (I# i#) = W# (uncheckedShiftRL# w# i#)

-- | Remove factors of @2@ and count them. If
--   @n = 2^k*m@ with @m@ odd, the result is @(k, m)@.
--   Precondition: argument not @0@ (not checked).
{-# RULES
"shiftToOddCount/Int"       shiftToOddCount = shiftOCInt
"shiftToOddCount/Word"      shiftToOddCount = shiftOCWord
"shiftToOddCount/Integer"   shiftToOddCount = shiftOCInteger
"shiftToOddCount/Natural"   shiftToOddCount = shiftOCNatural
  #-}
{-# INLINE [1] shiftToOddCount #-}
shiftToOddCount :: Integral a => a -> (Int, a)
shiftToOddCount n = case shiftOCInteger (fromIntegral n) of
                      (z, o) -> (z, fromInteger o)

-- | Specialised version for @'Word'@.
--   Precondition: argument strictly positive (not checked).
shiftOCWord :: Word -> (Int, Word)
shiftOCWord (W# w#) = case shiftToOddCount# w# of
                        (# z# , u# #) -> (I# z#, W# u#)

-- | Specialised version for @'Int'@.
--   Precondition: argument nonzero (not checked).
shiftOCInt :: Int -> (Int, Int)
shiftOCInt (I# i#) = case shiftToOddCount# (int2Word# i#) of
                        (# z#, u# #) -> (I# z#, I# (word2Int# u#))

-- | Specialised version for @'Integer'@.
--   Precondition: argument nonzero (not checked).
shiftOCInteger :: Integer -> (Int, Integer)
shiftOCInteger n@(S# i#) =
    case shiftToOddCount# (int2Word# i#) of
      (# z#, w# #)
        | isTrue# (z# ==# 0#) -> (0, n)
        | otherwise -> (I# z#, S# (word2Int# w#))
shiftOCInteger n@(Jp# bn#) = case bigNatZeroCount bn# of
                                 0#  -> (0, n)
                                 z#  -> (I# z#, n `shiftRInteger` z#)
shiftOCInteger n@(Jn# bn#) = case bigNatZeroCount bn# of
                                 0#  -> (0, n)
                                 z#  -> (I# z#, n `shiftRInteger` z#)

-- | Specialised version for @'Natural'@.
--   Precondition: argument nonzero (not checked).
shiftOCNatural :: Natural -> (Int, Natural)
shiftOCNatural n@(NatS# i#) =
    case shiftToOddCount# i# of
      (# z#, w# #)
        | isTrue# (z# ==# 0#) -> (0, n)
        | otherwise -> (I# z#, NatS# w#)
shiftOCNatural n@(NatJ# bn#) = case bigNatZeroCount bn# of
                                 0#  -> (0, n)
                                 z#  -> (I# z#, NatJ# (bn# `shiftRBigNat` z#))

-- | Count trailing zeros in a @'BigNat'@.
--   Precondition: argument nonzero (not checked, Integer invariant).
bigNatZeroCount :: BigNat -> Int#
bigNatZeroCount bn# = count 0# 0#
  where
    count a# i# =
          case indexBigNat# bn# i# of
            0## -> count (a# +# WORD_SIZE_IN_BITS#) (i# +# 1#)
            w#  -> a# +# word2Int# (ctz# w#)

-- | Remove factors of @2@. If @n = 2^k*m@ with @m@ odd, the result is @m@.
--   Precondition: argument not @0@ (not checked).
{-# RULES
"shiftToOdd/Int"       shiftToOdd = shiftOInt
"shiftToOdd/Word"      shiftToOdd = shiftOWord
"shiftToOdd/Integer"   shiftToOdd = shiftOInteger
  #-}
{-# INLINE [1] shiftToOdd #-}
shiftToOdd :: Integral a => a -> a
shiftToOdd n = fromInteger (shiftOInteger (fromIntegral n))

-- | Specialised version for @'Int'@.
--   Precondition: argument nonzero (not checked).
shiftOInt :: Int -> Int
shiftOInt (I# i#) = I# (word2Int# (shiftToOdd# (int2Word# i#)))

-- | Specialised version for @'Word'@.
--   Precondition: argument nonzero (not checked).
shiftOWord :: Word -> Word
shiftOWord (W# w#) = W# (shiftToOdd# w#)

-- | Specialised version for @'Int'@.
--   Precondition: argument nonzero (not checked).
shiftOInteger :: Integer -> Integer
shiftOInteger (S# i#) = S# (word2Int# (shiftToOdd# (int2Word# i#)))
shiftOInteger n@(Jn# bn#) = case bigNatZeroCount bn# of
                                 0#  -> n
                                 z#  -> n `shiftRInteger` z#
shiftOInteger n@(Jp# bn#) = case bigNatZeroCount bn# of
                                 0#  -> n
                                 z#  -> n `shiftRInteger` z#

-- | Shift argument right until the result is odd.
--   Precondition: argument not @0@, not checked.
shiftToOdd# :: Word# -> Word#
shiftToOdd# w# = uncheckedShiftRL# w# (word2Int# (ctz# w#))

-- | Like @'shiftToOdd#'@, but count the number of places to shift too.
shiftToOddCount# :: Word# -> (# Int#, Word# #)
shiftToOddCount# w# = case word2Int# (ctz# w#) of
                        k# -> (# k#, uncheckedShiftRL# w# k# #)

-- | Number of 1-bits in a @'Word#'@.
bitCountWord# :: Word# -> Int#
bitCountWord# w# = case bitCountWord (W# w#) of
                     I# i# -> i#

-- | Number of 1-bits in a @'Word'@.
bitCountWord :: Word -> Int
bitCountWord = popCount

-- | Number of 1-bits in an @'Int'@.
bitCountInt :: Int -> Int
bitCountInt = popCount

splitOff :: Integer -> Integer -> (Int, Integer)
splitOff _ 0 = (0, 0) -- prevent infinite loop
splitOff p n = go 0 n
  where
    go !k m = case m `quotRem` p of
      (q, 0) -> go (k + 1) q
      _      -> (k, m)
{-# INLINABLE splitOff #-}

-- | It is difficult to convince GHC to unbox output of 'splitOff' and 'splitOff.go',
-- so we fallback to a specialized unboxed version to minimize allocations.
splitOff# :: Word# -> Word# -> (# Int#, Word# #)
splitOff# _ 0## = (# 0#, 0## #)
splitOff# p n = go 0# n
  where
    go k m = case m `quotRemWord#` p of
      (# q, 0## #) -> go (k +# 1#) q
      _            -> (# k, m #)
{-# INLINABLE splitOff# #-}
