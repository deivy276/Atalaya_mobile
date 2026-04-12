from pprint import pprint

from app.database import _ensure_session_factory
from app.repositories.atalaya_repository import AtalayaDataRepository

session_factory = _ensure_session_factory()
with session_factory() as db:
    repo = AtalayaDataRepository(db)

    print('alerts_summary_name =', repo._alerts_summary_name())
    meta = repo._alerts_summary_meta()
    print('alerts_summary_meta =', meta)

    row = db.execute(
        __import__('sqlalchemy').text(
            """
            SELECT current_database(), current_user, current_schema()
            """
        )
    ).first()
    print('db_identity =', [row] if row else [])

    mv = db.execute(
        __import__('sqlalchemy').text(
            """
            SELECT schemaname, matviewname
            FROM pg_matviews
            WHERE schemaname = 'public'
              AND matviewname = 'atalaya_alerts_feed_mv'
            """
        )
    ).all()
    print('matview =', mv)

    cols = repo._get_columns('public', 'atalaya_alerts_feed_mv')
    print('columns =', cols)

    try:
        row_count = db.execute(
            __import__('sqlalchemy').text('SELECT COUNT(*) FROM public.atalaya_alerts_feed_mv')
        ).scalar_one()
    except Exception as ex:
        row_count = f'ERROR: {ex}'
    print('row_count =', row_count)

    try:
        sample_rows = db.execute(
            __import__('sqlalchemy').text(
                'SELECT alert_id_text, raw_id_text, description, severity, created_at '
                'FROM public.atalaya_alerts_feed_mv '
                'ORDER BY created_at DESC LIMIT 10'
            )
        ).all()
    except Exception as ex:
        sample_rows = f'ERROR: {ex}'
    print('sample_rows =')
    pprint(sample_rows)

    alerts = repo.fetch_alerts_list(limit=10, fresh=True)
    print('last_alerts_source =', repo.last_alerts_source)
    print('last_alerts_text_repairs =', repo.last_alerts_text_repairs)
    print('alerts_preview =')
    pprint([a.model_dump() for a in alerts.alerts[:5]])
