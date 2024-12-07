luhnDouble :: Int -> Int
luhnDouble n | n * 2> 9  = n * 2 - 9
             | otherwise = n * 2

luhn :: Int -> Int -> Int -> Int -> Bool

-- luhn a b c d = if (luhnDouble a + b + luhnDouble c + d) `mod` 10 == 0 then True else False

-- luhn a b c d | (luhnDouble a + b + luhnDouble c + d) `mod` 10 == 0 = True
--             | otherwise = False

luhn = \a -> (\b -> (\c -> (\d -> if (luhnDouble a + b + luhnDouble c + d) `mod` 10 == 0 then True else False)))
