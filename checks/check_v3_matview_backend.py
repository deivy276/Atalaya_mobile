from sqlalchemy import text
from app.database import _ensure_session_factory
from app.config import get_settings

settings = get_settings()
SessionFactory = _ensure_session_factory()
s = SessionFactory()
try:
    print('latest_samples_summary_name =', settings.latest_samples_summary_name)
    print('db_identity =', s.execute(text('select current_database(), current_user, current_schema()')).all())
    print('matview =', s.execute(text("select schemaname, matviewname from pg_matviews where schemaname='public' and matviewname='atalaya_latest_samples_mv' order by 1,2")).all())
    print('columns =', s.execute(text("select column_name, data_type from information_schema.columns where table_schema='public' and table_name='atalaya_latest_samples_mv' order by ordinal_position")).all())
    try:
        print('row_count =', s.execute(text('select count(*) from public.atalaya_latest_samples_mv')).scalar())
        print('sample_rows =', s.execute(text('select tag_norm, actual_tag, value, created_at from public.atalaya_latest_samples_mv order by created_at desc limit 5')).all())
    except Exception as ex:
        print('row_count/sample_rows error =', repr(ex))
finally:
    s.close()
