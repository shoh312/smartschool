# -*- coding: utf-8 -*-
"""Who gets an invitation SMS, and what is in it.

Two rules carry the weight here. A parent who already chose a password must
never be texted again -- the sync replays events constantly, and a message
per replay is both a charge and an alarming thing to receive. And the message
must never contain a password: an SMS outlives the phone it arrived on.
"""

from app.services.invitation_service import needs_invitation
from app.services.sms_service import code_message, invitation_message


class _Parent:
    def __init__(self, password_hash=None):
        self.password_hash = password_hash
        self.phone = "992987644002"


def test_a_parent_without_a_password_is_invited():
    assert needs_invitation(_Parent())


def test_a_parent_who_already_set_one_is_not():
    """The sync re-sends the same parent on every grade, mark and absence."""
    assert not needs_invitation(_Parent(password_hash="whatever"))


def test_the_invitation_carries_the_code_and_nothing_else_secret():
    message = invitation_message("790165")
    assert "790165" in message
    # The words a password would have to appear next to. None of them belong
    # in a message that lives in an inbox forever.
    for forbidden in ("парол", "password", "parol"):
        assert forbidden.lower() not in message.lower()


def test_the_invitation_says_why_it_arrived():
    """A bare six-digit number from an unknown sender is what a scam looks
    like -- the parent has to be able to tell this one apart."""
    message = invitation_message("790165")
    assert "SmartFlow" in message
    assert len(message) > 40


def test_the_plain_code_message_is_shorter_than_the_invitation():
    """Different situations: one is answered by someone who just tapped a
    button, the other arrives unannounced and has to explain itself."""
    assert len(code_message("790165")) < len(invitation_message("790165"))


class _Upsert:
    """When the sync decides to text a newly enrolled child's parent.

    The rule is narrow on purpose. Every grade and every absence carries the
    same parent details as the enrolment does, so firing on any of them would
    text a family at random hours for months -- the invitation belongs to the
    one event that means "this person has just been given a reason to install
    the app".
    """

    def __init__(self, known_numbers: set[str]):
        self.known = set(known_numbers)

    def upsert(self, phone: str) -> tuple[str, bool]:
        created = phone not in self.known
        self.known.add(phone)
        return phone, created

    def should_invite(self, event_type: str, phone: str | None) -> bool:
        if phone is None:
            return False
        _, created = self.upsert(phone)
        return event_type == "student" and created


NEW = "+992900000001"
KNOWN = "+992900000002"


def test_a_new_number_is_invited_when_the_child_is_enrolled():
    sync = _Upsert({KNOWN})
    assert sync.should_invite("student", NEW) is True


def test_a_number_already_on_file_is_not():
    """They have either been texted already or are using the app."""
    sync = _Upsert({KNOWN})
    assert sync.should_invite("student", KNOWN) is False


def test_a_grade_never_invites():
    """Even for a number seen for the first time -- a mark arriving is not a
    moment to text somebody about installing an app."""
    sync = _Upsert({KNOWN})
    assert sync.should_invite("grade", NEW) is False


def test_the_same_child_saved_twice_invites_once():
    """A director pressing save again, or a sync event replaying."""
    sync = _Upsert({KNOWN})
    assert sync.should_invite("student", NEW) is True
    assert sync.should_invite("student", NEW) is False


def test_an_event_without_a_parent_invites_nobody():
    sync = _Upsert({KNOWN})
    assert sync.should_invite("student", None) is False
