import Data.Char
import Data.List

-- 7.1

{-
add :: Int -> Int -> Int
add x y = x + y
-}

add :: Int -> Int -> Int
add = \x -> (\y -> x + y)

{-
twice :: (a -> a) -> a -> a
twice f x = f (f x)
-}

-- 7.2

{-
map :: (a -> b) -> [a] -> [b]
map f xs = [f x | x <- xs]
-}

{-
map :: (a -> b) -> [a] -> [b]
map f []     = []
map f (x:xs) = f x : Main.map f xs
-}

{-
filter :: (a -> Bool) -> [a] -> [a]
filter p xs = [x | x <- xs, p x]
-}

{-
filter :: (a -> Bool) -> [a] -> [a]
filter p []                 = []
filter p (x:xs) | p x       = x : Main.filter p xs
                | otherwise = Main.filter p xs
-}

{-
sumsqreven :: [Int] -> Int
sumsqreven ns = sum (Main.map (^2) (Main.filter even ns))
-}

-- 7.3
{-
sum []     = 0
sum (x:xs) = x + Main.sum xs

product []     = 1
product (x:xs) = x * Main.product xs

or []     = False
or (x:xs) = x || Main.or xs


and []     = True
and (x:xs) = x && Main.and xs
-}

{-
sum :: Num a => [a] -> a
sum = foldr (+) 0

product :: Num a => [a] -> a
product = foldr (*) 1

or :: [Bool] -> Bool
or = foldr (||) False

and :: [Bool] -> Bool
and = foldr (&&) True
-}

{-
foldr :: (a -> b -> b) -> b -> [a] -> b
foldr f v [] = v
foldr f v (x:xs) = f x (Main.foldr f v xs)
-}

{-
length :: [a] -> Int
length [] = 0
length (_:xs) = 1 + Main.length xs
-}

{-
length :: [a] -> Int
length = foldr (\_ n -> 1 + n) 0
-}

{-
reverse :: [a] -> [a]
reverse []     = []
reverse (x:xs) = reverse xs ++ [x]
-}

snoc :: a -> [a] -> [a]
snoc x xs = xs ++ [x]

{-
reverse :: [a] -> [a]
reverse = foldr snoc []
-}

{-
reverse [1,2,3] = 1 snoc (2 snoc ( 3 snoc [])))
                = 1 snoc (2 scnoc ([3])
                = 1 snoc ([3, 2])
                = [3, 2, 1]
-}


-- 7.4

{-
sum :: Num a => [a] -> a
sum = sum' 0
  where
    sum' v []     = v
    sum' v (x:xs) = sum' (v+x) xs
-}

{-
f []     = v
f (x:xs) = x # f xs

f v []     = v
f v (x:xs) = f (v # x) xs
-}

{-
sum :: Num a => [a] -> a
sum = foldr (+) 0

sum :: Num a => [a] -> a
sum = foldl (+) 0

product :: Num a => [a] -> a
product = foldr (*) 1

product :: Num a => [a] -> a
product = foldl (*) 1

or :: [Bool] -> Bool
or = foldr (||) False

or :: [Bool] -> Bool
or = foldl (||) False

and :: [Bool] -> Bool
and = foldr (&&) True


and :: [Bool] -> Bool
and = foldl (&&) True
-}

{-
length :: [a] -> Int
length = foldr (\_ n -> n+1) 0
-}

{-
length :: [a] -> Int
length = foldl (\n _ -> n+1) 0

reverse :: [a] -> [a]
reverse = foldl (\xs x -> x:xs) []
-}

{-
foldr :: (a -> b -> b) -> b -> [a] -> b
foldr f v [] = v
foldr f v (x:xs) = f x (foldr f v xs)

foldl :: (a -> b -> a) -> a -> [b] -> a
foldl f v []     = v
foldl f v (x:xs) = foldl f (f v x) xs
-}

-- 7.5

{-
(.) :: (b -> c) -> (a -> b) -> (a -> c)
f . g = \x -> f (g x)
-}

{-
odd n = not (even n)
twice f x = f (f x)
sumsqreven ns = sum (map (^2) (filter even ns))
-}

odd = not . even
twice f = f . f
sumsqreven = sum . map (^2) . filter even

compose :: [a -> a] -> (a -> a)
compose = foldr (.) id

-- 7.6

type Bit = Int

{-
bin2int :: [Bit] -> Int
bin2int bits = sum [w*b | (w,b) <- zip weights bits]
  where weights = iterate (*2) 1
-}

bin2int :: [Bit] -> Int
bin2int = foldr (\x y -> x + 2*y) 0

int2bin :: Int -> [Bit]
int2bin 0 = []
int2bin n = n `mod` 2 : int2bin (n `div` 2)

make8 :: [Bit] -> [Bit]
make8 bits = take 8 (bits ++ repeat 0)

encode :: String -> [Bit]
encode = concat . map (make8 . int2bin . ord)

{--
chop8 :: [Bit] -> [[Bit]]
chop8 []   = []
chop8 bits = take 8 bits : chop8 (drop 8 bits)
--}

decode :: [Bit] -> String
decode = map (chr . bin2int) . chop8

transmit :: String -> String
transmit = decode . channel . encode

channel :: [Bit] -> [Bit]
channel = id

-- 7.7

-- 7.7.1

votes :: [String]
votes = ["Red", "Blue", "Green", "Blue", "Blue", "Red"]

count :: Eq a => a -> [a] -> Int
count x = length . filter (== x)

rmdups :: Eq a => [a] -> [a]
rmdups [] = []
rmdups (x:xs) = x : rmdups (filter (/= x) xs)

result :: Ord a => [a] -> [(Int,a)]
result vs = sort [(count v vs, v) | v <- rmdups vs]

winner :: Ord a => [a] -> a
winner = snd . last . result

-- 7.7.2

ballots :: [[String]]
ballots = [["Red", "Green"],
           ["Blue"],
           ["Green", "Red", "Blue"],
           ["Blue", "Green", "Red"],
           ["Green"]]

rmempty :: Eq a => [[a]] -> [[a]]
rmempty = filter (/= [])

elim :: Eq a => a -> [[a]] -> [[a]]
elim x = map (filter (/= x))

rank :: Ord a => [[a]] -> [a]
rank = map snd . result . map head

winner' :: Ord a => [[a]] -> a
winner' bs = case rank (rmempty bs) of
  [c] ->c
  (c:cs) -> winner' (elim c bs)

  -- 7.9

-- 1.
{-
[f x | x <- xs, p x]
map f (filter p x)
-}

-- 2.

all :: (a -> Bool) -> [a] -> Bool
all p = and . map p

any :: (a -> Bool) -> [a] -> Bool
any p = or . map p

takeWhile :: (a -> Bool) -> [a] -> [a]
takeWhile _ []                 = []
takeWhile p (x:xs) | p x       = x : Main.takeWhile p xs
                   | otherwise = []

dropWhile :: (a -> Bool) -> [a] -> [a]
dropWhile _ []                 = []
dropWhile p (x:xs) | p x       = Main.dropWhile p xs
                   | otherwise = x:xs

-- 3.

map2 f = foldr (\x xs -> f x : xs) []

filter2 p = foldr (\x xs -> if p x then x:xs else xs) []

-- 4.
dec2int :: [Int] -> Int
dec2int = foldl (\x y -> 10 * x + y) 0

-- 5.
-- a

curry2 :: ((a,b) -> c) -> (a -> b -> c)
curry2 f = \x y ->  f(x, y)

uncurry2 :: (a -> b -> c) -> ((a, b) ->c)
uncurry2 f = \(x, y) -> f x y

-- 6

unfold p h t x | p x       = []
               | otherwise = h x : unfold p h t (t x)

chop8 :: [Bit] -> [[Bit]]
-- chop8 []   = []
-- chop8 bits = take 8 bits : chop8 (drop 8 bits)
chop8 = unfold null (take 8) (drop 8)

map' :: (a -> b) -> [a] -> [b]
-- map' f []     = []
-- map' f (x:xs) = f x : map' f xs
map' f = unfold null (f.head) tail

iterate' :: (a -> a) -> a -> [a]
iterate' f = unfold (\_ -> False) id f

-- 7

{--
calcParity :: [Bit] -> Bit
calcParity bits | (length (filter (== 1) bits) `mod` 2) == 0 = 0
                | otherwise                                  = 1
--}

calcParity :: [Bit] -> Bit
calcParity = (`mod` 2) . sum

addParity :: [Bit] -> [Bit]
addParity bits = bits ++ [calcParity bits]

encode2 :: String -> [Bit]
encode2 = concat . map (addParity . make8 . int2bin . ord)

chop9 :: [Bit] -> [[Bit]]
chop9 = unfold null (take 9) (drop 9)

checkByte :: [[Bit]] -> [[Bit]]
checkByte = map checkParity

checkParity :: [Bit] -> [Bit]
checkParity bits | sum (take 8 bits) `mod` 2 == bits !! 8 =  take 8 bits
                 | otherwise                              = error "Parity error"

decode2 :: [Bit] -> String
decode2 = map (chr . bin2int) . checkByte . chop9

-- 8

{-
decode2 ( encode2 "abcde")
decode2 (tail (encode2 "abcde"))
-}

-- 9

altMap :: (a -> b) -> (a -> b) -> [a] -> [b]
altMap _ _ [] = []
altMap f g (x:xs) = f x : altMap g f xs


{-
altMap (+10) (+100) [0,1,2,3,4]
[10,101,12,103,14]
-}


-- 10

luhnDouble :: Int -> Int
luhnDouble n | n * 2> 9  = n * 2 - 9
             | otherwise = n * 2

luhn :: [Int] -> Bool
luhn xs = sum (altMap luhnDouble id xs) `mod` 10 == 0
