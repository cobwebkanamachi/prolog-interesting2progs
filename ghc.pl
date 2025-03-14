% デバッグ時には以下を切り替える
% ghc_trace(P) :- format('trace: ~w~n', P).
ghc_trace(_).

% 引数に与えられた処理を実行する。
% 実行に失敗した場合には報告する。
always_success(P) :-
    ( call(P), !
    ; format('failed to execute: ~w~n', P)).

% 与えられたクエリの実行に失敗した場合の表示
report_fail(P) :-
    format('fail: ~w~n', P).

% 連言の場合は分解して順次処理
ghc((P, Q)) :- !, ghc(P), ghc(Q).

% 以下のように逆順に処理しても結果は同じになるはず。
% ghc((P, Q)) :- !, ghc(Q), ghc(P).

% 順序を明示できるように（本来の GHC にはない）
ghc((P -> Q)) :- !, ghc(P) -> ghc(Q).

% true はなにもしない。
ghc(true) :-
    !,
    ghc_trace(ghc(true)).
% A = B なら（アクティブ）ユニフィケーション実施。
ghc(A = B) :-
    !,
    ghc_trace(ghc(A = B)),
    (A = B ; report_fail(A = B)).
% A is B なら A is B を実行する。
% 但し、B に未実現変数が含まれるなら実現を待ってから実行。
ghc(A is B) :-
    !,
    ghc_trace(ghc(A is B)),
    term_variables(B, Vars),
    (Vars = [] -> (A is B ; report_fail(A is B))
    ; ghc_build_nonvars(Vars, Waits)
    -> when(Waits, (A is B ; report_fail(A is B)))).
ghc(prolog(P)) :-
    !,
    ghc_trace(ghc(prolog(P))),
    (call(P), ! ; report_fail(prolog(P))).

% 組み込み述語でないなら GHC プログラムとして解釈する。
ghc(Head) :-
    !,
    ghc_trace(ghc(Head)),
    ( functor(Head, F, N),
      findall(Clause,
              (Clause = [Copy,Body], functor(Copy, F, N), clause(Copy, Body)),
              Clauses),
      ghc_execute_clauses(_, Head, Clauses), !
    ; report_fail(Head)).
ghc_execute_clauses(_, _, []) :- !.
ghc_execute_clauses(Flag, Head, [[Copy, GuardBody]|Clauses]) :-
    !,
    always_success(ghc_execute(Flag, Head, Copy, GuardBody)),
    ghc_execute_clauses(Flag, Head, Clauses).

ghc_execute(Flag, Head, Copy, GuardBody) :-
    ghc_trace(Copy :- GuardBody),
    % 待ち合わせが必要な変数があるか調べ、あればそのリストを Waits に抽出する。
    always_success(ghc_wait_args(Head, Copy, Waits)),
    % Waits が空なら即座に実行できる。空でないなら待ち合わせが必要。
    ( Waits = []
    -> (Head = Copy -> always_success(ghc_process_guard_body(Flag, GuardBody))
       ; true)
    ; always_success(ghc_build_nonvars(Waits, NonVars)) ->
      when((nonvar(Flag) ; NonVars),
           ( nonvar(Flag)  % 完了済みなので停止
           ; ( Head = Copy
             ->
             always_success(ghc_process_guard_body(Flag, GuardBody))
             ; true)))).
% Copy が実体を要求している場合には、Head が実体か調べる。
% 実体でなければ Waits に待ち合わせ対象変数として返す。
ghc_wait_args(Head, Copy, Waits) :-
    Head =.. [_|HeadArgs],
    Copy =.. [_|CopyArgs],
    ghc_wait_args2(HeadArgs, CopyArgs, Waits).
ghc_wait_args2([], [], []).
ghc_wait_args2([H|Hs], [C|Cs], Waits) :-
    ( var(H), nonvar(C), functor(C, _, _)
    -> Waits = [H|Waits2],
       ghc_wait_args2(Hs, Cs, Waits2)
    ; ghc_wait_args2(Hs, Cs, Waits)).
% 変数リストを nonvar/1 でラップされた変数のリストとして返す。
ghc_build_nonvars([X], (nonvar(X))).
ghc_build_nonvars([X|Xs], (nonvar(X), Ys)) :-
    ghc_build_nonvars(Xs, Ys).

% 実行完了済みなら実行停止
ghc_process_guard_body(Flag, _) :- nonvar(Flag).
% ガード部先頭の取り出し
% G1,...|Body を G1 とそれ以外に分ける
ghc_process_guard_body(Flag, (G1, Gs) ; Body) :-
    !,
    ghc_process_guard_body(Flag, G1, (Gs ; Body)).
% G|Body を G と Body に分ける
ghc_process_guard_body(Flag, Guard ; Body) :-
    !,
    ghc_process_guard_body(Flag, Guard, Body).

% H :- B1,B2,...,Bn の場合
ghc_process_guard_body(Flag, Body) :-
    !,
    Flag = fired,  % 実行完了にしておく
    always_success(ghc(Body)).

% H :- true |B1,B2,...,Bn の場合
ghc_process_guard_body(Flag, true, GuardBody) :-
    !,
    always_success(ghc_process_guard_body(Flag, GuardBody)).


% H :- wait(G1) ,G2,...,Gn|B1,B2,...,Bm の場合
ghc_process_guard_body(Flag, wait(G), GuardBody) :-
    ( var(G)
    -> when((nonvar(Flag) ; nonvar(G)),
            ( nonvar(Flag)  % 完了済みなので停止
            ; always_success(ghc_process_guard_body(Flag, GuardBody))))
    ; nonvar(G)
    -> always_success(ghc_process_guard_body(Flag, GuardBody))).

% H :- G=[G1|G2] ,...,Gn|B1,B2,...,Bm の場合
ghc_process_guard_body(Flag, G1=[G2|G3], GuardBody) :-
    ( var(G1)
    -> when((nonvar(Flag) ; nonvar(G1)),
            ( nonvar(Flag)  % 完了済みなので停止
            ; ( G1=[G2|G3],
                always_success(ghc_process_guard_body(Flag, GuardBody))
              ; true)))  % ガード条件のマッチに失敗しても無視
    ; nonvar(G1)
    -> ( G1=[G2|G3],
         always_success(ghc_process_guard_body(Flag, GuardBody))
       ; true)).  % ガード条件のマッチに失敗しても無視

% passive unification
ghc_process_guard_body(Flag, G, GuardBody) :-
    term_variables(G, Vars),
    ( ghc_build_nonvars(Vars, Waits)
    -> when((nonvar(Flag) ; Waits),
            ( nonvar(Flag)  % 完了済みなので停止
            ; ( call(G),
                always_success(ghc_process_guard_body(Flag, G, GuardBody))
              ; true)))  % ガード条件のマッチに失敗しても無視
    ; Vars = []
    -> ( call(G),
         always_success(ghc_process_guard_body(Flag, GuardBody))
       ; true)).  % ガード条件のマッチに失敗しても無視

outstream([C|Cs]) :- outstream(C, Cs).
% write(P) が与えられたときには項を出力する。
outstream(write(P), Cmds) :- prolog(write(P)) -> outstream(Cmds).
% nl が与えられた時は改行を出力する。
outstream(nl, Cmds) :- prolog(nl) -> outstream(Cmds).
% ttyflush が与えられたときはフラッシュする。
outstream(ttyflush, Cmds) :- prolog(ttyflush) -> outstream(Cmds).
% told が与えられたときは outstream プロセスを終了する
outstream(told, _).

% 整数ストリーム生成
gen(N0, Max, Ns0) :-
    N0 =< Max | Ns0 = [N0 | Ns1], N1 is N0 + 1, gen(N1, Max, Ns1).
gen(N0, Max, Ns0) :-
    N0  > Max | Ns0 = [].
% 素数フィルタを適用する
sift([P|Xs1], Zs0) :-
    true | Zs0 = [P | Zs1], filter(P, Xs1, Ys), sift(Ys, Zs1).
sift([], Zs0) :-
    true | Zs0 = [].
% 素数フィルタ
filter(P, [X|Xs1], Ys0) :-
    X mod P =\= 0 | Ys0 = [X | Ys1], filter(P, Xs1, Ys1).
filter(P, [X|Xs1], Ys0) :-
    X mod P =:= 0 | filter(P, Xs1, Ys0).
filter(_, [],      Ys0) :-
    true | Ys0 = [].

% 引数に与えられたストリームを読み取り、順次カンマ区切りで出力していく。
printstream(Ps) :- outstream(Stream), printstream(Ps, Stream).
% ストリームが空なら終わり。
printstream([], Stream) :-
    true | Stream = [told].
% ストリーム先頭の出力。
printstream([P|Ps], Stream) :-
    true | Stream = [write(P), ttyflush | Stream2], printstream2(Ps, Stream2).
% ストリーム終端に達したら、出力ストリームを閉じる。
printstream2([], Stream) :-
    true | Stream = [nl, told].
% カンマ区切りで出力ストリームに出力する。
printstream2([P|Ps], Stream) :-
    true | Stream = [write(','), write(P), ttyflush | Stream2], printstream2(Ps, Stream2).

% 素数ストリームを得る
primes(Max, Ps) :- true | gen(2, Max, Ns), sift(Ns, Ps).

