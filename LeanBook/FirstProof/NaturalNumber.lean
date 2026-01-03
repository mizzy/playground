inductive MyNat where
  | zero
  | succ (n : MyNat)

#check MyNat.zero

#check MyNat.succ .zero

def MyNat.one := MyNat.succ .zero

def MyNat.two := MyNat.succ .one

def MyNat.add (m n : MyNat) : MyNat :=
  match n with
  | .zero => m
  | .succ n => succ (add m n )

#check MyNat.add .one .one = .two

set_option pp.fieldNotation.generalized false

#reduce MyNat.add .one .one

#reduce MyNat.two

example : MyNat.add .one .one = .two := by
  rfl
