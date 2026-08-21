TAJIKISTAN_CODE = "992"
LOCAL_NUMBER_LENGTH = 9


def normalize_phone(phone: str) -> str:
    """One canonical form per person: digits only, always country-code first.

    Stripping to digits was not enough. A parent typing "987644002" and the
    same parent typing "+992 987 64 40 02" produced two different keys, so
    the school ended up with two rows for one person -- and the children
    were attached to whichever one happened to be created first, leaving the
    other login staring at an empty dashboard.

    Everything therefore normalises to `992XXXXXXXXX`:

    * ``+992 987 64 40 02`` -> ``992987644002``
    * ``00992987644002``    -> ``992987644002``
    * ``987644002``         -> ``992987644002``
    * ``0987644002``        -> ``992987644002``

    Anything that doesn't fit those shapes is returned digits-only and
    unchanged: a number from another country must not be mangled into a
    Tajik one just to satisfy this function.
    """
    digits = "".join(char for char in phone if char.isdigit())
    if not digits:
        return digits

    # International dialling prefix.
    if digits.startswith("00"):
        digits = digits[2:]

    # Already canonical.
    if digits.startswith(TAJIKISTAN_CODE) and len(digits) == len(TAJIKISTAN_CODE) + LOCAL_NUMBER_LENGTH:
        return digits

    # Trunk prefix used when dialling inside the country.
    if digits.startswith("0") and len(digits) == LOCAL_NUMBER_LENGTH + 1:
        digits = digits[1:]

    if len(digits) == LOCAL_NUMBER_LENGTH:
        return TAJIKISTAN_CODE + digits

    return digits
