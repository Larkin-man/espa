module Data.Tes3.Disassembler.Native where

#include <haskell>
import Data.Tes3
import Data.Tes3.Get

escapeChar :: Char -> String
escapeChar c
  | c /= '\t' && (ord c < 32 || ord c == 255) = reverse $ drop 1 $ reverse $ drop 1 $ show c
  | otherwise = [c]

escapeString :: String -> String
escapeString = concat . map escapeChar

trimNulls :: String -> String
trimNulls s = reverse $ dropWhile (== '\0') $ reverse s

trimNull :: String -> String
trimNull s =
  reverse $ check_null $ reverse $ replace "%" "%%" s
  where
    check_null ('\0' : t) = t
    check_null t = '%' : t

writeFixedS :: S.ByteString -> String
writeFixedS = escapeString . trimNulls . t3StringNew . B.fromStrict

writeFixedMultilineS :: S.ByteString -> String
writeFixedMultilineS = intercalate "\n" . map (("    " ++) . escapeString) . splitOn "\r\n" . trimNulls . t3StringNew . B.fromStrict

writeNulledS :: S.ByteString -> String
writeNulledS = escapeString . trimNull . t3StringNew . B.fromStrict

writeT3Header :: T3Header -> String
writeT3Header (T3Header version file_type author description items_count refs)
  =  "VERSION " ++ show version ++ "\n"
  ++ "TYPE " ++ show file_type ++ "\n"
  ++ "AUTHOR " ++ writeFixedS author ++ "\n"
  ++ "DESCRIPTION\n" ++ writeFixedMultilineS description ++ "\n"
  ++ "REFS " ++ show (length refs) ++ "\n"
  ++ concat [writeNulledS n ++ " " ++ show z ++ "\n" | (T3FileRef n z) <- refs]
  ++ "\nITEMS " ++ show items_count ++ "\n"

writeT3Field :: T3Field -> String
writeT3Field (T3BinaryField sign d) = show sign ++ " " ++ C.unpack (encode d) ++ "\n"
writeT3Field (T3StringField sign s) = show sign ++ " " ++ (escapeString $ trimNull s) ++ "\n"
writeT3Field (T3MultilineField sign t) = show sign ++ "\n" ++ (intercalate "\n" $ map (("    " ++) . escapeString) t) ++ "\n"

writeT3Record :: T3Record -> String
writeT3Record (T3Record sign fields)
  =  "\n" ++ show sign ++ " " ++ show (length fields) ++ "\n"
  ++ concat [writeT3Field f | f <- fields]

writeT3File :: T3File -> String
writeT3File (T3File header records)
  =  "3SET\n"
  ++ writeT3Header header
  ++ concat [writeT3Record r | r <- records]

disassembly :: ByteString -> Either String String
disassembly b = do
  f <- runGetT3File b
  return $ writeT3File f
