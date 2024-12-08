-- 6.1
{-
fac :: Int -> Int
fac n = product [1..n]
-}

{-
fac :: Int -> Int
fac 0 = 1
fac n = n * fac (n-1)
-}

{-
(*) :: Int -> Int -> Int
m * 0 = 0
m * n = m + (m * (n-1))
-}

-- 6.2
{-
product :: Num a => [a] -> a
product []     = 1
product (n:ns) = n * Main.product ns
-}

{-
length :: [a] -> Int
length [] = 0
length (_:xs) = 1 + Main.length xs
-}

reverse :: [a] -> [a]
reverse []     = []
reverse (x:xs) = Main.reverse xs ++ [x]

{-
(++) :: [a] -> [a] -> [a]
[]     ++ ys = ys
(x:xs) ++ ys = x : (xs Main.++ ys)
-}

insert :: Ord a => a -> [a] -> [a]
insert x []                 = [x]
insert x (y:ys) | x <= y    = x:y:ys
                | otherwise = y : insert x ys

isort :: Ord a => [a] -> [a]
isort []     = []
isort (x:xs) = insert x (isort xs)

-- 6.3
zip :: [a] -> [b] -> [(a,b)]
zip []     _      = []
zip _      []     = []
zip (x:xs) (y:ys) = (x,y) : Main.zip xs ys

{-
drop :: Int -> [a] -> [a]
drop 0 xs     = xs
drop _ []     = []
drop n (_:xs) = Main.drop (n-1) xs
-}

-- 6.4
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n-2) + fib (n-1)

qsort :: Ord a => [a] -> [a]
qsort [] = []
qsort (x:xs) = qsort smaller ++ [x] ++ qsort larger
  where
    smaller = [a | a <- xs, a <= x]
    larger  = [b | b <- xs, b > x]

-- 6.5
even :: Int -> Bool
even 0 = True
even n = Main.odd (n-1)

odd :: Int -> Bool
odd 0 = False
odd n = Main.even (n-1)

evens :: [a] -> [a]
evens []     = []
evens (x:xs) = x : odds xs

odds :: [a] -> [a]
odds []     = []
odds (_:xs) = evens xs

-- 6.6
-- 6.6.1
product :: Num a => [a] -> a
product = foldr (*) 1

-- 6.6.2
{-
drop :: Integral b => b -> [a] -> [a]
drop 0 xs     = xs
drop _ []     = []
drop n (_:xs) = Main.drop (n-1) xs
-}

-- 6.6.3
{-
init :: [a] -> [a]
init (x:xs) | null xs   = []
            | otherwise = x : Main.init xs
-}

init :: [a] -> [a]
init [_] = []
init (x:xs) = x : Main.init xs

-- 6.8
-- 1.
fac :: Int -> Int
fac 0 = 1
fac n | n > 0 = n * fac (n-1)

-- 2.
sumdown :: Int -> Int
sumdown 0 = 0
sumdown n = n + sumdown (n - 1)

-- 3.

{-
(*) :: Int -> Int -> Int
m * 0 = 0
m * n = m + (m Main.* (n-1))
-}

(^) :: Int -> Int -> Int
m ^ 0 = 1
m ^ n = m * (m Main.^ (n-1))

{-
2 ^ 3 = 2 * (2 ^ 2)
      = 2 * 2 * (2 ^ 1)
      = 2 * 2 * 2 * (2 ^ 0)
      = 2 * 2 * 2 * 1
      = 8
-}

-- 4.
euclid :: Int -> Int -> Int
euclid m n | m == n = m
           | m > n = euclid n (m - n)
           | m < n = euclid m (n - m)

-- 5.
{-
length :: [a] -> Int
length [] = 0
length (_:xs) = 1 + length xs

length [1,2,3] = 1 + length [2,3]
               = 1 + 1 + length [3]
               = 1 + 1 + 1 + length []
               = 1 + 1 + 1 + 0
               = 3

drop :: Int -> [a] -> [a]
drop 0 xs     = xs
drop _ []     = []
drop n (_:xs) = drop (n-1) xs

drop 3 [1,2,3,4,5] = drop 2 [2,3,4,5]
                   = drop 1 [3, 4, 5]
                   = drop 0 [4, 5]
                   = [4, 5]

init :: [a] -> [a]
init (x:xs) | null xs   = []
            | otherwise = x : init xs

init [1,2,3] = 1 : init [2,3]
             = 1 : 2 : init [3]
             = 1 : 2 : []
             = [1, 2]
-}

-- 6.
-- a
and :: [Bool] -> Bool
and [b]                 = b
and (b:bs) | b == False = False
           | otherwise  = Main.and bs

-- b
concat :: [[a]] -> [a]
concat [] = []
concat (x:xs) = x ++ Main.concat xs

-- c
replicate :: Int -> a -> [a]
replicate 0 _ = []
replicate n x = x : Main.replicate (n-1) x

-- d
(!!) :: [a] -> Int -> a
(!!) (x:xs) 0         = x
(!!) (x:xs) n | n > 0 = (Main.!!) xs (n - 1)

-- e
elem :: Eq a => a -> [a] -> Bool
elem e []                 = False
elem e (x:xs) | e == x    = True
              | otherwise = Main.elem e xs

-- 7.
merge :: Ord a => [a] -> [a] -> [a]
merge xs []                  = xs
merge [] ys                  = ys
merge (x:xs) (y:ys) | x >= y = y : merge (x:xs) ys
                    | x < y  = x : merge xs (y:ys)

-- 8.
{-
halve :: [a] -> ([a], [a])
halve xs = (take n xs, drop n xs)
  where n = (length xs) `div` 2

msort :: Ord a => [a] -> [a]
msort []  = []
msort [x] = [x]
msort xs  = merge (msort (fst (halve xs))) (msort (snd (halve xs)))
-}

{-
msort [5,2,3,4,1] = merge (msort [5,2]) (msort [3,4,1])
                  = merge (merge (msort [5]) (msort [2])) (merge (msort [3,4]) (msort [1]))
                  = merge (merge [5] [2]) (merge (merge [3] [4]) [1])
                  = merge ([2, 5] (merge [3,4] [1]))
                  = merge ([2, 5] [1,3,4])
                  = [1,2,3,4,5]
-}

-- 9.
-- a
sum :: Num a => [a] -> a
sum []     = 0
sum (n:ns) = n + Main.sum ns

-- b
take :: Int -> [a] -> [a]
take 0 xs     = []
take _ []     = []
take n (x:xs) = x : Main.take (n-1) xs

-- c
last :: [a] -> a
last (x:xs) | null xs   = x
            | otherwise = Main.last xs
