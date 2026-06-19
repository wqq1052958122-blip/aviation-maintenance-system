from typing import Optional

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError, OperationalError, SQLAlchemyError
from sqlalchemy.orm import Session


def extract_db_message(exc: Exception) -> str:
    """Extract a readable MySQL business/constraint error message."""
    orig = getattr(exc, "orig", None)
    args = getattr(orig, "args", None)

    if args:
        # MySQL SIGNAL SQLSTATE '45000' raised by triggers/procedures usually
        # appears through PyMySQL as error code 1644 and args[1] is MESSAGE_TEXT.
        if len(args) >= 2 and args[0] == 1644:
            return str(args[1])
        if len(args) >= 2:
            return str(args[1])
        return str(args[0])

    return str(exc)


def raise_db_error(exc: Exception, db: Optional[Session] = None) -> None:
    if db is not None:
        db.rollback()

    if isinstance(exc, (IntegrityError, OperationalError, SQLAlchemyError)):
        raise HTTPException(status_code=400, detail=extract_db_message(exc)) from exc

    raise exc
