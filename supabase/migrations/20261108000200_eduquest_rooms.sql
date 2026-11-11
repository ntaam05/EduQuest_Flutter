begin;

create table eduquest_app.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z2-9]{6}$'),
  host_id uuid not null references eduquest_app.profiles(id) on delete cascade,
  quiz_id uuid not null references eduquest_app.quizzes(id) on delete cascade,
  max_players integer not null check (max_players between 2 and 100),
  duration_minutes integer not null check (duration_minutes between 1 and 300),
  question_duration_seconds integer not null check (question_duration_seconds between 20 and 30),
  status text not null default 'waiting' check (status in ('waiting','playing','showingresults','finished')),
  round_no integer not null default 0,
  question_started_at timestamptz,
  deadline timestamptz,
  created_at timestamptz not null default now()
);
create index eduquest_room_due on eduquest_app.rooms(deadline) where status in ('playing','showingresults');
create index eduquest_room_quiz on eduquest_app.rooms(quiz_id);

create table eduquest_app.room_members (
  room_id uuid not null references eduquest_app.rooms(id) on delete cascade,
  user_id uuid not null references eduquest_app.profiles(id) on delete cascade,
  score integer not null default 0,
  correct_answers integer not null default 0,
  primary key(room_id, user_id)
);
create index eduquest_room_member_user on eduquest_app.room_members(user_id);

create table eduquest_app.room_answers (
  room_id uuid not null,
  user_id uuid not null,
  question_id bigint not null references eduquest_app.questions(id) on delete cascade,
  selected_index integer not null,
  is_correct boolean not null,
  points integer not null,
  elapsed_ms integer not null,
  primary key(room_id, question_id, user_id),
  foreign key(room_id, user_id) references eduquest_app.room_members(room_id, user_id) on delete cascade
);

-- Realtime sends a revision only. Authorized clients fetch a personalized snapshot via RPC.
create table public.eduquest_room_updates (
  room_id uuid primary key references eduquest_app.rooms(id) on delete cascade,
  revision bigint not null default 1
);
alter table public.eduquest_room_updates enable row level security;
revoke all on public.eduquest_room_updates from public, anon, authenticated;
grant select on public.eduquest_room_updates to authenticated;

create function public.eduquest_room_member(p_room_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from eduquest_app.room_members m where m.room_id = p_room_id and m.user_id = auth.uid())
$$;
revoke all on function public.eduquest_room_member(uuid) from public, anon, authenticated, service_role;
grant execute on function public.eduquest_room_member(uuid) to authenticated;
create policy eduquest_room_updates_for_members on public.eduquest_room_updates
  for select to authenticated using (public.eduquest_room_member(room_id));

do $$
begin
  if not exists(select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists(select 1 from pg_publication_tables where pubname = 'supabase_realtime'
    and schemaname = 'public' and tablename = 'eduquest_room_updates') then
    alter publication supabase_realtime add table public.eduquest_room_updates;
  end if;
end;
$$;

create function eduquest_app.touch_room(p_room uuid)
returns void language sql set search_path = '' as $$
  insert into public.eduquest_room_updates(room_id) values (p_room)
  on conflict (room_id) do update set revision = eduquest_room_updates.revision + 1
$$;

create function eduquest_app.leaderboard(p_room uuid)
returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by rank), '[]')
  from (
    select row_number() over(order by m.score desc, m.correct_answers desc, p.name, m.user_id) rank,
      m.user_id, p.name, p.avatar_emoji, m.score, m.correct_answers
    from eduquest_app.room_members m join eduquest_app.profiles p on p.id = m.user_id
    where m.room_id = p_room
  ) r
$$;

create function eduquest_app.room_json(r eduquest_app.rooms)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', r.id, 'code', r.code, 'status', r.status, 'quiz_id', r.quiz_id,
    'quiz_title', q.title, 'host', jsonb_build_object('id', h.id, 'name', h.name, 'avatar_emoji', h.avatar_emoji),
    'max_players', r.max_players, 'duration_minutes', r.duration_minutes,
    'question_duration_seconds', r.question_duration_seconds,
    'current_round_number', r.round_no, 'current_question_index', r.round_no - 1,
    'current_players', jsonb_array_length(leader.players), 'players', (
      select coalesce(jsonb_agg(value || jsonb_build_object('id', value->'user_id')), '[]')
      from jsonb_array_elements(leader.players)
    )
  )
  from eduquest_app.quizzes q join eduquest_app.profiles h on h.id = r.host_id
  cross join lateral (select eduquest_app.leaderboard(r.id) players) leader
  where q.id = r.quiz_id
$$;

create function eduquest_app.advance_room(p_room uuid)
returns eduquest_app.rooms language plpgsql set search_path = '' as $$
declare
  room eduquest_app.rooms;
  question_id_at_round bigint;
  changed boolean := false;
  current_time_utc timestamptz;
begin
  select r.* into room from eduquest_app.rooms r where r.id = p_room for update;
  current_time_utc := clock_timestamp();
  while room.deadline <= current_time_utc and room.status in ('playing','showingresults') loop
    if room.status = 'playing' then
      select id into question_id_at_round from eduquest_app.questions
      where quiz_id = room.quiz_id and position = room.round_no;
      update eduquest_app.room_members m
      set score = m.score + a.points, correct_answers = m.correct_answers + a.is_correct::integer
      from eduquest_app.room_answers a
      where a.room_id = room.id and a.question_id = question_id_at_round and m.room_id = a.room_id and m.user_id = a.user_id;
      room.status := 'showingresults';
      room.deadline := room.deadline + interval '5 seconds';
    elsif exists(select 1 from eduquest_app.questions q where q.quiz_id = room.quiz_id and q.position = room.round_no + 1) then
      room.status := 'playing';
      room.round_no := room.round_no + 1;
      room.question_started_at := room.deadline;
      room.deadline := room.deadline + make_interval(secs => room.question_duration_seconds);
    else
      room.status := 'finished';
      room.deadline := null;
    end if;
    changed := true;
  end loop;
  if changed then
    update eduquest_app.rooms set status = room.status, round_no = room.round_no,
      question_started_at = room.question_started_at, deadline = room.deadline where id = p_room;
    perform eduquest_app.touch_room(p_room);
  end if;
  return room;
end;
$$;

create function eduquest_app.tick_rooms()
returns void language plpgsql set search_path = '' as $$
declare
  due_id uuid;
begin
  for due_id in select r.id from eduquest_app.rooms r
    where r.status in ('playing','showingresults') and r.deadline <= now()
    order by r.deadline limit 100 for update skip locked
  loop
    perform eduquest_app.advance_room(due_id);
  end loop;
end;
$$;

create function eduquest_app.room_snapshot(r eduquest_app.rooms, p_user uuid)
returns jsonb language plpgsql stable set search_path = '' as $$
declare
  snapshot jsonb;
  rankings jsonb := eduquest_app.leaderboard(r.id);
  question eduquest_app.questions;
  options_json jsonb;
  answer_index integer;
  answered_count integer;
  question_count integer;
begin
  snapshot := jsonb_build_object(
    'mode', case r.status when 'waiting' then 'lobby' when 'playing' then 'question'
               when 'showingresults' then 'results' else 'finished' end,
    'room', eduquest_app.room_json(r), 'leaderboard', rankings, 'server_time', statement_timestamp());
  if r.status not in ('playing','showingresults') then return snapshot; end if;

  select q.* into question from eduquest_app.questions q where q.quiz_id = r.quiz_id and q.position = r.round_no;
  select count(*) into question_count from eduquest_app.questions q where q.quiz_id = r.quiz_id;
  select jsonb_agg(jsonb_build_object('index', ordinality - 1, 'text', value) order by ordinality)
    into options_json from unnest(question.options) with ordinality as opt(value, ordinality);
  select count(*), max(a.selected_index) filter (where a.user_id = p_user) into answered_count, answer_index
    from eduquest_app.room_answers a where a.room_id = r.id and a.question_id = question.id;

  if r.status = 'playing' then
    return snapshot || jsonb_build_object(
      'question_event', jsonb_build_object(
        'room_id', r.id, 'question_number', r.round_no, 'current_round_number', r.round_no,
        'question_count', question_count, 'question_duration_seconds', r.question_duration_seconds,
        'total_players', jsonb_array_length(rankings), 'started_at', r.question_started_at, 'ends_at', r.deadline,
        'question', jsonb_build_object('id', question.id, 'text', question.question, 'options', options_json)),
      'has_answered', answer_index is not null, 'my_answer_index', answer_index, 'answered_count', answered_count);
  end if;

  return snapshot || jsonb_build_object('result', jsonb_build_object(
    'room_id', r.id, 'question_id', question.id, 'question_number', r.round_no, 'question_count', question_count,
    'question_text', question.question, 'options', options_json, 'correct_answer_index', question.correct_answer,
    'correct_answer_text', question.options[question.correct_answer + 1], 'explanation', question.explanation,
    'answered_count', answered_count, 'total_players', jsonb_array_length(rankings),
    'leaderboard', rankings, 'results_duration_seconds', 5,
    'round_scores', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', m.user_id, 'name', p.name, 'avatar_emoji', p.avatar_emoji,
        'answered', a.user_id is not null, 'selected_answer_index', a.selected_index,
        'is_correct', coalesce(a.is_correct,false), 'points_earned', coalesce(a.points,0), 'elapsed_milliseconds', a.elapsed_ms
      ) order by coalesce(a.points,0) desc, a.elapsed_ms nulls last, p.name, m.user_id), '[]')
      from eduquest_app.room_members m join eduquest_app.profiles p on p.id = m.user_id
      left join eduquest_app.room_answers a on a.room_id = m.room_id and a.user_id = m.user_id and a.question_id = question.id
      where m.room_id = r.id
    )
  ));
end;
$$;

create function public.eduquest_rooms(p_action text, p_input jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  room eduquest_app.rooms;
  question eduquest_app.questions;
  quiz_id_input uuid;
  question_id_input bigint;
  member boolean;
  code_value text;
  player_count integer;
  selected integer;
  previous_answer integer;
  is_correct boolean;
  elapsed integer;
  points integer;
  request_time timestamptz;
begin
  if me is null then raise sqlstate 'PT401' using message = 'Bạn chưa đăng nhập.'; end if;

  if p_action = 'list' then
    return (select coalesce(jsonb_agg(eduquest_app.room_json(r) order by created_at desc, id), '[]')
            from eduquest_app.rooms r where status <> 'finished');
  end if;

  if p_action = 'create' then
    quiz_id_input := (p_input->>'quiz_id')::uuid;
    perform 1 from eduquest_app.quizzes where id = quiz_id_input for key share;
    if not found or not exists(select 1 from eduquest_app.questions where quiz_id = quiz_id_input) then
      raise sqlstate 'PT409' using message = 'Bài thi chưa có câu hỏi.';
    end if;
    for i in 1..20 loop
      select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random()*32)::int + 1, 1), '')
      into code_value from generate_series(1,6);
      insert into eduquest_app.rooms(code, host_id, quiz_id, max_players, duration_minutes, question_duration_seconds)
      values (code_value, me, quiz_id_input, (p_input->>'max_players')::int, (p_input->>'duration_minutes')::int,
              coalesce((p_input->>'question_duration_seconds')::int,25))
      on conflict (code) do nothing returning * into room;
      exit when found;
    end loop;
    if room.id is null then raise sqlstate 'PT409' using message = 'Chưa tạo được mã phòng, vui lòng thử lại.'; end if;
    insert into eduquest_app.room_members(room_id,user_id) values (room.id,me);
    perform eduquest_app.touch_room(room.id);
    return eduquest_app.room_json(room);
  end if;

  if p_action = 'by_code' then
    select r.* into room from eduquest_app.rooms r where r.code = upper(btrim(p_input->>'code'));
  elsif p_action = 'join' then
    select r.* into room from eduquest_app.rooms r where r.code = upper(btrim(p_input->>'code')) for update;
  elsif p_action in ('get','state') then
    select r.* into room from eduquest_app.rooms r where r.id = (p_input->>'room_id')::uuid;
  elsif p_action in ('start','answer','leave') then
    select r.* into room from eduquest_app.rooms r where r.id = (p_input->>'room_id')::uuid for update;
  else
    raise sqlstate 'PT404' using message = 'Thao tác phòng thi không tồn tại.';
  end if;
  if room.id is null then raise sqlstate 'PT404' using message = 'Không tìm thấy phòng.'; end if;
  select exists(select 1 from eduquest_app.room_members m where m.room_id = room.id and m.user_id = me) into member;
  if p_action in ('state','start','answer','leave') and not member then
    raise sqlstate 'PT403' using message = 'Bạn không phải thành viên của phòng.';
  end if;
  if p_action in ('get','by_code','state') and room.deadline <= clock_timestamp() then
    room := eduquest_app.advance_room(room.id);
    if room.id is null then raise sqlstate 'PT404' using message = 'Không tìm thấy phòng.'; end if;
  end if;

  case p_action
    when 'get', 'by_code' then
      return eduquest_app.room_json(room);
    when 'state' then
      return eduquest_app.room_snapshot(room, me);
    when 'join' then
      if not member then
        if room.status <> 'waiting' then raise sqlstate 'PT409' using message = 'Trận đã bắt đầu.'; end if;
        select count(*) into player_count from eduquest_app.room_members where room_id = room.id;
        if player_count >= room.max_players then raise sqlstate 'PT409' using message = 'Phòng đã đầy.'; end if;
        insert into eduquest_app.room_members(room_id,user_id) values (room.id,me);
        perform eduquest_app.touch_room(room.id);
      end if;
      return eduquest_app.room_json(room);
    when 'leave' then
      if room.status in ('playing','showingresults') then
        raise sqlstate 'PT409' using message = 'Trận đang diễn ra. Bạn có thể vào lại phòng.';
      end if;
      if room.status = 'waiting' then
        if room.host_id = me then
          delete from eduquest_app.rooms where id = room.id;
        else
          delete from eduquest_app.room_members where room_id = room.id and user_id = me;
          perform eduquest_app.touch_room(room.id);
        end if;
      end if;
      return '{}';
    when 'start' then
      if room.host_id <> me then raise sqlstate 'PT403' using message = 'Chỉ chủ phòng mới được bắt đầu.'; end if;
      if room.status <> 'waiting' then raise sqlstate 'PT409' using message = 'Phòng không còn ở trạng thái chờ.'; end if;
      request_time := clock_timestamp();
      update eduquest_app.rooms set status = 'playing', round_no = 1, question_started_at = request_time,
        deadline = request_time + make_interval(secs => room.question_duration_seconds)
      where id = room.id returning * into room;
      perform eduquest_app.touch_room(room.id);
      return eduquest_app.room_json(room);
    when 'answer' then
      question_id_input := (p_input->>'question_id')::bigint;
      selected := (p_input->>'selected_answer_index')::int;
      select a.selected_index into previous_answer from eduquest_app.room_answers a
        where a.room_id = room.id and a.question_id = question_id_input and a.user_id = me;
      if found then
        if previous_answer = selected then return '{"accepted":true}'; end if;
        raise sqlstate 'PT409' using message = 'Bạn đã chốt đáp án cho câu này.';
      end if;
      request_time := clock_timestamp();
      if room.status <> 'playing' or request_time >= room.deadline then
        raise sqlstate 'PT409' using message = 'Câu hỏi hiện tại đã hết giờ.';
      end if;
      select q.* into question from eduquest_app.questions q where q.quiz_id = room.quiz_id and q.position = room.round_no;
      if question_id_input is distinct from question.id or selected is null or selected < 0 or selected >= cardinality(question.options) then
        raise sqlstate 'PT400' using message = 'Câu hỏi hoặc phương án trả lời không hợp lệ.';
      end if;
      elapsed := greatest(0, floor(extract(epoch from request_time - room.question_started_at) * 1000)::integer);
      is_correct := selected = question.correct_answer;
      points := case when is_correct then greatest(100, 1000 - floor(elapsed * 0.9 / room.question_duration_seconds)::integer) else 0 end;
      insert into eduquest_app.room_answers(room_id,user_id,question_id,selected_index,is_correct,points,elapsed_ms)
      values (room.id,me,question.id,selected,is_correct,points,elapsed);
      perform eduquest_app.touch_room(room.id);
      return '{"accepted":true}';
  end case;
exception when check_violation or not_null_violation or invalid_text_representation or numeric_value_out_of_range then
  raise sqlstate 'PT400' using message = 'Dữ liệu phòng thi không hợp lệ.';
end;
$$;

create function public.eduquest_delete_quiz(p_user_id uuid, p_quiz_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  owner uuid;
  file_path text;
begin
  select owner_id into owner from eduquest_app.quizzes where id = p_quiz_id for update;
  if not found then raise sqlstate 'PT404' using message = 'Không tìm thấy bài trắc nghiệm.'; end if;
  if owner is null or owner is distinct from p_user_id then
    raise sqlstate 'PT403' using message = 'Chỉ người tạo bài mới được xóa.';
  end if;
  if exists(select 1 from eduquest_app.rooms where quiz_id = p_quiz_id and status <> 'finished') then
    raise sqlstate 'PT409' using message = 'Bài đang được dùng trong một phòng thi chưa kết thúc.';
  end if;
  select object_path into file_path from eduquest_app.uploads where quiz_id = p_quiz_id;
  delete from eduquest_app.quizzes where id = p_quiz_id;
  return jsonb_build_object('object_path', file_path);
end;
$$;

revoke all on function public.eduquest_rooms(text, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.eduquest_rooms(text, jsonb) to authenticated;
revoke all on function public.eduquest_delete_quiz(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.eduquest_delete_quiz(uuid, uuid) to service_role;
commit;
