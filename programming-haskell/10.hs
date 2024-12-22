import Control.Monad (replicateM)
import Data.Char
import System.IO

-- 10.4

act :: IO (Char, Char)
act = do
  x <- getChar
  getChar
  y <- getChar
  return (x, y)

-- 10.5

getLine' :: IO String
getLine' = do
  x <- getChar
  if x == '\n'
    then
      return []
    else do
      xs <- getLine'
      return (x : xs)

putStr' :: String -> IO ()
putStr' [] = return ()
putStr' (x : xs) = do
  putChar x
  putStr' xs

putStrLn' :: String -> IO ()
putStrLn' xs = do
  putStr' xs
  putChar '\n'

strlen :: IO ()
strlen = do
  putStr' "Enter a string: "
  xs <- getLine
  putStr "The string has "
  putStr (show (length xs))
  putStrLn " characters"

-- 10.6

hangman :: IO ()
hangman = do
  putStrLn "Think of a word:"
  word <- sgetLine
  putStrLn "Try to guess it:"
  play word

sgetLine :: IO String
sgetLine = do
  x <- getCh
  if x == '\n'
    then do
      putChar x
      return []
    else do
      putChar '-'
      xs <- sgetLine
      return (x : xs)

getCh :: IO Char
getCh = do
  hSetEcho stdin False
  x <- getChar
  hSetEcho stdin True
  return x

play :: String -> IO ()
play word = do
  putStr "? "
  guess <- getLine
  if guess == word
    then
      putStrLn "You got it!!"
    else do
      putStrLn (match word guess)
      play word

match :: String -> String -> String
match xs ys = [if elem x ys then x else '-' | x <- xs]

-- 10.7

next :: Int -> Int
next 1 = 2
next 2 = 1

type Board = [Int]

initial :: Board
initial = [5, 4, 3, 2, 1]

finished :: Board -> Bool
finished = all (== 0)

valid :: Board -> Int -> Int -> Bool
valid board row num = board !! (row - 1) >= num

move :: Board -> Int -> Int -> Board
move board row num = [update r n | (r, n) <- zip [1 ..] board]
  where
    update r n = if r == row then n - num else n

putRow :: Int -> Int -> IO ()
putRow row num = do
  putStr (show row)
  putStr ": "
  putStrLn (concat (replicate num "* "))

putBoard :: Board -> IO ()
putBoard [a, b, c, d, e] = do
  putRow 1 a
  putRow 2 b
  putRow 3 c
  putRow 4 d
  putRow 5 e

getDigit :: String -> IO Int
getDigit prompt = do
  putStr prompt
  x <- getChar
  newline
  if isDigit x
    then
      return (digitToInt x)
    else do
      putStrLn "ERROR: Invalid digit"
      getDigit prompt

newline :: IO ()
newline = putChar '\n'

play' :: Board -> Int -> IO ()
play' board player =
  do
    newline
    putBoard board
    if finished board
      then do
        newline
        putStr "Player "
        putStr (show (next player))
        putStrLn " wins!!"
      else do
        newline
        putStr "Player "
        putStrLn (show player)
        row <- getDigit "Enter a row number: "
        num <- getDigit "Stars to remove : "
        if valid board row num
          then
            play' (move board row num) (next player)
          else do
            newline
            putStrLn "ERROR: Invalid move"
            play' board player

nim :: IO ()
nim = play' initial 1

-- 10.8
cls :: IO ()
cls = putStr "\ESC[2J"

type Pos = (Int, Int)

writeat :: Pos -> String -> IO ()
writeat p xs =
  do
    goto p
    putStr xs

goto :: Pos -> IO ()
goto (x, y) = putStr ("\ESC[" ++ show y ++ ";" ++ show x ++ "H")

width :: Int
width = 100

height :: Int
height = 100

type Board' = [Pos]

glider :: Board'
glider = [(4, 2), (2, 3), (4, 3), (3, 4), (4, 4)]

showcells :: Board' -> IO ()
showcells b = sequence_ [writeat p "O" | p <- b]

isAlive :: Board' -> Pos -> Bool
isAlive b p = elem p b

isEmpty :: Board' -> Pos -> Bool
isEmpty b p = not (isAlive b p)

neighbs :: Pos -> [Pos]
neighbs (x, y) =
  map
    wrap
    [ (x - 1, y - 1),
      (x, y - 1),
      (x + 1, y - 1),
      (x - 1, y),
      (x + 1, y),
      (x - 1, y + 1),
      (x, y + 1),
      (x + 1, y + 1)
    ]

wrap :: Pos -> Pos
wrap (x, y) =
  ( ((x - 1) `mod` width) + 1,
    ((y - 1) `mod` height) + 1
  )

liveneighbs :: Board' -> Pos -> Int
liveneighbs b = length . filter (isAlive b) . neighbs

survivors :: Board' -> [Pos]
survivors b = [p | p <- b, elem (liveneighbs b p) [2, 3]]

births :: Board' -> [Pos]
births b =
  [p | p <- rmdups (concat (map neighbs b)), isEmpty b p, liveneighbs b p == 3]

rmdups :: (Eq a) => [a] -> [a]
rmdups [] = []
rmdups (x : xs) = x : rmdups (filter (/= x) xs)

nextgen :: Board' -> Board'
nextgen b = survivors b ++ births b

life :: Board' -> IO ()
life b =
  do
    cls
    showcells b
    wait 500000
    life (nextgen b)

wait :: Int -> IO ()
wait n = sequence_ [return () | _ <- [1 .. n]]

-- 10.10

-- 1

putStr'' :: String -> IO ()
putStr'' [] = return ()
putStr'' xs = sequence_ [putChar x | x <- xs]

-- 2

putBoard' = putBoard'' 1

putBoard'' :: Int -> Board -> IO ()
putBoard'' r [] = return ()
putBoard'' r (n : ns) = do
  putRow r n
  putBoard'' (r + 1) ns

-- 3

putBoard''' :: Board -> IO ()
putBoard''' [] = return ()
putBoard''' ns = sequence_ [putRow r n | (r, n) <- zip [1 ..] ns]

-- 4

-- adder 関数の定義
adder :: IO ()
adder = do
  -- ユーザーに入力の数を尋ねる
  putStr "How many numbers? "
  -- 入力を読み取り、整数に変換
  n <- readLn :: IO Int
  -- 補助関数を使用して、n 個の数字を読み取り合計を計算
  total <- adderHelper 0 n
  -- 合計を表示
  putStrLn $ "The total is " ++ show total

-- adderHelper 関数の定義
-- 引数:
--   total   : 現在の合計
--   remaining : 残りの数字の数
adderHelper :: Int -> Int -> IO Int
adderHelper total 0 = return total -- 残りが0の場合、合計を返す
adderHelper total remaining = do
  -- 数字を読み取る
  num <- readLn :: IO Int
  -- 合計を更新し、残りの数を減らして再帰的に呼び出す
  adderHelper (total + num) (remaining - 1)

-- 5
-- adder_sequence.hs

-- 必要なモジュールのインポート

-- adder 関数の定義
adder' :: IO ()
adder' = do
  -- ユーザーに入力の数を尋ねる
  putStr "How many numbers? "
  -- 入力を読み取り、整数に変換
  n <- readLn :: IO Int
  -- n 個の readLn アクションを生成し、sequence で実行してリストとして取得
  numbers <- sequence (replicate n readNumber)
  -- 合計を計算
  let total = sum numbers
  -- 合計を表示
  putStrLn $ "The total is " ++ show total

-- 補助関数: 数字を読み取るアクション
readNumber :: IO Int
readNumber = readLn :: IO Int

-- 6
