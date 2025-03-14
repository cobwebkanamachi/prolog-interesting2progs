# prolog-interesting2progs
<PRE>
i found 2 interesting prolog programs on qiita, so experiment these.
1. bas.pl (filename was named by me)
   He made a basic implemented in 16 lines of swi-prolog.</PRE>
   https://qiita.com/h_sakurai/items/0f68db9116fe30315c26
<PRE>
2. ghc.pl (same above)
   He made GHC(guarded Horn Clause) on swi-prolog by him.</PRE>
   https://qiita.com/tadashi9e/items/ba2a15fec7462ce80b7e
<PRE>   
To run : 
1. swipl bas.pl
   output lines truncated two lines.
3. swipl ghc.pl
   then paste bellow into ?- after.
   ghc(primes(20, Ps)).
   then paste bellow into ?- after.
   then got bellow.
   Ps = [2, 3, 5, 7, 11, 13, 17, 19].
   ghc((printstream(Ps), primes(100, Ps))).
   then got bellow.
   2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97
   Ps = [2, 3, 5, 7, 11, 13, 17, 19, 23|...].

Sorry No warranty...(mistyped or ...misunderstanding??)
</PRE>   
Enjoy!

