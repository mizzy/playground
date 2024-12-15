-- 8.1
type Pos = (Int,Int)

type Assoc k v = [(k,v)]

find :: Eq k => k -> Assoc k v -> v
find k t = head [v | (k',v) <- t, k == k']

-- 8.2

data Move = North | South | East | West

move :: Move -> Pos -> Pos
move North (x,y) = (x,y+1)
move South (x,y) = (x,y-1)
move East  (x,y) = (x+1,y)
move West  (x,y) = (x-1,y)

moves :: [Move] -> Pos -> Pos
moves[] p=p
moves (m:ms) p = moves ms (move m p)

rev :: Move -> Move
rev North = South
rev South = North
rev East  = West
rev West  = East


-- data Shape = Circle Float | Rect Float Float


square :: Float -> Shape
square n = Rect n n

area :: Shape -> Float
area (Circle r) = pi * r^2
area (Rect x y) = x * y

safediv :: Int -> Int -> Maybe Int
safediv _ 0 = Nothing
safediv m n = Just (m `div` n)

safehead :: [a] -> Maybe a
safehead [] = Nothing
safehead xs = Just (head xs)

-- 8.3

-- newtype Nat = N Int


-- 8.4

data Nat = Zero | Succ Nat
    deriving (Eq, Ord, Show, Read)

nat2int :: Nat -> Int
nat2int Zero     = 0
nat2int (Succ n) = 1 + nat2int n

int2nat :: Int -> Nat
int2nat 0 = Zero
int2nat n = Succ (int2nat (n-1))

-- add :: Nat -> Nat -> Nat
-- add m n = int2nat (nat2int m + nat2int n)

add :: Nat -> Nat -> Nat
add Zero     n = n
add (Succ m) n = Succ (add m n)

data List a = Nil | Cons a (List a)

len :: List a -> Int
len Nil         = 0
len (Cons _ xs) = 1 + len xs

-- data Tree a = Leaf a | Node (Tree a) a (Tree a)

{-
t :: Tree Int
t = Node (Node (Leaf 1) 3 (Leaf 4)) 5
         (Node (Leaf 6) 7 (Leaf 9))
-}

{-
occurs :: Eq a => a -> Tree a -> Bool
occurs x (Leaf y) = x == y
occurs x (Node l y r) = x == y || occurs x l || occurs x r
-}

{-
flatten :: Tree a -> [a]
flatten (Leaf x) = [x]
flatten (Node l x r) = flatten l ++ [x] ++ flatten r
-}

{-
occurs :: Ord a => a -> Tree a -> Bool
occurs x (Leaf y)                 = x == y
occurs x (Node l y r) | x == y    = True
                      | x < y     = occurs x l
                      | otherwise = occurs x r
-}

-- 8.5

data Shape = Circle Float | Rect Float Float
    deriving (Eq, Ord, Show, Read)

-- 8.6

data Prop = Const Bool
          | Var Char
          | Not Prop
          | And Prop Prop
          | Imply Prop Prop
          | Or Prop Prop
          | Eq Prop Prop

p1 :: Prop
p1 = And (Var 'A') (Not (Var 'A'))

p2 :: Prop
p2 = Imply (And (Var 'A') (Var 'B')) (Var 'A')

p3 :: Prop
p3 = Imply (Var 'A') (And (Var 'A') (Var 'B'))

p4 :: Prop
p4 = Imply (And (Var 'A') (Imply
      (Var 'A') (Var 'B'))) (Var 'B')

type Subst = Assoc Char Bool

{-
eval :: Subst -> Prop -> Bool
eval _ (Const b)   = b
eval s (Var x)     = find x s
eval s (Not p)     = not (eval s p)
eval s (And p q)   = eval s p && eval s q
eval s (Imply p q) = eval s p <= eval s q
eval s (Or p q)    = eval s p || eval s q
eval s (Eq p q)    = eval s p == eval s p
-}

vars :: Prop -> [Char]
vars (Const _)   = []
vars (Var x)     = [x]
vars (Not p)     = vars p
vars (And p q)   = vars p ++ vars q
vars (Imply p q) = vars p ++ vars q
vars (Or p q)    = vars p ++ vars q
vars (Eq p q)    = vars p ++ vars q

type Bit = Int

int2bin :: Int -> [Bit]
int2bin 0 = []
int2bin n = n `mod` 2 : int2bin (n `div` 2)


bools :: Int -> [[Bool]]
bools n = map (reverse . map conv . make n . int2bin) range
    where
        range = [0..(2^n)-1]
        make n bs = take n (bs ++ repeat 0)
        conv 0 = False
        conv 1 = True


{-
bools :: Int -> [[Bool]]
bools 0 = [[]]
bools n = map (False:) bss ++ map (True:) bss
          where bss = bools (n-1)
-}

rmdups :: Eq a => [a] -> [a]
rmdups [] = []
rmdups (x:xs) = x : rmdups (filter (/= x) xs)

substs :: Prop -> [Subst]
substs p = map (zip vs) (bools (length vs))
           where vs = rmdups (vars p)

{-
isTaut :: Prop -> Bool
isTaut p = and [eval s p | s <-substs p]
-}

-- 8.7



{-
value :: Expr -> Int
value (Val n) = n
value (Add x y) = value x + value y
value (Mul x y) = value x * value y
-}

data Expr = Val Int | Add Expr Expr | Mul Expr Expr
    deriving (Eq, Ord, Show, Read)

type Cont = [Op]
data OpType = ADD_OP | MUL_OP deriving (Eq, Show)
data Op = EVAL Expr OpType | ADD Int | MUL Int deriving (Eq, Show)

eval :: Expr -> Cont -> Int
eval (Val n) c = exec c n
eval (Add x y) c = eval x (EVAL y ADD_OP : c)
eval (Mul x y) c = eval x (EVAL y MUL_OP : c)

exec :: Cont -> Int -> Int
exec [] n            = n
exec (EVAL y op : c) n =
     case op of
         ADD_OP -> eval y (ADD n : c)
         MUL_OP -> eval y (MUL n : c)
exec (ADD n : c) m   = exec c (n + m)
exec (MUL n : c) m   = exec c (n * m)

value :: Expr -> Int
value e = eval e []


-- 8.1
-- 1

{-
add :: Nat -> Nat -> Nat
add Zero     n = n
add (Succ m) n = Succ (add m n)
-}

mult :: Nat -> Nat -> Nat
mult m Zero     = Zero
mult m (Succ n) = add m (mult m n)

-- 2

{-
occurs :: Ord a => a -> Tree a -> Bool
occurs x (Leaf y)                         = compare x y == EQ
occurs x (Node l y r) | compare x y == EQ = True
                      | compare x y == LT = occurs x l
                      | otherwise         = occurs x r
-}

-- 3

data Tree a = Leaf a | Node (Tree a) (Tree a)
  deriving (Show)

leaves :: Tree a -> Int
leaves (Leaf _)   = 1
leaves (Node l r) = leaves l + leaves r

balanced :: Tree a -> Bool
balanced (Leaf _) = True
balanced (Node l r) = abs (leaves l - leaves r) <= 1
                      && balanced l && balanced r

-- 4
halve :: [a] -> ([a], [a])
halve xs = (take n xs, drop n xs)
  where n = (length xs) `div` 2

balance :: [a] -> Tree a
balance [x] = Leaf x
balance xs = Node (balance ys) (balance zs)
             where (ys, zs) = halve xs

-- 5
folde :: (Int -> a) -> (a -> a -> a) -> Expr -> a
folde f g (Val n)   = f n
folde f g (Add x y) = g (folde f g x) (folde f g y)

{-
eval :: Expr -> Int
eval = folde (+0) (+)
-}

size :: Expr -> Int
size = folde ((+1).(*0)) (+)

-- 7
{-
instance Eq a => Eq (Maybe a) where
  Nothing == Nothing = True
  Nothing == _       = False
  _       == Nothing = False
  Just x  == Just y  = x == y
-}

{--
instance Eq a => Eq [a] where
  [] == []         = True
  [] == _          = False
  _  == []         = False
  (x:xs) == (y:ys) = x == y && xs == ys
--}

-- 8
-- 上の方の元実装に追加

-- 9
-- 上の方の元実装に追加
