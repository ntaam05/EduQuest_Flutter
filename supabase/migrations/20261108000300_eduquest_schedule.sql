begin;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule('eduquest-advance-rooms', '2 seconds', 'select eduquest_app.tick_rooms()');
select cron.schedule('eduquest-cron-history-cleanup', '17 * * * *', $job$
  delete from cron.job_run_details
  where jobid = (select jobid from cron.job where jobname = 'eduquest-advance-rooms')
    and end_time < now() - interval '2 hours'
$job$);

commit;
