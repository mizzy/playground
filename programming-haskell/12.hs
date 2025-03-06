-- 12.1

inc :: [Int] -> [Int]
inc [] = []
inc (n : ns) = n + 1 : inc ns

sqr :: [Int] -> [Int]
sqr [] = []
sqr (n : ns) = n ^ 2 : sqr ns

map' :: (a -> b) -> [a] -> [b]
map' f [] = []
map' f (x : xs) = f x : map' f xs

data Tree a = Leaf a | Node (Tree a) (Tree a)
  deriving (Show)

instance Functor Tree where
  fmap g (Leaf x) = Leaf (g x)
  fmap g (Node l r) = Node (fmap g l) (fmap g r)

inc' :: (Functor f) => f Int -> f Int
inc' = fmap (+ 1)

-- 12.2
insert :: (Ord a) => a -> [a] -> [a]
insert x [] = [x]
insert x (y : ys)
  | x <= y = x : y : ys
  | otherwise = y : insert x ys

-- 12.3
safediv :: Int -> Int -> Maybe Int
safediv _ 0 = Nothing
safediv n m = Just (n `div` m)

-- 12.3.2
type State = Int

-- type ST = State -> State
-- type ST a = State -> (a,State)
newtype ST a = S (State -> (a, State))

app :: ST a -> State -> (a, State)
app (S st) x = st x

instance Functor ST where
  fmap g st = S (\s -> let (x, s') = app st s in (g x, s'))

instance Applicative ST where
  pure x = S (\s -> (x, s))
  stf <*> stx =
    S
      ( \s ->
          let (f, s') = app stf s
              (x, s'') = app stx s'
           in (f x, s'')
      )

instance Monad ST where
  st >>= f = S (\s -> let (x, s') = app st s in app (f x) s')

-- 12.3.3
tree :: Tree Char
tree = Node (Node (Leaf 'a') (Leaf 'b')) (Leaf 'c')

rlabel :: Tree a -> Int -> (Tree Int, Int)
rlabel (Leaf _) n = (Leaf n, n + 1)
rlabel (Node l r) n = (Node l' r', n'')
  where
    (l', n') = rlabel l n
    (r', n'') = rlabel r n'

fresh :: ST Int
fresh = S (\n -> (n, n + 1))

fresh' = fmap (+ 1) (fresh)

alabel :: Tree a -> ST (Tree Int)
alabel (Leaf _) = Leaf <$> fresh
alabel (Node l r) = Node <$> alabel l <*> alabel r

alabel' :: Tree a -> ST (Tree Int)
alabel' (Leaf _) = Leaf <$> fresh'
alabel' (Node l r) = Node <$> alabel' l <*> alabel' r

mlabel :: Tree a -> ST (Tree Int)
mlabel (Leaf _) = do
  n <- fresh
  return (Leaf n)
mlabel (Node l r) = do
  l' <- mlabel l
  r' <- mlabel r
  return (Node l' r')

-- 12.3.4
mapM' :: (Monad m) => (a -> m b) -> [a] -> m [b]
mapM' f [] = return []
mapM' f (x : xs) = do
  y <- f x
  ys <- mapM' f xs
  return (y : ys)

-- 12.5
-- 1
data Tree' a = Leaf' | Node' (Tree' a) a (Tree' a)
  deriving (Show)

instance Functor Tree' where
  fmap g Leaf' = Leaf'
  fmap g (Node' l x r) = Node' (fmap g l) (g x) (fmap g r)

-- 2
{-
instance Functor ((->) a) where
  fmap = (.)
-}
