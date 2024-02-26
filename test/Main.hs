module Main (main) where

import System.Exit (exitFailure, exitSuccess)
import qualified Test.HUnit as U

import qualified Bindings.HTTPRedirect
import qualified Metadata.Metadata
import qualified XML.Canonical
import qualified XML.Encryption
import qualified XML.Signature

tests :: U.Test
tests =
    U.test
        [ U.TestLabel "XML.Canonical" XML.Canonical.tests
        , U.TestLabel "XML.Signature" XML.Signature.tests
        , U.TestLabel "XML.Encryption" XML.Encryption.tests
        , U.TestLabel "Bindings.HTTPRedirect" Bindings.HTTPRedirect.tests
        , U.TestLabel "Metadata.Metadata" Metadata.Metadata.tests
        ]

main :: IO ()
main = do
    r <- U.runTestTT tests
    if U.errors r == 0 && U.failures r == 0
        then exitSuccess
        else exitFailure
