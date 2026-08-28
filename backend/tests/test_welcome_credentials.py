# -*- coding: utf-8 -*-
"""What the school tells a family when their child is registered.

Only one thing, now: the pupil's login, delivered into the parent's app. The
parent's own way in is the Register button -- phone, code, a password they
choose -- and nothing the school sends is a credential for them.

An earlier version also texted school-issued passwords for both of them. Two
sets of credentials arriving by two routes, while the app still asked the
parent to choose a third, is what made signing in unusable; these tests are
here so that does not creep back.
"""

from app.services.credentials_service import in_app_message


def _message():
    return in_app_message(
        student_name="Komron",
        student_username="k.abdulloev",
        student_password="Qw7rtyPn",
    )


def test_the_pupils_login_and_password_are_both_there():
    """The pupil cannot invent either one, so this message is the only place
    they exist outside the database."""
    title, body = _message()
    assert "Komron" in title
    assert "k.abdulloev" in body
    assert "Qw7rtyPn" in body


def test_the_parents_own_login_is_not_repeated():
    """They are reading this while signed in with it -- and every extra copy
    of a credential is one more place it can be read from."""
    _, body = _message()
    assert "987644002" not in body
    assert "parol" not in body.lower()


def test_it_is_written_in_tajik():
    """Unlike an SMS, a push has no per-character cost, so there is no reason
    to write it in Latin."""
    _, body = _message()
    assert any("Ѐ" <= character <= "ӿ" for character in body)


def test_the_pupils_password_is_eight_characters_from_an_unambiguous_set():
    """It gets read off a screen and typed by a child, so 0/O and 1/l/I are
    left out of the alphabet."""
    from app.services.student_login_service import PASSWORD_LENGTH, generate_password

    for _ in range(50):
        password = generate_password()
        assert len(password) == PASSWORD_LENGTH == 8
        assert not set(password) & set("0O1lI")
