# -*- coding: utf-8 -*-
"""The rules that make a six-digit SMS code a credential rather than a
formality.

Each of these is a way in if it is missing: a code that outlives its message,
a code that can be guessed all afternoon, a code that still works after it
has been used, and an endpoint that will text anyone as often as they ask --
that last one spends the school's money rather than opening an account, which
is why it is here alongside the others.
"""

from datetime import datetime, timedelta

from app.services import verification_service as verification

NOW = datetime(2026, 8, 22, 10, 0)


def _record(code="123456", *, salt="s@lt", attempts=0, consumed_at=None, expires_at=None):
    return {
        "code_salt": salt,
        "code_hash": verification.hash_secret(code, salt),
        "expires_at": expires_at or verification.expiry_from(NOW),
        "attempts": attempts,
        "consumed_at": consumed_at,
    }


def test_the_right_code_is_accepted():
    assert verification.check_code("123456", now=NOW, **_record()).ok


def test_a_wrong_code_is_not():
    check = verification.check_code("000000", now=NOW, **_record())
    assert not check.ok
    assert check.reason == "code_invalid"


def test_a_code_expires():
    """Five minutes. The message stays in the inbox forever; the code must
    not."""
    later = NOW + verification.CODE_TTL + timedelta(seconds=1)
    check = verification.check_code("123456", now=later, **_record())
    assert not check.ok
    assert check.reason == "code_expired"


def test_a_used_code_cannot_be_used_again():
    check = verification.check_code("123456", now=NOW, **_record(consumed_at=NOW))
    assert not check.ok
    assert check.reason == "code_already_used"


def test_guessing_runs_out():
    """Without this a six-digit code is a million tries away from anyone."""
    check = verification.check_code(
        "123456", now=NOW, **_record(attempts=verification.MAX_ATTEMPTS)
    )
    assert not check.ok
    assert check.reason == "too_many_attempts"


def test_the_last_allowed_attempt_still_counts():
    check = verification.check_code(
        "123456", now=NOW, **_record(attempts=verification.MAX_ATTEMPTS - 1)
    )
    assert check.ok


def test_sending_is_capped_per_hour():
    assert verification.may_send_code(0)
    assert verification.may_send_code(verification.MAX_CODES_PER_HOUR - 1)
    assert not verification.may_send_code(verification.MAX_CODES_PER_HOUR)


def test_codes_are_six_digits_and_not_all_the_same():
    codes = {verification.generate_code() for _ in range(200)}
    assert all(len(code) == verification.CODE_LENGTH and code.isdigit() for code in codes)
    # A generator stuck on one value would pass every other test here.
    assert len(codes) > 150


def test_a_password_verifies_against_its_own_hash_only():
    salt, digest = verification.hash_password("bolam2026")
    assert verification.verify_password("bolam2026", salt, digest)
    assert not verification.verify_password("bolam2027", salt, digest)


def test_a_parent_without_a_password_verifies_nothing():
    """The 61 parents registered before passwords existed have null columns,
    and null must never mean "any password will do"."""
    assert not verification.verify_password("", None, None)
    assert not verification.verify_password("anything", None, None)
    assert not verification.verify_password("anything", "salt", None)


def test_the_echoed_number_is_masked():
    """Enough for a parent to recognise their own number, not enough to
    confirm someone else's to whoever asked."""
    masked = verification.mask_phone("992987644002")
    assert masked.endswith("40 02")
    assert "987644" not in masked


def test_the_code_table_stamps_its_own_time_in_utc():
    """Not the database's clock.

    Postgres on this machine returns local time from now() while every check
    here works in UTC. A database-stamped created_at therefore looked five
    hours into the future, the hourly send limit counted stale rows as fresh,
    and invitations stopped going out for the rest of the day -- with no
    error anywhere, which is what made it expensive to find.
    """
    from datetime import datetime

    from app.models.verification_code_model import VerificationCode

    column = VerificationCode.__table__.c.created_at
    assert column.server_default is None, "the database must not stamp this"
    assert column.default is not None, "something has to stamp it"

    # Checked by what it produces rather than which function it is: a local
    # clock would be hours off, and that is the failure that mattered.
    stamped = column.default.arg({})
    assert abs((stamped - datetime.utcnow()).total_seconds()) < 5
