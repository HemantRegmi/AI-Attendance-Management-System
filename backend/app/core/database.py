from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
from app.core.config import settings

# Async engine for FastAPI
engine_args = {
    "echo": settings.debug,
    "future": True,
}

# Only apply pooling arguments for non-SQLite databases (e.g., PostgreSQL)
# SQLite with aiosqlite/NullPool does not support these arguments.
if "sqlite" not in settings.database_url:
    engine_args.update({
        "pool_size": 10,
        "max_overflow": 20,
        "pool_timeout": 30,
        "pool_recycle": 3600,
        "pool_pre_ping": True
    })

async_engine = create_async_engine(
    settings.database_url,
    **engine_args
)

# Sync engine for Alembic migrations
sync_engine = create_engine(
    settings.database_url_sync,
    echo=settings.debug
)

# Session makers
AsyncSessionLocal = async_sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=sync_engine
)

# Base class for models
Base = declarative_base()

# Dependency to get async database session
async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

# Dependency to get sync database session (for migrations)
def get_sync_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
