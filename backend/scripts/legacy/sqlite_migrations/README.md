# Scripts de migration SQLite — LEGACY / OBSOLÈTES

Ces scripts ont été créés avant la mise en place d'Alembic comme système
de migration officiel. Ils utilisent `sqlite3` directement et sont
**incompatibles avec PostgreSQL**.

## Pourquoi ils sont archivés ici

- Ils ne doivent **pas** être exécutés sur une base PostgreSQL
- Ils sont conservés pour référence historique uniquement
- Les migrations équivalentes existent dans `../alembic/versions/`

## Migration officielle

Toutes les migrations doivent utiliser **Alembic** :

```bash
# Appliquer toutes les migrations
alembic upgrade head

# Voir l'état actuel
alembic current

# Créer une nouvelle migration
alembic revision --autogenerate -m "description"
```

## Correspondance anciens scripts → migrations Alembic

| Script legacy | Migration Alembic |
|---|---|
| `migrate_notifications.py` | `0007_add_notification_reply_fields.py` |
| `migrate_smart_bins.py` | `0001_initial_schema.py` |
| `migrate_collector_logs.py` | `0005_add_actor_tables.py` |
| `migrate_mfa.py` / `migrate_otp.py` | `0001_initial_schema.py` |
| `migrate_educator_videos.py` | `0005_add_actor_tables.py` |
