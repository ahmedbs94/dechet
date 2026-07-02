"""Migration: Create testimonials and center_proposals tables."""
import sys
import os
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from database import engine
from sqlalchemy import text

def migrate():
    with engine.connect() as conn:
        # Create testimonials table
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS testimonials (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                user_name VARCHAR,
                user_avatar_url VARCHAR,
                content TEXT NOT NULL,
                rating INTEGER DEFAULT 5,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        
        # Create center_proposals table
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS center_proposals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                user_name VARCHAR,
                name VARCHAR NOT NULL,
                address VARCHAR NOT NULL,
                lat VARCHAR,
                lng VARCHAR,
                waste_types VARCHAR DEFAULT '',
                description TEXT,
                status VARCHAR DEFAULT 'pending',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        
        # Create indexes
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_testimonials_user_id ON testimonials(user_id)"))
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_center_proposals_user_id ON center_proposals(user_id)"))
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_center_proposals_status ON center_proposals(status)"))
        
        conn.commit()
        print("✅ Migration réussie: tables 'testimonials' et 'center_proposals' créées.")

if __name__ == "__main__":
    migrate()
