(||) :: Bool -> Bool -> Bool

{-
True || True = True
True || False = True
False || True = True
False || False = False
-}

{-
False || False = False
_ || _ = True
-}

{-
False || b = b
True || _ = True
-}

b || c | b == c = b
       | otherwise = True
