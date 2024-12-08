import Data.Char

let2int :: Char -> Int
let2int c = ord c - ord 'a'

int2let :: Int -> Char
int2let n = chr (ord 'a' + n)

shift :: Int -> Char -> Char
shift n c | isLower c = int2let ((let2int c + n ) `mod` 26)
          | otherwise = c

encode :: Int -> String -> String
encode n xs = [shift n x | x <- xs]

table :: [Float]
table = [8.1, 1.5, 2.8, 4.2, 12.7, 2.2, 2.0, 6.1, 7.0,
         0.2, 0.8, 4.0, 2.4, 6.7, 7.5, 1.9, 0.1, 6.0,
         6.3, 9.0, 2.8, 1.0, 2.4, 0.2, 2.0, 0.1]

percent :: Int -> Int -> Float
percent n m = (fromIntegral n / fromIntegral m) * 100

lowers :: String -> Int
lowers xs = length [x | x <- xs, x >= 'a' && x <= 'z']

count :: Char -> String -> Int
count x xs = length [x' | x' <- xs, x == x']

freqs :: String -> [Float]
freqs xs = [percent (count x xs) n | x <- ['a'..'z']]
  where n = lowers xs

chisqr :: [Float] -> [Float] -> Float
chisqr os es = sum [((o-e)^2)/e | (o,e) <- zip os es]

rotate :: Int -> [a] -> [a]
rotate n xs = drop n xs ++ take n xs

positions :: Eq a => a -> [a] -> [Int]
positions x xs = [i | (x',i) <- zip xs [0..], x == x']

crack :: String -> String
crack xs = encode (-factor) xs
  where
    factor = head (positions (minimum chitab) chitab)
    chitab = [chisqr (rotate n table') table | n <- [0..25]]
    table' = freqs xs

-- 5.7 練習問題
-- 1.
a = sum [x^2 | x <- [1..100]]

-- 2.
grid :: Int -> Int -> [(Int, Int)]
grid m n = [(x, y) | x <- [0..m], y <- [0..n]]

-- 3.
square :: Int -> [(Int, Int)]
square n = [(x, y) | (x, y) <- grid n n, x /= y]

-- 4.
replicate :: Int -> a ->[a]
replicate n x = [x | _ <- [1..n]]

-- 5.
pyths :: Int -> [(Int, Int, Int)]
pyths n = [(x, y, z) | x <- [1..n], y <- [1..n], z <-[1..n], x^2 + y^2 == z^2]

-- 6.
factors :: Int -> [Int]
factors n = [x | x <- [1..n], n `mod` x == 0]

perfects :: Int -> [Int]
perfects n = [x | x <- [1..n], sum (factors x) - x == x]

-- 7.
b = [(x, y) | x <- [1,2,3], y <- [4,5,6]] == concat [[(x,y) |  y <- [4,5,6]] | x <- [1,2,3]]

-- 8.
find :: Eq a => a -> [(a,b)] -> [b]
find k t = [v | (k',v) <- t, k == k']

positions2 :: Eq a => a -> [a] -> [Int]
positions2 x xs = find x [x' | x' <- zip xs [0..]]

c = positions 'a' ['a', 'b', 'a'] == positions2 'a' ['a', 'b', 'a']

-- 9.
scalarproduct :: [Int] -> [Int] -> Int
scalarproduct xs ys = sum [x * y | (x, y) <- zip xs ys]

-- 10.
int2let2 :: Int -> Char
int2let2 n = chr (ord 'A' + n)

let2int2 :: Char -> Int
let2int2 c = ord c - ord 'A'

shift2 :: Int -> Char -> Char
shift2 n c | isLower c = int2let ((let2int c + n) `mod` 26)
           | isUpper c = int2let2 ((let2int2 c + n) `mod` 26)
           | otherwise = c

encode2 :: Int -> String -> String
encode2 n xs = [shift2 n x | x <- xs]
