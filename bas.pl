a(V,G,[V|G]).
e(X,I,G,G):-member(X=I,G),!.
e(I,I)-->{integer(I)},!.
e(A+B,I)-->!,e(A,I1),e(B,I2),{I is I1+I2}.
e(X=E,V)-->!,e(E,V),a(X=V),!.
e(E1<E2,I)-->!,e(E1,I1),e(E2,I2),{I1<I2->I=1;I=0},!.
g(I:_,[I:E|Ls],[I:E|Ls]):-!.
g(I:_,[_|Ls],Rs):-!,g(I:_,Ls,Rs).
g(_:_,[],[]).
s(goto(I),_)-->{basic(P),g(I:_,P,Ls)},b(Ls).
s(X=E,Ls)-->!,e(E,V),a(X=V),b(Ls).
s(if(E,E1),Ls)-->!,e(E,V),({V=0} -> b(Ls);s(E1,Ls)).
s(print(E),Ls)-->!,e(E,V),{writeln(V)},b(Ls).
b([])-->!.
b([_:E|Ls])-->s(E,Ls).
run:- basic(P),b(P,[],_).
basic([
10:(a=0),
20:(print(a)),
30:(a=a+1),
40:(if(a<2,goto(20)))
]).
:- run.
:- halt.
