-module(kvs).
-author('Maxim Sokhatsky <maxim@synrc.com>').
-include_lib("kvs/include/users.hrl").
-include_lib("kvs/include/translations.hrl").
-include_lib("kvs/include/groups.hrl").
-include_lib("kvs/include/feeds.hrl").
-include_lib("kvs/include/acls.hrl").
-include_lib("kvs/include/meetings.hrl").
-include_lib("kvs/include/invites.hrl").
-include_lib("kvs/include/config.hrl").
-include_lib("kvs/include/accounts.hrl").
-include_lib("kvs/include/log.hrl").
-include_lib("kvs/include/membership.hrl").
-include_lib("kvs/include/payments.hrl").
-include_lib("stdlib/include/qlc.hrl").
-include_lib("kvs/include/feed_state.hrl").
-compile(export_all).

start() -> DBA = ?DBA, DBA:start().
dir() -> DBA = ?DBA, DBA:dir().
stop() -> DBA = ?DBA, DBA:stop().
initialize() -> DBA = ?DBA, DBA:initialize().
delete() -> DBA = ?DBA, DBA:delete().
init_indexes() -> DBA = ?DBA, DBA:init_indexes().

traversal( _, _, undefined, _) -> [];
traversal(_, _, _, 0) -> [];
traversal(RecordType, PrevPos, Next, Count)->
    case kvs:get(RecordType, Next) of
        {error,_} -> [];
        {ok, R} ->
            Prev = element(PrevPos, R),
            Count1 = case Count of C when is_integer(C) -> C - 1; _-> Count end,
            [R | traversal(RecordType, PrevPos, Prev, Count1)]
    end.

init_db() ->
    case kvs:get(user,"joe") of
        {error,_} ->
            add_seq_ids(),
            kvs_account:create_account(system),
            add_sample_users(),
            add_sample_packages(),
            add_sample_payments(),
            add_translations();
        {ok,_} -> ignore end.

add_sample_payments() ->
    {ok, Pkg1} = kvs:get(membership,1),
    {ok, Pkg2} = kvs:get(membership,2),
    {ok, Pkg3} = kvs:get(membership,3),
    {ok, Pkg4} = kvs:get(membership,4),
    PList = [{"doxtop", Pkg1},{"maxim", Pkg2},{"maxim",Pkg4}, {"kate", Pkg3} ],
    [ok = add_payment(U, P) || {U, P} <- PList],
    ok.

add_payment(UserId, Package) ->
    {ok, MPId} = kvs_payment:add_payment(#payment{user_id=UserId, membership=Package}),
    kvs_payment:set_payment_state(MPId, ?MP_STATE_DONE, undefined).

add_seq_ids() ->
    Init = fun(Key) ->
           case kvs:get(id_seq, Key) of
                {error, _} -> ok = kvs:put(#id_seq{thing = Key, id = 0});
                {ok, _} -> ignore
           end
    end,
    Init("meeting"),
    Init("user_transaction"),
    Init("user_product"),
    Init("user_payment"),
    Init("transaction"),
    Init("membership"),
    Init("payment"),
    Init("acl"),
    Init("acl_entry"),
    Init("feed"),
    Init("entry"),
    Init("like_entry"),
    Init("likes"),
    Init("one_like"),
    Init("comment").

add_translations() ->
    lists:foreach(fun({English, Lang, Word}) ->
                          ok = kvs:put(#translation{english = English, lang = "en",  word = English}),
                          ok = kvs:put(#translation{english = English, lang = Lang,  word = Word}),
              ok
    end, ?URL_DICTIONARY).

add_sample_users() ->

    Groups = [ #group{id="Clojure"},
               #group{id="Haskell"},
               #group{id="Erlang"} ],

    UserList = [
        #user{username = "maxim", password="pass", name = "Maxim", surname = "Sokhatsky",
            feed = kvs_feed:create(), type = admin, direct = kvs_feed:create(),
            sex=m, status=ok, team = kvs_meeting:create_team("tours"),  email="maxim@synrc.com"},
        #user{username = "doxtop", password="pass", name = "Andrii", surname = "Zadorozhnii",
            feed = kvs_feed:create(), type = admin, direct = kvs_feed:create(),
            sex=m, status=ok, team = kvs_meeting:create_team("tours"),  email="doxtop@synrc.com"},
        #user{username = "alice", password="pass", name = "Alice", surname = "Imagionary",
            feed = kvs_feed:create(), type = admin, direct = kvs_feed:create(),
            sex=f, status=ok, team = kvs_meeting:create_team("tours"),  email="alice@synrc.com"},
        #user{username = "akalenuk", password="pass", name = "Alexander", surname = "Kalenuk",
            feed = kvs_feed:create(), type = admin, direct = kvs_feed:create(),
            sex=m, status=ok, team = kvs_meeting:create_team("tours"),  email="akalenuk@gmail.com"}
    ],

    kvs:put(Groups),

    {ok, Quota} = kvs:get(config,"accounts/default_quota", 300),

    [ begin
        [ kvs_group:join(Me#user.username,G#group.id) || G <- Groups ],
          kvs_account:create_account(Me#user.username),
          kvs_account:transaction(Me#user.username, quota, Quota, #tx_default_assignment{}),
          kvs:put(Me#user{password = kvs:sha(Me#user.password), starred = kvs_feed:create(), pinned = kvs_feed:create()})
      end || Me <- UserList],

    kvs_acl:define_access({user, "maxim"},    {feature, admin}, allow),
    kvs_acl:define_access({user_type, admin}, {feature, admin}, allow),

    [ kvs_user:subscribe(Me#user.username, Her#user.username) || Her <- UserList, Me <- UserList, Her /= Me ],
    [ kvs_user:init_mq(U) || U <- UserList ],

    ok.

add_sample_packages() -> kvs_membership:add_sample_data().
version() -> DBA=?DBA, DBA:version().

add_configs() ->
    %% smtp
    kvs:put(#config{key="smtp/user",     value="noreply@synrc.com"}),
    kvs:put(#config{key="smtp/password", value="maxim@synrc.com"}),
    kvs:put(#config{key="smtp/host",     value="mail.synrc.com"}),
    kvs:put(#config{key="smtp/port",     value=465}),
    kvs:put(#config{key="smtp/with_ssl", value=true}),
    kvs:put(#config{key="accounts/default_quota", value=2000}),
    kvs:put(#config{key="accounts/quota_limit/soft",  value=-30}),
    kvs:put(#config{key="accounts/quota_limit/hard",  value=-100}),
    kvs:put(#config{key="purchase/notifications/email",  value=["maxim@synrc.com"]}),
    kvs:put(#config{key="delivery/notifications/email",  value=["maxim@synrc.com"]}).

put(Record) ->
    DBA=?DBA,
    DBA:put(Record).

put_if_none_match(Record) ->
    DBA=?DBA,
    DBA:put_if_none_match(Record).

update(Record, Meta) ->
    DBA=?DBA,
    DBA:update(Record, Meta).

get(RecordName, Key) ->
    DBA=?DBA,
    DBA:get(RecordName, Key).

get_for_update(RecordName, Key) ->
    DBA=?DBA,
    DBA:get_for_update(RecordName, Key).

get(RecordName, Key, Default) ->
    DBA=?DBA,
    case DBA:get(RecordName, Key) of
        {ok,{RecordName,Key,Value}} ->
            ?INFO("db:get config value ~p,", [{RecordName, Key, Value}]),
            {ok,Value};
        {error, _B} ->
            ?INFO("db:get new config value ~p,", [{RecordName, Key, Default}]),
            DBA:put({RecordName,Key,Default}),
            {ok,Default} end.

delete(Keys) -> DBA=?DBA, DBA:delete(Keys).
delete(Tab, Key) -> ?INFO("db:delete ~p:~p",[Tab, Key]), DBA=?DBA,DBA:delete(Tab, Key).
delete_by_index(Tab, IndexId, IndexVal) -> DBA=?DBA,DBA:delete_by_index(Tab, IndexId, IndexVal).
multi_select(RecordName, Keys) -> DBA=?DBA,DBA:multi_select(RecordName, Keys).
select(From, PredicateFunction) -> ?INFO("db:select ~p, ~p",[From,PredicateFunction]), DBA=?DBA, DBA:select(From, PredicateFunction).
count(RecordName) -> DBA=?DBA,DBA:count(RecordName).
all(RecordName) -> DBA=?DBA,DBA:all(RecordName).
all_by_index(RecordName, Index, IndexValue) -> DBA=?DBA,DBA:all_by_index(RecordName, Index, IndexValue).
next_id(RecordName) -> DBA=?DBA,DBA:next_id(RecordName).
next_id(RecordName, Incr) -> DBA=?DBA,DBA:next_id(RecordName, Incr).
next_id(RecordName, Default, Incr) -> DBA=?DBA,DBA:next_id(RecordName, Default, Incr).

make_admin(User) ->
    {ok,U} = kvs:get(user, User),
    kvs:put(U#user{type = admin}),
    kvs_acl:define_access({user, U#user.username}, {feature, admin}, allow),
    kvs_acl:define_access({user_type, admin}, {feature, admin}, allow),
    ok.

make_rich(User) -> 
    Q = kvs:get_config("accounts/default_quota",  300),
    kvs_account:transaction(User, quota, Q * 100, #tx_default_assignment{}),
    kvs_account:transaction(User, internal, Q, #tx_default_assignment{}),
    kvs_account:transaction(User, currency, Q * 2, #tx_default_assignment{}).

list_to_term(String) ->
    {ok, T, _} = erl_scan:string(String++"."),
    case erl_parse:parse_term(T) of
        {ok, Term} ->
            Term;
        {error, Error} ->
            Error
    end.

save_db(Path) ->
    Data = lists:append([all(B) || B <- [list_to_term(B) || B <- store_riak:dir()] ]),
    kvs:save(Path, Data).

load_db(Path) ->
    add_seq_ids(),
    AllEntries = kvs:load(Path),
    [{_,_,{_,Handler}}] = ets:lookup(config, "riak_client"),
    [case is_tuple(E) of
        false -> skip;
        true ->  put(E) 
    end || E <- AllEntries].

make_paid_fake(UId) ->
    put(#payment{user_id=UId,info= "fake_purchase"}).

save(Key, Value) ->
    Dir = ling:trim_from_last(Key, "/"),
    filelib:ensure_dir(Dir),
    file:write_file(Key, term_to_binary(Value)).

load(Key) ->
    {ok, Bin} = file:read_file(Key),
    binary_to_term(Bin).

coalesce(undefined, B) -> B;
coalesce(A, _) -> A.

sha(Raw) ->
    lists:flatten([io_lib:format("~2.16.0b", [N]) || <<N>> <= crypto:sha(Raw)]).

sha_upper(Raw) ->
    SHA = sha(Raw),
    string:to_upper(SHA).
