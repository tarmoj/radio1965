"""
SQLAlchemy engine/session and ORM models for the Events DB (MySQL/MariaDB).

Schema mirrors sql/schema.sql - see that file for the raw DDL used to
create the database, so keep the two in sync when making changes.
"""

from collections.abc import Generator

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    String,
    Text,
    create_engine,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, relationship, sessionmaker

from server import config

engine = create_engine(config.DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


EVENT_TYPES = ("text", "audio", "video", "audiostream", "videostream", "article", "webcontent", "livestream")
EVENT_STATUSES = ("unpublished", "new", "shelved", "archived")


class Event(Base):
    __tablename__ = "events"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    type: Mapped[str] = mapped_column(Enum(*EVENT_TYPES, name="event_type"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    publish_at: Mapped[object] = mapped_column(DateTime, nullable=False)
    shelf_at: Mapped[object | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(
        Enum(*EVENT_STATUSES, name="event_status"), nullable=False, default="unpublished"
    )
    comments_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[object] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    tags: Mapped[list["Tag"]] = relationship(
        back_populates="event", cascade="all, delete-orphan", lazy="joined"
    )

    def to_dict(self) -> dict:
        """JSON-safe dict matching the Event schema in project-description.md."""
        return {
            "id": self.id,
            "type": self.type,
            "title": self.title,
            "summary": self.summary,
            "url": self.url,
            "publish_at": self.publish_at.isoformat(),
            "shelf_at": self.shelf_at.isoformat() if self.shelf_at else None,
            "status": self.status,
            "comments_enabled": self.comments_enabled,
            "tags": [t.tag for t in self.tags],
            "payload": self.payload or {},
        }


class Tag(Base):
    __tablename__ = "tags"

    event_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("events.id", ondelete="CASCADE"), primary_key=True
    )
    tag: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)

    event: Mapped["Event"] = relationship(back_populates="tags")


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
