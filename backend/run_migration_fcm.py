from dotenv import load_dotenv
load_dotenv('.env')
from database import engine
from sqlalchemy import text

# PostgreSQL : AUTOCOMMIT pour les commandes DDL (ALTER TABLE ne supporte pas les transactions)
with engine.connect().execution_options(isolation_level='AUTOCOMMIT') as conn:
    sql = (
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name='users' AND column_name='fcm_token'"
    )
    result = conn.execute(text(sql))
    exists = result.fetchone() is not None

    if exists:
        print('[OK] fcm_token existe deja dans PostgreSQL - rien a faire')
    else:
        conn.execute(text('ALTER TABLE users ADD COLUMN fcm_token VARCHAR'))
        print('[OK] Colonne fcm_token ajoutee avec succes dans PostgreSQL')
