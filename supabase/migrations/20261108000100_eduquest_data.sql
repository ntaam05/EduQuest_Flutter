begin;

create schema eduquest_app;
revoke all on schema eduquest_app from public, anon, authenticated;

create table eduquest_app.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  avatar_url text check (char_length(avatar_url) <= 500),
  avatar_emoji text not null default '👤' check (char_length(avatar_emoji) between 1 and 16),
  dark_mode boolean not null default false,
  notifications_enabled boolean not null default true,
  language text not null default 'vi' check (language in ('vi','en')),
  created_at timestamptz not null default now()
);

create function eduquest_app.on_auth_signup()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into eduquest_app.profiles(id, name)
  values (new.id, coalesce(nullif(left(btrim(new.raw_user_meta_data->>'name'), 120), ''), 'Người học'))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger eduquest_create_profile after insert on auth.users
for each row execute function eduquest_app.on_auth_signup();

insert into eduquest_app.profiles(id, name)
select id, coalesce(nullif(left(btrim(raw_user_meta_data->>'name'), 120), ''), 'Người học')
from auth.users on conflict (id) do nothing;

create table eduquest_app.quizzes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references eduquest_app.profiles(id) on delete set null,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  subject text not null check (char_length(btrim(subject)) between 1 and 100),
  description text check (char_length(description) <= 2000),
  duration_minutes integer not null default 15 check (duration_minutes between 1 and 300),
  icon_emoji text check (char_length(icon_emoji) <= 16),
  created_at timestamptz not null default now()
);

create table eduquest_app.questions (
  id bigint generated always as identity primary key,
  quiz_id uuid not null references eduquest_app.quizzes(id) on delete cascade,
  position integer not null check (position > 0),
  question text not null check (char_length(btrim(question)) between 1 and 3000),
  options text[] not null check (cardinality(options) between 2 and 21),
  correct_answer integer not null check (correct_answer >= 0 and correct_answer < cardinality(options)),
  explanation text check (char_length(explanation) <= 3000),
  unique (quiz_id, position)
);

create table eduquest_app.attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references eduquest_app.profiles(id) on delete cascade,
  quiz_id uuid not null references eduquest_app.quizzes(id) on delete cascade,
  started_at timestamptz not null default clock_timestamp(),
  submitted_at timestamptz,
  answers jsonb not null default '{}',
  correct_answers integer not null default 0,
  total_questions integer not null,
  score_percent numeric(5,2) not null default 0,
  time_spent_seconds integer not null default 0
);
create index eduquest_attempt_user_quiz on eduquest_app.attempts(user_id, quiz_id, started_at desc);
create index eduquest_attempt_quiz on eduquest_app.attempts(quiz_id);
create index eduquest_attempt_user_submitted on eduquest_app.attempts(user_id, submitted_at desc)
where submitted_at is not null;

create table eduquest_app.uploads (
  id bigint generated always as identity primary key,
  owner_id uuid not null references eduquest_app.profiles(id) on delete cascade,
  quiz_id uuid not null unique references eduquest_app.quizzes(id) on delete cascade,
  original_name text not null check (char_length(original_name) between 1 and 255),
  object_path text not null unique,
  extension text not null check (extension in ('txt','pdf','docx','xlsx')),
  size_bytes bigint not null check (size_bytes between 1 and 10485760),
  uploaded_at timestamptz not null default now()
);
create index eduquest_upload_owner on eduquest_app.uploads(owner_id, uploaded_at desc);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('eduquest-documents', 'eduquest-documents', false, 10485760, array['application/octet-stream']);

-- Quiz keys, profiles and submissions stay private. Only the RPCs below are exposed.
create function eduquest_app.quiz_json(p_quiz eduquest_app.quizzes, p_user uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', p_quiz.id, 'title', p_quiz.title, 'subject', p_quiz.subject,
    'description', p_quiz.description, 'duration_minutes', p_quiz.duration_minutes,
    'created_at', p_quiz.created_at, 'icon_emoji', p_quiz.icon_emoji,
    'is_owner', coalesce(p_quiz.owner_id = p_user, false),
    'status', case when a.id is null then 'notStarted' when a.submitted_at is null then 'inProgress' else 'completed' end,
    'last_score', case when a.submitted_at is not null then a.score_percent / 10 end,
    'progress', case when a.submitted_at is null then 0 else 1 end,
    'question_count', jsonb_array_length(q.items), 'questions', q.items
  )
  from lateral (
    select coalesce(jsonb_agg(jsonb_build_object('id', id, 'question', question, 'options', options) order by position), '[]') items
    from eduquest_app.questions where quiz_id = p_quiz.id
  ) q
  left join lateral (
    select id, submitted_at, score_percent from eduquest_app.attempts
    where user_id = p_user and quiz_id = p_quiz.id order by started_at desc, id desc limit 1
  ) a on true
$$;

create function eduquest_app.profile_json(p_user uuid)
returns jsonb language sql stable set search_path = '' as $$
  select to_jsonb(p) || jsonb_build_object(
    'role', 'Student', 'total_quizzes', a.total_quizzes, 'total_questions', a.total_questions,
    'average_score', a.average_score, 'xp', a.xp, 'streak_days', s.streak_days
  )
  from eduquest_app.profiles p
  cross join lateral (
    select count(*) total_quizzes, coalesce(sum(total_questions), 0) total_questions,
           coalesce(round(avg(score_percent), 2), 0) average_score, coalesce(sum(round(score_percent)), 0) xp
    from eduquest_app.attempts where user_id = p.id and submitted_at is not null
  ) a
  cross join lateral (
    with days as (
      select distinct (submitted_at at time zone 'UTC')::date as study_day
      from eduquest_app.attempts where user_id = p.id and submitted_at is not null
    ), ordered as (
      select study_day, (row_number() over(order by study_day desc) - 1)::integer offset_days from days
    )
    select count(*) streak_days from ordered
    where study_day = (select max(study_day) from days) - offset_days
      and (select max(study_day) from days) >= (now() at time zone 'UTC')::date - 1
  ) s
  where p.id = p_user
$$;

create function eduquest_app.insert_quiz(p_user uuid, p_input jsonb, p_draft boolean default false)
returns eduquest_app.quizzes language plpgsql set search_path = '' as $$
declare
  quiz eduquest_app.quizzes;
  item jsonb;
  opts text[];
  answer_index integer;
  item_position integer := 0;
  title text := btrim(p_input->>'title');
  subject text := btrim(p_input->>'subject');
begin
  if coalesce(char_length(title), 0) not between 1 and 200 or coalesce(char_length(subject), 0) not between 1 and 100 then
    raise sqlstate 'PT400' using message = 'Vui lòng nhập tên bài và môn học hợp lệ.';
  end if;
  if jsonb_typeof(p_input->'questions') is distinct from 'array' then
    raise sqlstate 'PT400' using message = 'Danh sách câu hỏi không hợp lệ.';
  end if;
  if (not p_draft and jsonb_array_length(p_input->'questions') = 0) or jsonb_array_length(p_input->'questions') > 300 then
    raise sqlstate 'PT400' using message = 'Bài thi cần từ 1 đến 300 câu hỏi.';
  end if;
  insert into eduquest_app.quizzes(owner_id, title, subject, description, duration_minutes, icon_emoji)
  values (p_user, title, subject, nullif(btrim(p_input->>'description'), ''),
          coalesce((p_input->>'duration_minutes')::integer, 15), coalesce(p_input->>'icon_emoji','📝'))
  returning * into quiz;

  for item in select value from jsonb_array_elements(p_input->'questions') loop
    item_position := item_position + 1;
    if jsonb_typeof(item->'options') is distinct from 'array' then
      raise sqlstate 'PT400' using message = 'Danh sách phương án không hợp lệ.';
    end if;
    select array_agg(btrim(value->>'text') order by ordinality)
    into opts from jsonb_array_elements(item->'options') with ordinality;
    answer_index := (item->>'correct_answer_index')::integer;
    if coalesce(cardinality(opts), 0) not between 2 and 21
      or exists(select 1 from unnest(opts) o where coalesce(char_length(o), 0) not between 1 and 1000)
      or answer_index is null or answer_index < 0 or answer_index >= cardinality(opts) then
      raise sqlstate 'PT400' using message = format('Phương án hoặc đáp án của câu %s không hợp lệ.', item_position);
    end if;
    insert into eduquest_app.questions(quiz_id, position, question, options, correct_answer, explanation)
    values (quiz.id, item_position, btrim(item->>'text'), opts, answer_index, nullif(btrim(item->>'explanation'), ''));
  end loop;
  return quiz;
end;
$$;

create function eduquest_app.attempt_result(a eduquest_app.attempts)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'quiz_id', a.quiz_id, 'correct_answers', a.correct_answers, 'total_questions', a.total_questions,
    'score_percent', a.score_percent, 'score_out_of_10', round(a.score_percent / 10, 2),
    'time_spent_seconds', a.time_spent_seconds, 'answers', a.answers, 'submitted_at', a.submitted_at,
    'xp_earned', round(a.score_percent),
    'review_questions', (
      select jsonb_agg(jsonb_build_object('id', id, 'correct_answer', correct_answer, 'explanation', explanation) order by position)
      from eduquest_app.questions where quiz_id = a.quiz_id
    )
  )
$$;

create function public.eduquest_data(p_action text, p_input jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  quiz eduquest_app.quizzes;
  attempt eduquest_app.attempts;
  quiz_id_input uuid;
  answers_input jsonb;
  correct_count integer;
  question_count integer;
  current_time_utc timestamptz;
  new_name text;
begin
  if me is null then raise sqlstate 'PT401' using message = 'Bạn chưa đăng nhập.'; end if;

  case p_action
    when 'profile_get' then
      return eduquest_app.profile_json(me);
    when 'profile_update' then
      new_name := btrim(p_input->>'name');
      update eduquest_app.profiles set
        name = coalesce(new_name, name),
        avatar_url = coalesce(p_input->>'avatar_url', avatar_url),
        avatar_emoji = coalesce(p_input->>'avatar_emoji', avatar_emoji),
        dark_mode = coalesce((p_input->>'dark_mode')::boolean, dark_mode),
        notifications_enabled = coalesce((p_input->>'notifications_enabled')::boolean, notifications_enabled),
        language = coalesce(p_input->>'language', language)
      where id = me;
      if new_name is not null then
        update auth.users set raw_user_meta_data = coalesce(raw_user_meta_data,'{}') || jsonb_build_object('name', new_name)
        where id = me;
      end if;
      return eduquest_app.profile_json(me);
    when 'profile_stats' then
      return (
        select jsonb_build_object(
          'weekly_completed', count(*) filter (where submitted_at >= now() - interval '7 days'),
          'total_study_hours', round(coalesce(sum(time_spent_seconds),0) / 3600.0, 2),
          'weekly_scores', coalesce(jsonb_agg(jsonb_build_object('date', submitted_at, 'score', score_percent)
             order by submitted_at) filter (where submitted_at >= now() - interval '7 days'), '[]'))
        from eduquest_app.attempts where user_id = me and submitted_at is not null
      );
    when 'quiz_list' then
      return (select coalesce(jsonb_agg(eduquest_app.quiz_json(q, me) order by created_at desc, id), '[]')
              from eduquest_app.quizzes q where exists(select 1 from eduquest_app.questions x where x.quiz_id = q.id));
    when 'quiz_get' then
      select q.* into quiz from eduquest_app.quizzes q where q.id = (p_input->>'quiz_id')::uuid
        and (q.owner_id = me or exists(select 1 from eduquest_app.questions x where x.quiz_id = q.id));
      if not found then raise sqlstate 'PT404' using message = 'Không tìm thấy bài trắc nghiệm.'; end if;
      return eduquest_app.quiz_json(quiz, me);
    when 'quiz_create' then
      quiz := eduquest_app.insert_quiz(me, p_input);
      return eduquest_app.quiz_json(quiz, me);
    when 'attempt_start' then
      quiz_id_input := (p_input->>'quiz_id')::uuid;
      select count(*) into question_count from eduquest_app.questions where quiz_id = quiz_id_input;
      if question_count = 0 then raise sqlstate 'PT409' using message = 'Bài thi chưa có câu hỏi.'; end if;
      insert into eduquest_app.attempts(user_id, quiz_id, total_questions) values (me, quiz_id_input, question_count)
      returning * into attempt;
      return jsonb_build_object('id', attempt.id, 'quiz_id', quiz_id_input,
                                'started_at', attempt.started_at, 'total_questions', attempt.total_questions);
    when 'attempt_submit' then
      select a.* into attempt from eduquest_app.attempts a where a.id = (p_input->>'attempt_id')::bigint and a.user_id = me for update;
      if not found then raise sqlstate 'PT404' using message = 'Không tìm thấy lượt làm bài.'; end if;
      if attempt.submitted_at is not null then return eduquest_app.attempt_result(attempt); end if;
      answers_input := p_input->'answers';
      if jsonb_typeof(answers_input) is distinct from 'object' then
        raise sqlstate 'PT400' using message = 'Danh sách câu trả lời không hợp lệ.';
      end if;
      if exists (
        select 1 from jsonb_each_text(answers_input) a
        left join eduquest_app.questions q on q.id::text = a.key and q.quiz_id = attempt.quiz_id
        where q.id is null or a.value is null or a.value !~ '^(0|[1-9][0-9]?)$'
           or case when a.value ~ '^(0|[1-9][0-9]?)$' then a.value::integer >= cardinality(q.options) else false end
      ) then raise sqlstate 'PT400' using message = 'Đáp án gửi lên không hợp lệ.'; end if;

      select count(*) filter (where answers_input->>id::text = correct_answer::text)
      into correct_count from eduquest_app.questions where quiz_id = attempt.quiz_id;
      current_time_utc := clock_timestamp();
      update eduquest_app.attempts a set
        answers = answers_input, correct_answers = correct_count,
        score_percent = round(correct_count * 100.0 / a.total_questions, 2),
        submitted_at = current_time_utc,
        time_spent_seconds = greatest(0, least(q.duration_minutes * 60, round(extract(epoch from current_time_utc - a.started_at))::integer))
      from eduquest_app.quizzes q where a.id = attempt.id and q.id = a.quiz_id returning a.* into attempt;
      return eduquest_app.attempt_result(attempt);
    when 'attempt_list' then
      return (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', a.id, 'quiz_id', a.quiz_id, 'quiz_title', q.title,
          'started_at', a.started_at, 'submitted_at', a.submitted_at,
          'score_percent', a.score_percent, 'correct_answers', a.correct_answers,
          'total_questions', a.total_questions, 'status', case when a.submitted_at is null then 'InProgress' else 'Completed' end
        ) order by a.started_at desc, a.id desc), '[]')
        from eduquest_app.attempts a join eduquest_app.quizzes q on q.id = a.quiz_id where a.user_id = me
      );
    when 'upload_list' then
      return (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', u.id, 'original_name', u.original_name, 'extension', u.extension, 'size_bytes', u.size_bytes,
          'uploaded_at', u.uploaded_at, 'quiz_id', q.id, 'quiz_title', q.title,
          'questions_count', (select count(*) from eduquest_app.questions x where x.quiz_id = q.id)
        ) order by u.uploaded_at desc, u.id desc), '[]')
        from eduquest_app.uploads u join eduquest_app.quizzes q on q.id = u.quiz_id where u.owner_id = me
      );
    else raise sqlstate 'PT404' using message = 'Thao tác EduQuest không tồn tại.';
  end case;
exception when check_violation or not_null_violation or invalid_text_representation or numeric_value_out_of_range then
  raise sqlstate 'PT400' using message = 'Dữ liệu thiếu hoặc vượt giới hạn cho phép.';
end;
$$;

create function public.eduquest_store_upload(p_user_id uuid, p_upload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  quiz eduquest_app.quizzes;
  file_id bigint;
  count_questions integer;
begin
  if p_user_id is null or split_part(p_upload->>'object_path', '/', 1) is distinct from p_user_id::text
      or not exists(select 1 from storage.objects where bucket_id = 'eduquest-documents' and name = p_upload->>'object_path')
  then raise sqlstate 'PT400' using message = 'Tệp tải lên chưa tồn tại.'; end if;
  quiz := eduquest_app.insert_quiz(p_user_id, p_upload || '{"duration_minutes":15,"icon_emoji":"📄"}', true);
  insert into eduquest_app.uploads(owner_id, quiz_id, original_name, object_path, extension, size_bytes)
  values (p_user_id, quiz.id, p_upload->>'original_name', p_upload->>'object_path', p_upload->>'extension', (p_upload->>'size_bytes')::bigint)
  returning id into file_id;
  count_questions := jsonb_array_length(p_upload->'questions');
  return jsonb_build_object('file_id', file_id, 'quiz_id', quiz.id, 'quiz', eduquest_app.quiz_json(quiz, p_user_id),
     'questions_count', count_questions, 'status', case when count_questions = 0 then 'draft' else 'ready_for_review' end);
end;
$$;

revoke all on function public.eduquest_data(text, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.eduquest_data(text, jsonb) to authenticated;
revoke all on function public.eduquest_store_upload(uuid, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.eduquest_store_upload(uuid, jsonb) to service_role;

-- Seed the existing sample quiz subjects.
select eduquest_app.insert_quiz(null, $seed$
{"title": "Flutter Cơ Bản", "subject": "Lập trình di động", "description": "Kiểm tra kiến thức cơ bản về Flutter framework và Dart.", "duration_minutes": 15, "icon_emoji": "📱", "questions": [{"text": "Flutter được phát triển bởi công ty nào?", "options": [{"text": "Microsoft"}, {"text": "Google"}, {"text": "Apple"}, {"text": "Meta"}], "correct_answer_index": 1, "explanation": "Flutter được phát triển bởi Google."}, {"text": "Ngôn ngữ lập trình chính của Flutter là gì?", "options": [{"text": "JavaScript"}, {"text": "Kotlin"}, {"text": "Dart"}, {"text": "Swift"}], "correct_answer_index": 2, "explanation": "Flutter sử dụng Dart."}, {"text": "Widget nào sắp xếp phần tử theo chiều dọc?", "options": [{"text": "Row"}, {"text": "Stack"}, {"text": "Column"}, {"text": "Wrap"}], "correct_answer_index": 2, "explanation": "Column sắp xếp theo chiều dọc."}]}
$seed$);
select eduquest_app.insert_quiz(null, $seed$
{"title": "Cơ Sở Dữ Liệu", "subject": "Cơ sở dữ liệu", "description": "Ôn tập SQL và các khái niệm database quan trọng.", "duration_minutes": 20, "icon_emoji": "🗄️", "questions": [{"text": "SQL là viết tắt của gì?", "options": [{"text": "Structured Query Language"}, {"text": "Simple Query Logic"}, {"text": "Standard Query List"}, {"text": "System Query Language"}], "correct_answer_index": 0, "explanation": "SQL là Structured Query Language."}, {"text": "Lệnh nào dùng để lấy dữ liệu?", "options": [{"text": "INSERT"}, {"text": "UPDATE"}, {"text": "SELECT"}, {"text": "DELETE"}], "correct_answer_index": 2, "explanation": "SELECT truy vấn dữ liệu."}, {"text": "Primary Key có đặc điểm gì?", "options": [{"text": "Có thể trùng"}, {"text": "Có thể NULL"}, {"text": "Duy nhất và không NULL"}, {"text": "Chỉ dùng một bảng"}], "correct_answer_index": 2, "explanation": "Khóa chính là duy nhất và không NULL."}]}
$seed$);
select eduquest_app.insert_quiz(null, $seed$
{"title": "Lập Trình Hướng Đối Tượng", "subject": "Lập trình", "description": "Các khái niệm OOP quan trọng.", "duration_minutes": 15, "icon_emoji": "🏗️", "questions": [{"text": "Đóng gói (Encapsulation) nhằm mục đích gì?", "options": [{"text": "Ẩn và kiểm soát dữ liệu"}, {"text": "Tạo nhiều tiến trình"}, {"text": "Biên dịch code"}, {"text": "Xóa class"}], "correct_answer_index": 0, "explanation": "Đóng gói kiểm soát truy cập dữ liệu."}, {"text": "Kế thừa trong OOP cho phép?", "options": [{"text": "Một lớp kế thừa đặc điểm lớp khác"}, {"text": "Chỉ tạo biến"}, {"text": "Chỉ gọi hàm tĩnh"}, {"text": "Xóa đối tượng"}], "correct_answer_index": 0, "explanation": "Lớp con kế thừa đặc điểm từ lớp cha."}]}
$seed$);

commit;
