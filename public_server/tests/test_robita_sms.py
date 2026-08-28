# -*- coding: utf-8 -*-
"""The two things that break silently when driving a web panel instead of an
API.

Robita's send form is nine characters wide, so a number stored the way this
server stores them -- country code first -- is truncated by the browser field
and the message goes to a number nobody owns. And the panel answers an
expired session by serving the login page with HTTP 200, which looks exactly
like success unless something checks.
"""

from app.services.robita_sms import _LOGGED_OUT_MARKER, _first_message, to_local_number


def test_the_country_code_comes_off():
    """The field is maxlength=9; 992987644002 would be cut to the first nine
    digits -- 992987644 -- which is a real-looking number and the wrong
    person."""
    assert to_local_number("992987644002") == "987644002"


def test_a_number_typed_any_way_lands_the_same():
    for written in ["+992 98 764 40 02", "992987644002", "0987644002", "98-764-40-02"]:
        assert to_local_number(written) == "987644002", written


def test_an_already_local_number_is_left_alone():
    assert to_local_number("987644002") == "987644002"


def test_the_logged_out_marker_is_what_the_login_page_has():
    """If Robita renames this field the retry logic stops noticing expired
    sessions, so the marker is asserted rather than assumed."""
    login_page = '<form action="auth" method="post"><input name=\'login\'>' \
                 '<input type="password" name="password"></form>'
    assert _LOGGED_OUT_MARKER in login_page

    panel_page = '<a href="?page=message">Сообщения</a>'
    assert _LOGGED_OUT_MARKER not in panel_page


def test_the_panels_own_error_text_is_extracted_for_the_log():
    html = '<div class="alert alert-danger">Недостаточно средств</div>'
    assert "Недостаточно средств" in _first_message(html)


def test_no_banner_is_not_an_error():
    assert _first_message("<html><body>ok</body></html>") == ""
