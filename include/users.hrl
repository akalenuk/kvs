-include("types.hrl").

-record(user, {
        username :: username_type() | '_', %% Dialyzer and record MatchSpec warnings http://j.mp/vZ8670
        password,
        facebook_id,
        twitter_id,
        auth,
        email,
        avatar,
        name = undefined,
        surname = undefined,
        age,
        sex,
        location,
        education,
        register_date,
        status = not_verified :: user_state() | '_',
        verification_code :: string() | '_',
        zone,
        type,
        feed,
        direct,
        starred,
        pinned,
        comments,
        discussions,
        transactions,
        team,
        aclver}).

-record(user_status,{
        username :: username_type(),
        last_login,
        show_splash = true :: boolean()
        }).

-record(user_info,{
        username :: username_type(),
        name,
        surname,
        age,
        avatar_url,
        sex,
        skill = 0 :: integer(),
        score = 0 :: integer()}).

-record(user_address, {
        username :: username_type(),
        address = "",
        city = "",
        district = "",
        postal_code = "",
        phone = "",
        personal_id = "" }).

-record(user_type,{
        id,
        aclver}).

-record(subscription,{
        key,
        who,
        whom}).

-record(forget_password, {
        token :: string(),
        uid   :: string(),
        create :: {integer(), integer(), integer()}}).

-record(prohibited,{
        ip        :: {string(), atom()},
        activity  :: any(),
        time      :: {integer(),integer(),integer()},
        uid = undefined :: 'undefined' | string()}).

-record(avatar,{
        big :: string(),
        small :: string(),
        tiny :: string()}).

-record(user_game_status,{
        user,
        status  %% strings: online|offline|busy|free_for_game|invisible
        }).

-record(user_ignores, {who, whom}).
-record(user_ignores_rev, {whom, who}).

-record(twitter_oauth, {user_id, token, secret}).
-record(facebook_oauth, {user_id, access_token}).

-define(ACTIVE_USERS_TOP_N, 12).

-record(active_users_top, {
        no,
        user_id,
        entries_count,
        last_one_timestamp
        }).

-define(USER_EXCHANGE(UserId), list_to_binary("user_exchange."++UserId++".fanout")).
